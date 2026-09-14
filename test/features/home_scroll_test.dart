import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/features/today/today_screen.dart';
import 'package:unwind/features/week/weekly_strip.dart';
import 'package:unwind/main.dart';
import 'package:unwind/widgets/pull_cord.dart';
import 'package:unwind/widgets/todd/todd_view.dart';

/// 홈 스크롤 (개정 2026-09-14) — 헤더·Todd·체크리스트가 함께 스크롤되고,
/// 전등 줄과 하단 스트립은 제자리에 남는다.
void main() {
  late UnwindDatabase db;

  setUp(() {
    db = UnwindDatabase.withExecutor(NativeDatabase.memory());
  });

  testWidgets('위로 스크롤하면 Todd도 올라가고 전등 줄·스트립은 고정', (tester) async {
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

    // 화면을 넘칠 만큼 할 일을 채운다
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
    );
    final today = container.read(todayKeyProvider);
    for (var i = 0; i < 20; i++) {
      await db.todoDao.insertTodo(title: '할 일 $i', date: today);
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('할 일 0'), findsOneWidget);

    double top(Finder f) => tester.getTopLeft(f).dy;
    final toddBefore = top(find.byType(ToddView));
    final titleBefore = top(find.text('Today'));
    final cordBefore = top(find.byType(PullCord));
    final stripBefore = top(find.byType(WeeklyStrip));

    // 천천히 끌어 fling 없이 약 120pt만 스크롤한다 (빠르게 끌면 관성으로
    // 헤더가 캐시 범위 밖까지 밀려 트리에서 빠진다)
    await tester.timedDrag(
      find.byType(CustomScrollView),
      const Offset(0, -120),
      const Duration(milliseconds: 600),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // 헤더·Todd는 함께 올라간다
    expect(top(find.byType(ToddView)), lessThan(toddBefore - 80));
    // 헤더는 화면 위로 완전히 밀려났다 — 트리에는 남아 있으니 offstage도 찾는다
    expect(
      top(find.text('Today', skipOffstage: false)),
      lessThan(titleBefore - 80),
    );
    // 전등 줄과 하단 스트립은 가만히
    expect(top(find.byType(PullCord)), cordBefore);
    expect(top(find.byType(WeeklyStrip)), stripBefore);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
