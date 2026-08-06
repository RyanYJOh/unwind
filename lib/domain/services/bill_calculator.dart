import 'dart:math' as math;

import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';

// §6.5 계산 상수 — 모든 상수는 파일 상단에 선언. 임의 변경 금지.
const double kBulbKwhPerHour = 0.06; // 등 하나가 한 시간에 쓰는 전력
const int kUnitPrice = 152; // 원/kWh
const int kBaseFee = 730; // 원
const int kDayStartHour = 6; // 하루의 시작

/// 10원 반올림 (§4.4)
int round10(double won) => ((won / 10).round()) * 10;

/// 하루치 계산 결과
class DayBill {
  final String date;
  final double kwh;
  final bool lightsOut;
  final int sleepMinutes;

  const DayBill({
    required this.date,
    required this.kwh,
    required this.lightsOut,
    required this.sleepMinutes,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'kwh': kwh,
        'lightsOut': lightsOut,
        'sleepMinutes': sleepMinutes,
      };

  factory DayBill.fromJson(Map<String, dynamic> json) => DayBill(
        date: json['date'] as String,
        kwh: (json['kwh'] as num).toDouble(),
        lightsOut: json['lightsOut'] as bool,
        sleepMinutes: json['sleepMinutes'] as int,
      );
}

/// 주간 청구서 계산 결과
class WeekBillResult {
  final String weekStart; // 월요일
  final double kwh;
  final int amount; // 원, 10원 반올림 + 기본료
  final int sleepMinutes; // 주간 Lumi 총 수면
  final List<DayBill> days;

  const WeekBillResult({
    required this.weekStart,
    required this.kwh,
    required this.amount,
    required this.sleepMinutes,
    required this.days,
  });

  /// 불을 끈 밤의 수 (문구용: `이번 주엔 4일 밤 불을 껐어요`)
  int get lightsOutNights => days.where((d) => d.lightsOut).length;
}

/// §6.5 청구서 계산기 — 순수 로직. 단위 테스트 필수.
class BillCalculator {
  /// 항목 하나의 점등 시간(시간 단위).
  ///   시작 = max(그날 06:00, createdAt)
  ///   종료 = 완료 시 completedAt / 미완료 시 (lightsOutAt ?? 그날 24:00)
  static double litHours({
    required DateTime dayStart, // 그날 00:00 (로컬)
    required DateTime createdAt,
    DateTime? completedAt,
    DateTime? lightsOutAt,
  }) {
    final sixAm = DateTime(
        dayStart.year, dayStart.month, dayStart.day, kDayStartHour);
    final midnight =
        DateTime(dayStart.year, dayStart.month, dayStart.day + 1);

    final start = createdAt.isAfter(sixAm) ? createdAt : sixAm;
    final end = completedAt ?? lightsOutAt ?? midnight;

    final h = end.difference(start).inSeconds / 3600.0;
    return math.max(0.0, h);
  }

  /// 하루치 kWh + Lumi 수면 (§6.5)
  static DayBill calcDay({
    required String dateKey,
    required List<Todo> todos,
    required Day? day,
  }) {
    final dayStart = parseDayKey(dateKey);
    var hours = 0.0;
    for (final t in todos) {
      if (t.status == TodoStatus.deferred) continue; // §15 — v1 미사용
      hours += litHours(
        dayStart: dayStart,
        createdAt: t.createdAt,
        completedAt: t.completedAt,
        lightsOutAt: day?.lightsOutAt,
      );
    }

    // Lumi 수면: 취침 = lightsOutAt (없으면 0), 기상 = 다음날 06:00
    var sleepMinutes = 0;
    final lightsOutAt = day?.lightsOutAt;
    if (lightsOutAt != null) {
      final wake = DateTime(
          dayStart.year, dayStart.month, dayStart.day + 1, kDayStartHour);
      sleepMinutes =
          math.max(0, wake.difference(lightsOutAt).inMinutes);
    }

    return DayBill(
      date: dateKey,
      kwh: hours * kBulbKwhPerHour,
      lightsOut: lightsOutAt != null,
      sleepMinutes: sleepMinutes,
    );
  }

  /// 주간 청구서 (§6.5)
  /// 주간 요금 = BASE_FEE + round10(주간 kWh × UNIT_PRICE)
  static WeekBillResult calcWeek({
    required String weekStartKey, // 월요일
    required Map<String, List<Todo>> todosByDate,
    required Map<String, Day> daysByDate,
  }) {
    final monday = parseDayKey(weekStartKey);
    final days = <DayBill>[];
    for (var i = 0; i < 7; i++) {
      final key = dayKey(addDays(monday, i));
      days.add(calcDay(
        dateKey: key,
        todos: todosByDate[key] ?? const [],
        day: daysByDate[key],
      ));
    }
    final kwh = days.fold(0.0, (sum, d) => sum + d.kwh);
    return WeekBillResult(
      weekStart: weekStartKey,
      kwh: kwh,
      amount: kBaseFee + round10(kwh * kUnitPrice),
      sleepMinutes: days.fold(0, (sum, d) => sum + d.sleepMinutes),
      days: days,
    );
  }
}

/// §6.5 수면 서술 등급 — 숫자·알파벳 등급 금지. 하룻밤 기준 시간으로 서술.
/// [minutes]는 하룻밤 수면(분). 주간 요약에는 평균을 넣는다.
String sleepGrade(int minutes) {
  final h = minutes / 60.0;
  if (h >= 7) return '푹 잤어요';
  if (h >= 5) return '잘 잤어요';
  if (h >= 3) return '조금 뒤척였어요';
  if (h > 0) return '겨우 눈을 붙였어요';
  return '밤새 깨어 있었어요';
}
