import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoActionSheetAction;
import 'package:flutter/material.dart' show Checkbox, TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/utils/dates.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/db/tables/tables.dart';
import 'package:unwind/features/compose/date_bar.dart';
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
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const UnwindApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> teardownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets('FAB → 시트 → 원형 저장 CTA → 키보드가 닫히고 항목이 나타난다', (tester) async {
    await pumpApp(tester);

    // 빈 상태 문구 (§6.1)
    expect(
      find.text('No lights to keep on today'),
      findsNWidgets(2),
    ); // 크로스페이드 2겹

    // FAB 탭
    await tester.tap(find.bySemanticsLabel('Add a task'));
    await tester.pump(const Duration(milliseconds: 400)); // 시트 320ms

    // 우측 원형 화살표 저장 CTA가 추가·편집 공통으로 노출된다.
    expect(find.bySemanticsLabel('Save'), findsOneWidget);

    // 제목 입력 후 CTA가 연결된 저장 콜백을 실행한다.
    await tester.enterText(find.byType(TextField).first, '치과 예약 전화하기');
    tester.widget<DateBar>(find.byType(DateBar)).onSave();
    await tester.pump(const Duration(milliseconds: 100));

    // 저장 후 시트와 선택 날짜는 유지하지만 키보드는 닫히고 입력창은 비워진다.
    expect(find.byType(TextField), findsWidgets);
    expect(
      (tester.widget<TextField>(find.byType(TextField).first)).controller!.text,
      isEmpty,
    );
    expect(tester.testTextInput.isVisible, false);

    // 배리어를 눌러 시트 닫기
    await tester.tapAt(const Offset(8, 8));
    await tester.pump(const Duration(milliseconds: 400));

    // DB → 스트림 → 등 1개
    expect(find.byType(LampRow), findsOneWidget);

    await teardownApp(tester);
  });

  testWidgets('체크 토글이 DB에 반영되고 등이 흐려진다', (tester) async {
    // 미리 데이터 심기 — todayKey는 롤오버 서비스와 같은 규칙으로 계산
    final todayKey = logicalTodayKey(DateTime.now());
    await db.todoDao.insertTodo(title: '운동 30분', date: todayKey);

    await pumpApp(tester);
    expect(find.byType(LampRow), findsOneWidget);

    // 개정 2026-08-07: 토글은 우측 스위치로
    await tester.tap(find.byType(LampSwitch));
    await tester.pump(); // 리빌드 프레임
    await tester.pump(const Duration(milliseconds: 700));

    final rows = await db.todoDao.getByDate(todayKey);
    expect(rows.single.status, TodoStatus.done);
    expect(rows.single.completedAt, isNotNull);

    // §14: 완료해도 리스트에서 사라지지 않는다
    expect(find.byType(LampRow), findsOneWidget);

    await teardownApp(tester);
  });

  testWidgets('자동 미루기와 반복은 상호 배제되고 기본 시간이 저장된다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Add a task'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Move to tomorrow automatically'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);

    tester.widget<Checkbox>(find.byType(Checkbox)).onChanged!(true);
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);

    tester
        .widget<GestureDetector>(
          find
              .ancestor(
                of: find.text('Every day'),
                matching: find.byType(GestureDetector),
              )
              .first,
        )
        .onTap!();
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);

    tester
        .widget<GestureDetector>(
          find
              .ancestor(
                of: find.text('No repeat'),
                matching: find.byType(GestureDetector),
              )
              .first,
        )
        .onTap!();
    await tester.pump();
    tester.widget<Checkbox>(find.byType(Checkbox)).onChanged!(true);
    tester
        .widget<GestureDetector>(
          find
              .ancestor(
                of: find.text('Time'),
                matching: find.byType(GestureDetector),
              )
              .first,
        )
        .onTap!();
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '시간 있는 일');
    tester.widget<DateBar>(find.byType(DateBar)).onSave();
    await tester.pump(const Duration(milliseconds: 100));

    final todayKey = logicalTodayKey(DateTime.now());
    final saved = (await db.todoDao.getByDate(todayKey)).single;
    expect(saved.autoDefer, true);
    expect(saved.scheduledTimeMinutes, 9 * 60);
    await teardownApp(tester);
  });

  testWidgets('항목을 왼쪽으로 스와이프하면 삭제된다', (tester) async {
    final todayKey = logicalTodayKey(DateTime.now());
    await db.todoDao.insertTodo(title: '지울 일', date: todayKey);
    await pumpApp(tester);

    final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
    expect(dismissible.direction, DismissDirection.endToStart);
    expect(
      await dismissible.confirmDismiss!(DismissDirection.endToStart),
      true,
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(await db.todoDao.getByDate(todayKey), isEmpty);
    expect(find.byType(LampRow), findsNothing);
    await teardownApp(tester);
  });

  testWidgets('반복 항목 롱프레스는 삭제만 표시하고 삭제 범위를 묻는다', (tester) async {
    final todayKey = logicalTodayKey(DateTime.now());
    final recurrence = await db.recurrenceDao.create(
      title: '반복 항목',
      rule: RecurrenceRule.daily,
      startDate: todayKey,
    );
    await db.todoDao.insertTodo(
      title: '반복 항목',
      date: todayKey,
      recurrenceId: recurrence.id,
    );
    await pumpApp(tester);

    await tester.longPress(find.byType(LampRow));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Delete only this task'), findsOneWidget);
    expect(find.text('Delete this and all future repeats'), findsOneWidget);

    final deleteOnlyAction = find.ancestor(
      of: find.text('Delete only this task'),
      matching: find.byType(CupertinoActionSheetAction),
    );
    tester.widget<CupertinoActionSheetAction>(deleteOnlyAction).onPressed();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      (await db.todoDao.getByDate(todayKey)).single.status,
      TodoStatus.deferred,
    );
    await tester.pump();
    expect(find.byType(LampRow), findsNothing);
    await teardownApp(tester);
  });
}
