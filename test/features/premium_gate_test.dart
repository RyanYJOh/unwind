import 'package:drift/native.dart';
import 'package:flutter/material.dart' show MaterialApp, TextField;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/haptics/haptics.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/db/tables/tables.dart';
import 'package:unwind/features/compose/date_bar.dart';
import 'package:unwind/features/premium/paywall_screen.dart';
import 'package:unwind/features/settings/settings_screen.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/l10n/generated/app_localizations.dart';
import 'package:unwind/main.dart';

/// Todd Plus 게이트 (수익화 2026-08-22) —
/// ① 무료는 반복 규칙 3개까지: 네 번째를 저장하려는 순간 페이월이 뜨고
///    규칙은 만들어지지 않는다 (Plus면 그대로 저장).
/// ② 무료는 조명 색 앰버만: 다른 스와치를 탭하면 페이월, 설정은 불변.
void main() {
  late UnwindDatabase db;

  setUp(() async {
    db = UnwindDatabase.withExecutor(NativeDatabase.memory());
    await db.settingsDao.setValue('onboardingCompleted', 'true');
  });

  Future<void> seedRules(int n) async {
    for (var i = 0; i < n; i++) {
      await db.recurrenceDao.create(
        title: '습관 $i',
        rule: RecurrenceRule.daily,
        startDate: '2026-08-22',
      );
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const UnwindApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// FAB → 시트 → 제목 입력 → 매일 반복 선택 → 저장
  Future<void> trySaveRecurring(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Add a task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, '네 번째 습관');
    await tester.tap(find.text('Every day'));
    await tester.pump();
    tester.widget<DateBar>(find.byType(DateBar)).onSave();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // 페이월 push 전환
  }

  testWidgets('무료 + 규칙 3개 → 네 번째 저장 시 페이월, 규칙은 그대로 3개', (tester) async {
    await seedRules(3);
    await pumpApp(tester);
    await trySaveRecurring(tester);

    expect(
      find.descendant(
        of: find.byType(PaywallScreen),
        matching: find.text('TODD PLUS'),
      ),
      findsOneWidget,
    );
    expect((await db.recurrenceDao.getActive()).length, 3);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('Plus면 네 번째 반복도 그대로 저장된다', (tester) async {
    await seedRules(3);
    await db.settingsDao.setValue('premiumEnabled', 'true');
    await pumpApp(tester);
    await trySaveRecurring(tester);

    expect(find.byType(PaywallScreen), findsNothing);
    expect((await db.recurrenceDao.getActive()).length, 4);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('무료가 앰버 외 스와치를 탭하면 페이월, 설정은 앰버 유지', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: UnwindHapticsScope(
          haptics: UnwindHaptics(enabled: false),
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.bySemanticsLabel('Rose'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(await db.settingsDao.getValue('lightColor'), isNot('rose'));

    // 페이월 CTA — 구독하면 Plus가 켜지고 축하 뒤 닫힌다
    await tester.tap(find.text('Join Todd'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600)); // 축하 1.4s + 닫힘
    expect(await db.settingsDao.getValue('premiumEnabled'), 'true');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
