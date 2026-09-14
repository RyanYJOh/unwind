import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/features/today/today_screen.dart';
import 'package:unwind/main.dart';
import 'package:unwind/ui/ui.dart';

/// 홈 편집 모드 (2026-09-14) — 롱프레스하면 아이폰 홈 화면처럼 떨면서
/// ✕ 배지와 순서 손잡이가 생긴다.
void main() {
  late UnwindDatabase db;

  setUp(() {
    db = UnwindDatabase.withExecutor(NativeDatabase.memory());
  });

  Future<String> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390×844pt
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await db.settingsDao.setValue('onboardingCompleted', 'true');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const UnwindApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    return ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
    ).read(todayKeyProvider);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> teardown(WidgetTester tester) async {
    // 순서 저장 뒤 위젯 스냅샷 디바운스(180ms)가 남아 있을 수 있다
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('롱프레스 → 편집 모드(✕·손잡이·완료), 완료로 끝낸다', (tester) async {
    final today = await pumpHome(tester);
    await db.todoDao.insertTodo(title: '물 마시기', date: today);
    await db.todoDao.insertTodo(
      title: '회의',
      date: today,
      scheduledTimeMinutes: 9 * 60,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(UnwindDragHandle), findsNothing);
    expect(find.text('Done'), findsNothing);

    // 시간 지정 항목도 롱프레스로 편집 모드에 들어간다
    await tester.longPress(find.text('회의'));
    await settle(tester);

    expect(find.text('Done'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete 물 마시기'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete 회의'), findsOneWidget);
    // 손잡이는 시간 없는 항목에만 — 시간 지정은 시계(시간순 고정)
    expect(find.byType(UnwindDragHandle), findsOneWidget);
    expect(find.bySemanticsLabel('Sorted by time'), findsOneWidget);
    expect(find.byType(UnwindLampSwitch), findsNothing);

    // 편집 중 타일 탭은 아무 일도 없다 — 입력 시트가 뜨지 않고 편집도 유지
    await tester.tap(find.text('물 마시기'));
    await settle(tester);
    expect(find.text('Add a note'), findsNothing);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('Done'), findsNothing);
    expect(find.byType(UnwindDragHandle), findsNothing);
    expect(find.byType(UnwindLampSwitch), findsNWidgets(2));
    await teardown(tester);
  });

  testWidgets('손잡이를 끌면 순서가 바뀌고 DB에 남는다', (tester) async {
    final today = await pumpHome(tester);
    for (final t in ['첫째', '둘째', '셋째']) {
      await db.todoDao.insertTodo(title: t, date: today);
    }
    await tester.pump(const Duration(milliseconds: 200));

    // 시간 없는 항목은 롱프레스가 곧 "들어 올리기" — 놓으면 편집 모드로 남는다
    await tester.longPress(find.text('첫째'));
    await settle(tester);
    expect(find.text('Done'), findsOneWidget);

    // 첫째의 손잡이를 끌어 맨 아래로
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UnwindDragHandle).first),
    );
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);

    expect([for (final t in await db.todoDao.getByDate(today)) t.title], [
      '둘째',
      '셋째',
      '첫째',
    ]);
    // 놓은 뒤에도 편집 모드는 이어진다 (아이폰처럼 여러 번 옮길 수 있다)
    expect(find.text('Done'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('빈 곳을 탭하면 편집이 끝난다', (tester) async {
    final today = await pumpHome(tester);
    await db.todoDao.insertTodo(title: '하나뿐', date: today);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.longPress(find.text('하나뿐'));
    await settle(tester);
    expect(find.text('Done'), findsOneWidget);

    // 목록 아래 빈 자리
    final list = find.byType(CustomScrollView);
    await tester.tapAt(tester.getBottomLeft(list) + const Offset(120, -40));
    await settle(tester);
    expect(find.text('Done'), findsNothing);
    await teardown(tester);
  });
}
