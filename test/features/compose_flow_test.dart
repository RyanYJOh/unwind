import 'package:drift/native.dart';
import 'package:flutter/material.dart' show TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/utils/dates.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/db/tables/tables.dart';
import 'package:unwind/domain/models/todd_state.dart';
import 'package:unwind/widgets/todd/todd_view.dart';
import 'package:unwind/features/compose/date_bar.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/main.dart';
import 'package:unwind/ui/ui.dart';

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

    // 빈 상태 문구 (§6.1) — v2: textPrimary 크로스페이드 폐기, 한 겹
    expect(find.text('No to-do items'), findsOneWidget);

    // FAB 탭
    await tester.tap(find.bySemanticsLabel('Add a task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 시트 320ms

    // 우측 원형 화살표 저장 CTA가 추가·편집 공통으로 노출된다.
    expect(find.bySemanticsLabel('Save'), findsOneWidget);

    // 제목 입력 후 CTA가 연결된 저장 콜백을 실행한다.
    await tester.enterText(find.byType(TextField).first, '치과 예약 전화하기');
    tester.widget<DateBar>(find.byType(DateBar)).onSave();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 개정 2026-08-12: 저장하면 키보드와 함께 시트도 닫힌다 (토스트 없음).
    expect(find.byType(DateBar), findsNothing);
    expect(tester.testTextInput.isVisible, false);

    // DB → 스트림 → 등 1개
    expect(find.byType(UnwindTodoTile), findsOneWidget);

    await teardownApp(tester);
  });

  testWidgets('입력 시트를 핸들로 아래로 드래그하면 닫힌다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Add a task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DateBar), findsOneWidget);

    await tester.timedDrag(
      find.byKey(const ValueKey('unwindSheetHandle')),
      const Offset(0, 500),
      const Duration(milliseconds: 200),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DateBar), findsNothing);

    await teardownApp(tester);
  });

  testWidgets('체크 토글이 DB에 반영되고 등이 흐려진다', (tester) async {
    // 미리 데이터 심기 — todayKey는 롤오버 서비스와 같은 규칙으로 계산
    final todayKey = logicalTodayKey(DateTime.now());
    await db.todoDao.insertTodo(title: '운동 30분', date: todayKey);

    await pumpApp(tester);
    expect(find.byType(UnwindTodoTile), findsOneWidget);

    // 개정 2026-08-07: 토글은 우측 스위치로
    await tester.tap(find.byType(UnwindLampSwitch));
    await tester.pump(); // 리빌드 프레임
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final rows = await db.todoDao.getByDate(todayKey);
    expect(rows.single.status, TodoStatus.done);
    expect(rows.single.completedAt, isNotNull);

    // §14: 완료해도 리스트에서 사라지지 않는다
    expect(find.byType(UnwindTodoTile), findsOneWidget);

    await teardownApp(tester);
  });

  testWidgets('자동 미루기와 반복은 상호 배제되고 기본 시간이 저장된다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Add a task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 개정 2026-08-12: 역할별로 UI가 다르다 —
    // 시간=값 행, 자동 미루기=토글 행, 반복=칩 그룹.
    bool autoDefer() =>
        tester.widget<UnwindToggle>(find.byType(UnwindToggle)).value;
    UnwindChip chip(String label) =>
        tester.widget<UnwindChip>(find.widgetWithText(UnwindChip, label));
    Future<void> tapText(String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
    }

    expect(find.text('Postpone automatically'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(chip('No repeat').selected, true);

    await tapText('Postpone automatically');
    expect(autoDefer(), true);

    // 반복을 고르면 자동 미루기가 풀린다 (상호 배제)
    await tapText('Every day');
    expect(chip('Every day').selected, true);
    expect(autoDefer(), false);

    // 선택된 반복 칩을 다시 누르면 해제된다
    await tapText('Every day');
    expect(chip('Every day').selected, false);
    expect(chip('No repeat').selected, true);

    await tapText('Postpone automatically');
    await tapText('Time'); // 값 행을 열면 기본 09:00이 잡힌다
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField).first, '시간 있는 일');
    tester.widget<DateBar>(find.byType(DateBar)).onSave();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

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
    expect(find.byType(UnwindTodoTile), findsNothing);
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

    // v2: 롱프레스 → 곧바로 삭제 범위를 묻는 액션 시트 (중간 단계 제거)
    await tester.longPress(find.byType(UnwindTodoTile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete only this task'), findsOneWidget);
    expect(find.text('Delete this and all future repeats'), findsOneWidget);

    await tester.tap(find.text('Delete only this task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      (await db.todoDao.getByDate(todayKey)).single.status,
      TodoStatus.deferred,
    );
    await tester.pump();
    expect(find.byType(UnwindTodoTile), findsNothing);
    await teardownApp(tester);
  });

  testWidgets('삭제하면 되돌리기 토스트가 뜨고, 누르면 등이 돌아온다', (tester) async {
    final todayKey = logicalTodayKey(DateTime.now());
    await db.todoDao.insertTodo(title: '되살릴 일', date: todayKey);
    await pumpApp(tester);

    final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
    expect(
      await dismissible.confirmDismiss!(DismissDirection.endToStart),
      true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await db.todoDao.getByDate(todayKey), isEmpty);
    expect(find.text('To-do deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final restored = await db.todoDao.getByDate(todayKey);
    expect(restored.single.title, '되살릴 일');
    expect(restored.single.status, TodoStatus.pending);

    await tester.pump(const Duration(seconds: 6)); // 토스트 정리
    await teardownApp(tester);
  });

  testWidgets('반복 항목은 스와이프로 지울 때도 삭제 범위를 묻는다', (tester) async {
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

    final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
    final pending = dismissible.confirmDismiss!(DismissDirection.endToStart);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 개정 2026-08-12: 스와이프도 범위를 묻는다 (그냥 지워지던 버그).
    expect(find.text('Delete only this task'), findsOneWidget);
    expect(find.text('Delete this and all future repeats'), findsOneWidget);
    expect(
      (await db.todoDao.getByDate(todayKey)).single.status,
      TodoStatus.pending,
    );

    // 닫기 = 취소 → 항목은 제자리로 돌아온다
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(await pending, false);
    expect(
      (await db.todoDao.getByDate(todayKey)).single.status,
      TodoStatus.pending,
    );

    await teardownApp(tester);
  });

  testWidgets('Todd를 톡 건드리면 반응하고, 잠들었을 땐 무반응', (tester) async {
    final todayKey = logicalTodayKey(DateTime.now());
    await db.todoDao.insertTodo(title: '남은 일', date: todayKey);
    await pumpApp(tester);

    ToddState todd() => tester.widget<ToddView>(find.byType(ToddView)).state;
    expect(todd().isAsleep, isFalse);

    final before = todd().eventTick;
    await tester.tap(find.byType(ToddView));
    await tester.pump();
    expect(todd().event, ToddEvent.poke);
    expect(todd().eventTick, greaterThan(before));

    // 소등 → 잠든 방. 이제 아무리 건드려도 반응하지 않는다.
    await db.dayDao.markLightsOut(todayKey, DateTime.now());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(todd().isAsleep, isTrue);

    final asleepTick = todd().eventTick;
    await tester.tap(find.byType(ToddView));
    await tester.pump();
    expect(todd().eventTick, asleepTick, reason: '잠든 Todd는 깨우지 않는다');

    await teardownApp(tester);
  });
}
