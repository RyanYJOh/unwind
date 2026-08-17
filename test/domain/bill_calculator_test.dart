import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/db/tables/tables.dart';
import 'package:unwind/data/repositories/bill_repository.dart';
import 'package:unwind/data/repositories/todo_repository.dart';
import 'package:unwind/domain/services/bill_calculator.dart';

/// §6.5 청구서 계산 — 단위 테스트 필수 (§13 M3)
void main() {
  group('nightLengthHours', () {
    test('기본 22→05 = 7시간', () {
      expect(nightLengthHours(22, 5), 7);
    });

    test('자정 넘김 01→05 = 4시간', () {
      expect(nightLengthHours(1, 5), 4);
    });
  });

  group('하루 요금 — 남긴 등 × 밤', () {
    test('소등한 날은 0원', () {
      final day = BillCalculator.calcDay(
        dateKey: '2026-08-03',
        todos: const [],
        day: null,
      );
      expect(day.lightsOut, true);
      expect(day.kwh, 0);
      expect(day.amount, 0);
      expect(day.sleepScore, 1);
    });

    test('미완 2개 · 미소등 → 2 × 7h × 0.06 kWh', () {
      Todo pending(String id) => Todo(
        id: id,
        title: id,
        date: '2026-08-03',
        status: TodoStatus.pending,
        sortIndex: 0,
        createdAt: DateTime(2026, 8, 3, 10),
        autoDefer: false,
      );
      final day = BillCalculator.calcDay(
        dateKey: '2026-08-03',
        todos: [pending('a'), pending('b')],
        day: null,
        wakeHour: 5,
        bedtimeHour: 22,
      );
      expect(day.lightsOut, false);
      expect(day.leftover, 2);
      expect(day.kwh, closeTo(0.84, 1e-9));
      expect(day.amount, 12768); // 0.84 * 15200
      expect(day.sleepScore, 0);
    });
  });

  group('round10 · 주간 요금', () {
    test('10원 반올림', () {
      expect(round10(1234.0), 1230);
      expect(round10(1235.0), 1240);
      expect(round10(1236.7), 1240);
    });

    test('빈 주(매일 닫힘)는 0원', () {
      final result = BillCalculator.calcWeek(
        weekStartKey: '2026-08-03',
        todosByDate: {},
        daysByDate: {},
      );
      expect(result.amount, 0);
      expect(result.kwh, 0.0);
      expect(result.sleepScore, 1.0);
      expect(result.completed, 0);
      expect(result.total, 0);
    });
  });

  group('Todd 수면 등급', () {
    test('서술 등급 경계', () {
      expect(sleepGrade(1.0), SleepGrade.deep);
      expect(sleepGrade(0.80), SleepGrade.well);
      expect(sleepGrade(0.79), SleepGrade.tossed);
      expect(sleepGrade(0.50), SleepGrade.tossed);
      expect(sleepGrade(0.20), SleepGrade.barely);
      expect(sleepGrade(0.19), SleepGrade.none);
      expect(sleepGrade(0), SleepGrade.none);
    });
  });

  group('BillRepository — 생성 (인메모리 DB)', () {
    late UnwindDatabase db;
    late TodoRepository todoRepo;
    late BillRepository billRepo;

    setUp(() {
      db = UnwindDatabase.withExecutor(NativeDatabase.memory());
      todoRepo = TodoRepository(db);
      billRepo = BillRepository(db);
    });

    tearDown(() => db.close());

    test('지난주에 활동이 있으면 청구서가 생성된다 (한 번만)', () async {
      final t = await todoRepo.add(title: '지난주 일', date: '2026-07-28');
      await todoRepo.setDone(t, true);
      await todoRepo.pullCord('2026-07-28', DateTime(2026, 7, 28, 22, 0));

      final bill = await billRepo.ensureLastWeekBill('2026-08-06');
      expect(bill, isNotNull);
      expect(bill!.weekStart, '2026-07-27');
      expect(bill.isRead, false);
      expect(bill.amount, 0); // 소등한 날 + 빈 날 = 전부 닫힘
      expect(bill.sleepMinutes, greaterThan(0));

      final contents = decodeBillPayload(bill.payload);
      expect(contents.days.length, 7);
      expect(contents.completed, 1);
      expect(contents.total, 1);
      expect(contents.sleepScore, 1.0);

      final again = await billRepo.ensureLastWeekBill('2026-08-06');
      expect(again!.generatedAt, bill.generatedAt);
    });

    test('빈 주도 0원 청구서를 만든다', () async {
      final bill = await billRepo.ensureLastWeekBill('2026-08-06');
      expect(bill, isNotNull);
      expect(bill!.amount, 0);
      expect(bill.kwh, 0);
      expect(decodeBillPayload(bill.payload).sleepScore, 1.0);
    });

    test('미소등 날은 남긴 등 × 밤만큼 청구한다', () async {
      await todoRepo.add(title: '남은 등', date: '2026-07-28');
      // 소등 없음 → leftover 1 × 7h × 0.06 = 0.42 kWh → 6,384원 → 6,380원
      final bill = await billRepo.ensureLastWeekBill(
        '2026-08-06',
        wakeHour: 5,
        bedtimeHour: 22,
      );
      expect(bill, isNotNull);
      expect(bill!.kwh, closeTo(0.42, 1e-9));
      expect(bill.amount, 6380);
      final contents = decodeBillPayload(bill.payload);
      expect(contents.completed, 0);
      expect(contents.total, 1);
      expect(contents.sleepScore, closeTo(6 / 7, 1e-9));
      final lit = contents.days.where((d) => !d.lightsOut).toList();
      expect(lit, hasLength(1));
      expect(lit.first.leftover, 1);
      expect(lit.first.amount, 6384); // 0.42 * 15200
    });
  });
}
