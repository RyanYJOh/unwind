import 'package:drift/native.dart';
import 'package:flutter/material.dart' show TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/utils/dates.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/db/tables/tables.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/features/week/week_screen.dart';
import 'package:unwind/main.dart';
import 'package:unwind/ui/ui.dart';

/// §6.2 주간 뷰 (전면 재작성 2026-08-13).
void main() {
  late UnwindDatabase db;
  late String todayKey;
  late String mondayKey;

  setUp(() async {
    db = UnwindDatabase.withExecutor(NativeDatabase.memory());
    await db.settingsDao.setValue('onboardingCompleted', 'true');
    todayKey = logicalTodayKey(DateTime.now());
    mondayKey = weekMondayKey(todayKey);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
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

  /// 홈의 `Week n` 알약으로 주간 뷰에 들어간다.
  Future<void> openWeek(WidgetTester tester) async {
    await tester.tap(find.byType(UnwindPill).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('홈의 Week 알약으로 주간 뷰에 들어간다', (tester) async {
    await pumpApp(tester);
    expect(find.byType(WeekScreen), findsNothing);

    // 칩은 상대 표현을 쓴다 (개편 2026-08-13)
    expect(find.text('This week'), findsWidgets);

    await openWeek(tester);
    expect(find.byType(WeekScreen), findsOneWidget);
    // 월~일 7개 요일이 모두 있다 (하단 스트립에도 요일이 있으니 화면으로 한정)
    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(
        find.descendant(of: find.byType(WeekScreen), matching: find.text(d)),
        findsOneWidget,
      );
    }
    await teardownApp(tester);
  });

  testWidgets('주간 뷰에서는 체크할 수 없다 (등은 읽기 전용)', (tester) async {
    await db.todoDao.insertTodo(title: '주간 항목', date: mondayKey);
    await pumpApp(tester);
    await openWeek(tester);

    Finder inWeek(Finder inner) =>
        find.descendant(of: find.byType(WeekScreen), matching: inner);

    expect(inWeek(find.byType(UnwindTodoTile)), findsOneWidget);
    // 오늘의 방에만 있는 벽 스위치가 여기엔 없다
    expect(inWeek(find.byType(UnwindLampSwitch)), findsNothing);
    expect(
      tester
          .widget<UnwindTodoTile>(inWeek(find.byType(UnwindTodoTile)))
          .readOnlySwitch,
      isTrue,
    );

    // DB 상태도 그대로다
    expect(
      (await db.todoDao.getByDate(mondayKey)).single.status,
      TodoStatus.pending,
    );
    await teardownApp(tester);
  });

  testWidgets('요일의 + 버튼은 그 날짜로 입력 시트를 연다', (tester) async {
    await pumpApp(tester);
    await openWeek(tester);

    // 수요일(월+2) 줄의 추가 버튼
    final wedKey = dayKey(addDays(parseDayKey(mondayKey), 2));
    Finder iconButton(String label) => find.byWidgetPredicate(
      (w) => w is UnwindIconButton && w.semanticLabel == label,
    );

    await tester.tap(iconButton('Add to Wed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).first, '수요일 할 일');
    await tester.pump();
    // 시트의 저장 CTA (화살표 아이콘)
    await tester.tap(iconButton('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final saved = await db.todoDao.getByDate(wedKey);
    expect(saved.single.title, '수요일 할 일');
    await teardownApp(tester);
  });

  testWidgets('주간 뷰에서 스와이프 삭제 + 되돌리기가 동작한다', (tester) async {
    await db.todoDao.insertTodo(title: '지울 주간 항목', date: mondayKey);
    await pumpApp(tester);
    await openWeek(tester);

    final dismissible = tester.widget<Dismissible>(
      find.descendant(
        of: find.byType(WeekScreen),
        matching: find.byType(Dismissible),
      ),
    );
    expect(
      await dismissible.confirmDismiss!(DismissDirection.endToStart),
      true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await db.todoDao.getByDate(mondayKey), isEmpty);
    expect(find.text('To-do deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect((await db.todoDao.getByDate(mondayKey)).single.title, '지울 주간 항목');

    await tester.pump(const Duration(seconds: 6));
    await teardownApp(tester);
  });

  testWidgets('미완료 토글을 켜면 완료된 항목만 목록에서 숨긴다', (tester) async {
    final a = await db.todoDao.insertTodo(title: '끝난 일', date: mondayKey);
    await db.todoDao.insertTodo(title: '남은 일', date: mondayKey);
    await db.todoDao.setDone(a.id, true);
    await pumpApp(tester);
    await openWeek(tester);

    Finder inWeek(Finder inner) =>
        find.descendant(of: find.byType(WeekScreen), matching: inner);

    expect(inWeek(find.text('끝난 일')), findsOneWidget);
    expect(inWeek(find.text('남은 일')), findsOneWidget);

    await tester.tap(inWeek(find.text('Incomplete tasks')));
    await tester.pump();

    expect(inWeek(find.text('끝난 일')), findsNothing);
    expect(inWeek(find.text('남은 일')), findsOneWidget);
    // 진행 바는 필터와 무관하다
    expect(
      tester
          .widget<AnimatedFractionallySizedBox>(
            find.byType(AnimatedFractionallySizedBox),
          )
          .widthFactor,
      0.5,
    );

    await teardownApp(tester);
  });

  testWidgets('진행 바는 끝낸 만큼 차오른다', (tester) async {
    // 월요일에 2개, 하나만 완료 → 진행 1/2
    final a = await db.todoDao.insertTodo(title: 'A', date: mondayKey);
    await db.todoDao.insertTodo(title: 'B', date: mondayKey);
    await db.todoDao.setDone(a.id, true);
    await pumpApp(tester);
    await openWeek(tester);

    double barFactor() => tester
        .widget<AnimatedFractionallySizedBox>(
          find.byType(AnimatedFractionallySizedBox),
        )
        .widthFactor!;

    expect(barFactor(), 0.5);
    expect(find.text("This week's progress"), findsOneWidget);

    await teardownApp(tester);
  });

  testWidgets('계획이 없는 주는 빈 막대 + 초대 문구', (tester) async {
    await pumpApp(tester);
    await openWeek(tester);

    expect(
      tester
          .widget<AnimatedFractionallySizedBox>(
            find.byType(AnimatedFractionallySizedBox),
          )
          .widthFactor,
      0.0,
    );
    expect(find.text('Nothing planned this week yet'), findsOneWidget);
    await teardownApp(tester);
  });

  testWidgets('스트립을 지난주로 넘기면 칩 라벨과 주간 뷰가 함께 따라간다', (tester) async {
    final lastMonday = dayKey(addDays(parseDayKey(mondayKey), -7));
    await db.todoDao.insertTodo(title: '지난주 항목', date: lastMonday);
    await pumpApp(tester);

    // 스트립 한 페이지 = 한 주. 오른쪽으로 밀면 과거로 간다.
    // (홈은 호흡 애니메이션이 계속 돌아 pumpAndSettle을 쓸 수 없다)
    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Last week'), findsOneWidget);

    await openWeek(tester);
    // 주간 뷰 제목도 칩과 같은 라벨을 쓴다
    expect(find.text('Last week'), findsWidgets);
    expect(find.text('지난주 항목'), findsOneWidget);
    await teardownApp(tester);
  });
}
