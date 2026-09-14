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
    final repo = container.read(todoRepositoryProvider);
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => repo.add(title: '할 일 $i', date: today));
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('할 일 0'), findsOneWidget);

    double top(Finder f) => tester.getTopLeft(f).dy;
    final toddBefore = top(find.byType(ToddView));
    final titleBefore = top(find.text('Today'));
    final cordBefore = top(find.byType(PullCord));
    final stripBefore = top(find.byType(WeeklyStrip));

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -120),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // 헤더·Todd는 함께 올라간다
    expect(top(find.byType(ToddView)), lessThan(toddBefore - 80));
    expect(top(find.text('Today')), lessThan(titleBefore - 80));
    // 전등 줄과 하단 스트립은 가만히
    expect(top(find.byType(PullCord)), cordBefore);
    expect(top(find.byType(WeeklyStrip)), stripBefore);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(db.close);
  });
}
