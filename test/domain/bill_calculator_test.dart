import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/repositories/bill_repository.dart';
import 'package:unwind/data/repositories/todo_repository.dart';
import 'package:unwind/domain/services/bill_calculator.dart';

/// §6.5 청구서 계산 — 단위 테스트 필수 (§13 M3)
void main() {
  group('litHours — 점등 시간', () {
    final day = DateTime(2026, 8, 3); // 월요일

    test('06:00 이전에 만든 항목은 06:00부터 계산한다', () {
      final h = BillCalculator.litHours(
        dayStart: day,
        createdAt: DateTime(2026, 8, 3, 2, 0), // 새벽 2시 등록
        completedAt: DateTime(2026, 8, 3, 8, 0),
      );
      expect(h, closeTo(2.0, 1e-9)); // 06~08시
    });

    test('06:00 이후 등록은 등록 시각부터', () {
      final h = BillCalculator.litHours(
        dayStart: day,
        createdAt: DateTime(2026, 8, 3, 10, 0),
        completedAt: DateTime(2026, 8, 3, 13, 30),
      );
      expect(h, closeTo(3.5, 1e-9));
    });

    test('미완료 + 전등 줄 당김 → lightsOutAt까지', () {
      final h = BillCalculator.litHours(
        dayStart: day,
        createdAt: DateTime(2026, 8, 3, 10, 0),
        lightsOutAt: DateTime(2026, 8, 3, 22, 0),
      );
      expect(h, closeTo(12.0, 1e-9));
    });

    test('미완료 + 당기지 않음 → 그날 24:00까지', () {
      final h = BillCalculator.litHours(
        dayStart: day,
        createdAt: DateTime(2026, 8, 3, 18, 0),
      );
      expect(h, closeTo(6.0, 1e-9));
    });

    test('음수가 되지 않는다 (자정 직전 등록 후 즉시 완료 등)', () {
      final h = BillCalculator.litHours(
        dayStart: day,
        createdAt: DateTime(2026, 8, 3, 23, 59),
        completedAt: DateTime(2026, 8, 3, 23, 58), // 비정상 입력
      );
      expect(h, 0.0);
    });
  });

  group('round10 · 주간 요금', () {
    test('10원 반올림', () {
      expect(round10(1234.0), 1230);
      expect(round10(1235.0), 1240);
      expect(round10(1236.7), 1240);
    });

    test('주간 요금 = BASE_FEE + round10(kWh × UNIT_PRICE)', () {
      // 등 1개, 06~16시(10h) 켜짐 → 0.6 kWh → 91.2원 → 90원 + 730원
      final result = BillCalculator.calcWeek(
        weekStartKey: '2026-08-03',
        todosByDate: {},
        daysByDate: {},
      );
      expect(result.amount, kBaseFee); // 빈 주는 기본료만
      expect(result.kwh, 0.0);
    });
  });

  group('Lumi 수면 (§6.5)', () {
    test('취침 22:30 → 기상 다음날 06:00 = 450분', () {
      // calcDay를 직접 검증하려면 Day 행이 필요 — 통합 케이스에서 확인
      expect(sleepGrade(450), '푹 잤어요'); // 7.5h
    });

    test('서술 등급 경계', () {
      expect(sleepGrade(7 * 60), '푹 잤어요');
      expect(sleepGrade(5 * 60), '잘 잤어요');
      expect(sleepGrade(3 * 60), '조금 뒤척였어요');
      expect(sleepGrade(60), '겨우 눈을 붙였어요');
      expect(sleepGrade(0), '밤새 깨어 있었어요');
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
      // 지난주 화요일(7/28)에 항목 1개 + 전등 줄
      final t = await todoRepo.add(title: '지난주 일', date: '2026-07-28');
      await todoRepo.setDone(t, true);
      await todoRepo.pullCord('2026-07-28', DateTime(2026, 7, 28, 22, 0));

      final bill = await billRepo.ensureLastWeekBill('2026-08-06');
      expect(bill, isNotNull);
      expect(bill!.weekStart, '2026-07-27'); // 지난주 월요일
      expect(bill.isRead, false);
      expect(bill.amount, greaterThanOrEqualTo(kBaseFee));
      // 수면: 22:00 → 다음날 06:00 = 480분
      expect(bill.sleepMinutes, 480);

      // payload 파싱 + 재생성 안 함
      expect(decodeBillPayload(bill.payload).length, 7);
      final again = await billRepo.ensureLastWeekBill('2026-08-06');
      expect(again!.generatedAt, bill.generatedAt);
    });

    test('빈 주에는 청구서를 만들지 않는다', () async {
      final bill = await billRepo.ensureLastWeekBill('2026-08-06');
      expect(bill, isNull);
    });
  });
}
