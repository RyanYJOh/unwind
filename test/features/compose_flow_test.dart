import 'package:drift/native.dart';
import 'package:flutter/material.dart' show TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/utils/dates.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/db/tables/tables.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/main.dart';
import 'package:unwind/widgets/lamp_row.dart';

/// §6.3 입력 시트 흐름 + §14 사용성 수용 기준 (인메모리 DB)
void main() {
  late UnwindDatabase db;

  setUp(() async {
    db = UnwindDatabase.withExecutor(NativeDatabase.memory());
    // 온보딩 라우팅 우회 (§6.6) — 홈 화면 테스트
    await db.settingsDao.setValue('onboardingCompleted', 'true');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const UnwindApp(),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> teardownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('FAB → 시트 → 엔터 연속 입력 → 항목이 등으로 나타난다',
      (tester) async {
    await pumpApp(tester);

    // 빈 상태 문구 (§6.1)
    expect(find.text('오늘은 켜둘 불이 없어요'), findsNWidgets(2)); // 크로스페이드 2겹

    // FAB 탭
    await tester.tap(find.bySemanticsLabel('할 일 추가'));
    await tester.pump(const Duration(milliseconds: 400)); // 시트 320ms

    // 제목 입력 후 엔터
    await tester.enterText(find.byType(TextField).first, '치과 예약 전화하기');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 100));

    // §14: 엔터로 연속 입력 — 시트 유지 + 입력창 비워짐
    expect(find.byType(TextField), findsWidgets);
    expect(
        (tester.widget<TextField>(find.byType(TextField).first))
            .controller!
            .text,
        isEmpty);

    // 두 번째 항목
    await tester.enterText(find.byType(TextField).first, '장보기');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 100));

    // 시트 닫기 (✕)
    await tester.tap(find.text('✕'));
    await tester.pump(const Duration(milliseconds: 400));

    // DB → 스트림 → 등 2개 (순서는 sortIndex)
    expect(find.byType(LampRow), findsNWidgets(2));

    await teardownApp(tester);
  });

  testWidgets('체크 토글이 DB에 반영되고 등이 흐려진다', (tester) async {
    // 미리 데이터 심기 — todayKey는 롤오버 서비스와 같은 규칙으로 계산
    final todayKey = logicalTodayKey(DateTime.now());
    await db.todoDao.insertTodo(title: '운동 30분', date: todayKey);

    await pumpApp(tester);
    expect(find.byType(LampRow), findsOneWidget);

    await tester.tap(find.byType(LampRow));
    await tester.pump(const Duration(milliseconds: 700));

    final rows = await db.todoDao.getByDate(todayKey);
    expect(rows.single.status, TodoStatus.done);
    expect(rows.single.completedAt, isNotNull);

    // §14: 완료해도 리스트에서 사라지지 않는다
    expect(find.byType(LampRow), findsOneWidget);

    await teardownApp(tester);
  });
}
