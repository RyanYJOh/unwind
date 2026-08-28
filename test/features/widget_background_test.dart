import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons, MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/haptics/haptics.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/domain/models/widget_background.dart';
import 'package:unwind/features/premium/paywall_screen.dart';
import 'package:unwind/features/settings/widget_background_strip.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/l10n/generated/app_localizations.dart';
import 'package:unwind/ui/ui.dart';

/// 위젯 배경 (선택형 2026-08-28) — §8.7 게이트 ③.
/// 설정 스트립: 깊은 밤 외 전부 Plus (잠금 + 페이월), 탭 = 선택 + 설치
/// 안내 시트. 저장된 선택은 게이트 밖에서도 남는다.
void main() {
  test('fromName — 모르는 값·null은 기본 깊은 밤', () {
    expect(WidgetBackground.fromName('aurora'), WidgetBackground.aurora);
    expect(WidgetBackground.fromName('nope'), WidgetBackground.deepNight);
    expect(WidgetBackground.fromName(null), WidgetBackground.deepNight);
  });

  test('effective — 무료는 항상 깊은 밤, 저장값은 게이트 밖에서 유지', () {
    expect(
      WidgetBackground.effective(premium: false, stored: 'blanketFort'),
      WidgetBackground.deepNight,
    );
    expect(
      WidgetBackground.effective(premium: true, stored: 'blanketFort'),
      WidgetBackground.blanketFort,
    );
    expect(
      WidgetBackground.effective(premium: true, stored: null),
      WidgetBackground.deepNight,
    );
  });

  Future<UnwindDatabase> pumpStrip(
    WidgetTester tester, {
    required bool premium,
  }) async {
    final db = UnwindDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await db.settingsDao.setValue('premiumEnabled', '$premium');
    // 9칸 스트립이 가로로 다 들어오게 (가로 스크롤 뷰포트)
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UnwindHapticsScope(
            haptics: UnwindHaptics(),
            child: const UnwindScreen(
              child: Center(child: WidgetBackgroundStrip()),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return db;
  }

  testWidgets('무료: 깊은 밤 외 전부 잠금 — 탭하면 페이월, 설정 불변', (tester) async {
    final db = await pumpStrip(tester, premium: false);

    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(8));

    await tester.tap(find.text('Fireflies'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(await db.settingsDao.getValue('widgetBackground'), isNull);
  });

  testWidgets('Plus: 탭하면 선택이 저장되고 설치 안내 시트가 뜬다', (tester) async {
    final db = await pumpStrip(tester, premium: true);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);

    await tester.ensureVisible(find.text('Blanket Fort'));
    await tester.pump();
    await tester.tap(find.text('Blanket Fort'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(await db.settingsDao.getValue('widgetBackground'), 'blanketFort');
    // 설치 안내 시트 — 온보딩 3단계 문구 재사용
    expect(find.text('Go to the Home Screen'), findsOneWidget);
    expect(find.text('Got it!'), findsOneWidget);
  });
}
