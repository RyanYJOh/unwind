import 'dart:math' as math;

import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';

// §6.5 계산 상수 — 모든 상수는 파일 상단에 선언. 임의 변경 금지.
const double kBulbKwhPerHour = 0.06; // 60W 등 하나가 한 시간에 쓰는 전력
const int kUnitPrice = 15200; // 원/kWh — 재미용 100배 (개정 2026-08-17)

/// 10원 반올림 (§4.4)
int round10(double won) => ((won / 10).round()) * 10;

/// 취침→기상 밤의 길이(시간). 자정을 넘기는 구간을 허용한다.
/// 두 시각이 같으면 하루 전체(24h)로 본다.
double nightLengthHours(int bedtimeHour, int wakeHour) {
  final h = (wakeHour - bedtimeHour + 24) % 24;
  return (h == 0 ? 24 : h).toDouble();
}

/// 그날 밤이 닫혔는가 — 소등했거나, 켤 등이 없거나, 남은 등을 전부 껐다.
bool isDayClosed(List<Todo> todos, Day? day) {
  if (day?.lightsOutAt != null) return true;
  final counted = todos.where((t) => t.status != TodoStatus.deferred);
  if (counted.isEmpty) return true;
  return counted.every((t) => t.status == TodoStatus.done);
}

/// 하루치 계산 결과
class DayBill {
  final String date;
  final double kwh;
  final bool lightsOut;
  final int sleepMinutes;
  final int leftover;
  final int amount;
  final double sleepScore;

  const DayBill({
    required this.date,
    required this.kwh,
    required this.lightsOut,
    required this.sleepMinutes,
    this.leftover = 0,
    this.amount = 0,
    this.sleepScore = 0,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'kwh': kwh,
    'lightsOut': lightsOut,
    'sleepMinutes': sleepMinutes,
    'leftover': leftover,
    'amount': amount,
    'sleepScore': sleepScore,
  };

  factory DayBill.fromJson(Map<String, dynamic> json) => DayBill(
    date: json['date'] as String,
    kwh: (json['kwh'] as num).toDouble(),
    lightsOut: json['lightsOut'] as bool,
    sleepMinutes: json['sleepMinutes'] as int,
    leftover: (json['leftover'] as num?)?.toInt() ?? 0,
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    sleepScore: (json['sleepScore'] as num?)?.toDouble() ?? 0,
  );
}

/// 주간 청구서 계산 결과
class WeekBillResult {
  final String weekStart; // 월요일
  final double kwh;
  final int amount; // 원, 10원 반올림. 7일 모두 소등이면 0
  final int sleepMinutes; // 주간 Todd 총 수면
  final int completed;
  final int total;
  final double sleepScore; // 0~1, 소등한 밤 / 7
  final List<DayBill> days;

  const WeekBillResult({
    required this.weekStart,
    required this.kwh,
    required this.amount,
    required this.sleepMinutes,
    required this.completed,
    required this.total,
    required this.sleepScore,
    required this.days,
  });

  /// 불을 끈 밤의 수
  int get lightsOutNights => days.where((d) => d.lightsOut).length;
}

/// 영수증에 넣는 스냅샷 — [WeeklyBill.payload] JSON.
class BillContents {
  final int completed;
  final int total;
  final double sleepScore;
  final List<DayBill> days;

  const BillContents({
    required this.completed,
    required this.total,
    required this.sleepScore,
    required this.days,
  });
}

/// §6.5 청구서 계산기 — 순수 로직. 단위 테스트 필수.
///
/// 요금은 **밤에 남긴 등**만 본다. 하루를 닫으면(소등·전부 완료·빈 방)
/// 그날은 0원. 7일을 모두 닫으면 주간 총액도 0원.
/// 남긴 등 하나 = 취침~기상 동안 60W가 켜져 있던 것으로 친다.
class BillCalculator {
  /// 하루치 kWh + Todd 수면
  static DayBill calcDay({
    required String dateKey,
    required List<Todo> todos,
    required Day? day,
    int wakeHour = 5,
    int bedtimeHour = 22,
  }) {
    final counted = todos
        .where((t) => t.status != TodoStatus.deferred)
        .toList();
    final closed = isDayClosed(todos, day);
    final leftover = closed
        ? 0
        : counted.where((t) => t.status == TodoStatus.pending).length;

    final nightH = nightLengthHours(bedtimeHour, wakeHour);
    final kwh = leftover * nightH * kBulbKwhPerHour;
    final amount = (kwh * kUnitPrice).round();

    final dayStart = parseDayKey(dateKey);
    final wake = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day + 1,
      wakeHour,
    );
    final windowMinutes = (nightH * 60).round();

    var sleepMinutes = 0;
    if (closed) {
      final lightsOutAt = day?.lightsOutAt;
      if (lightsOutAt != null) {
        sleepMinutes = math.max(0, wake.difference(lightsOutAt).inMinutes);
      } else {
        sleepMinutes = windowMinutes;
      }
    }

    return DayBill(
      date: dateKey,
      kwh: kwh,
      lightsOut: closed,
      sleepMinutes: sleepMinutes,
      leftover: leftover,
      amount: amount,
      sleepScore: closed ? 1 : 0,
    );
  }

  /// 주간 청구서
  /// 주간 요금 = 7일 모두 소등이면 0, 아니면 round10(주간 kWh × UNIT_PRICE)
  static WeekBillResult calcWeek({
    required String weekStartKey, // 월요일
    required Map<String, List<Todo>> todosByDate,
    required Map<String, Day> daysByDate,
    int wakeHour = 5,
    int bedtimeHour = 22,
  }) {
    final monday = parseDayKey(weekStartKey);
    final days = <DayBill>[];
    var completed = 0;
    var total = 0;
    for (var i = 0; i < 7; i++) {
      final key = dayKey(addDays(monday, i));
      final todos = todosByDate[key] ?? const <Todo>[];
      for (final t in todos) {
        if (t.status == TodoStatus.deferred) continue;
        total++;
        if (t.status == TodoStatus.done) completed++;
      }
      days.add(
        calcDay(
          dateKey: key,
          todos: todos,
          day: daysByDate[key],
          wakeHour: wakeHour,
          bedtimeHour: bedtimeHour,
        ),
      );
    }
    final allClosed = days.every((d) => d.lightsOut);
    final kwh = allClosed ? 0.0 : days.fold(0.0, (sum, d) => sum + d.kwh);
    final closedNights = days.where((d) => d.lightsOut).length;
    return WeekBillResult(
      weekStart: weekStartKey,
      kwh: kwh,
      amount: allClosed ? 0 : round10(kwh * kUnitPrice),
      sleepMinutes: days.fold(0, (sum, d) => sum + d.sleepMinutes),
      completed: completed,
      total: total,
      sleepScore: closedNights / 7.0,
      days: days,
    );
  }
}

/// §6.5 수면 서술 등급 — 숫자·알파벳 등급 금지. 문구는 l10n에서 조회한다.
/// [score]는 0~1 (소등한 밤 / 7).
enum SleepGrade { deep, well, tossed, barely, none }

SleepGrade sleepGrade(double score) {
  if (score >= 1.0 - 1e-9) return SleepGrade.deep;
  if (score >= 0.80) return SleepGrade.well;
  if (score >= 0.50) return SleepGrade.tossed;
  if (score >= 0.20) return SleepGrade.barely;
  return SleepGrade.none;
}
