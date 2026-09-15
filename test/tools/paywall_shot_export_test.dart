import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/haptics/haptics.dart';
import 'package:unwind/core/tokens/palette.dart';
import 'package:unwind/core/tokens/typography.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/features/premium/paywall_screen.dart';
import 'package:unwind/features/premium/premium_providers.dart';
import 'package:unwind/features/premium/purchases_service.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/l10n/generated/app_localizations.dart';

/// 페이월 스크린샷 추출 — App Store Connect 인앱 상품 심사용 (2026-09-15).
///
///   PAYWALL_EXPORT=1 flutter test test/tools/paywall_shot_export_test.dart
///
/// → build/paywall/{en,ko}.png (iPhone 6.9" 1320×2868). 실제 PaywallScreen을
/// 렌더하고, 가격은 App Store Connect에 등록한 값을 가짜 스토어로 넣는다
/// (RevenueCat Offering이 돌려줄 문자열과 같은 모양). 평소 flutter test에선 skip.
const _w = 440.0, _h = 956.0, _dpr = 3.0;

const _prices = {
  'en': {
    ToddPlan.monthly: ('\$3.99', null),
    ToddPlan.yearly: ('\$23.99', '\$1.99'),
    ToddPlan.lifetime: ('\$59.99', null),
  },
  'ko': {
    ToddPlan.monthly: ('₩4,900', null),
    ToddPlan.yearly: ('₩29,000', '₩2,417'),
    ToddPlan.lifetime: ('₩79,000', null),
  },
};

class _StorePrices extends PurchasesService {
  _StorePrices(this.lang);
  final String lang;

  @override
  Future<Map<ToddPlan, PlanOffer>?> loadPlans() async => {
    for (final e in _prices[lang]!.entries)
      e.key: PlanOffer(
        plan: e.key,
        priceString: e.value.$1,
        pricePerMonthString: e.value.$2,
      ),
  };
}

Future<void> _loadFonts() async {
  Future<void> load(String family, File file) async {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }

  await load('Pretendard', File('assets/fonts/PretendardVariable.ttf'));
  // 혜택 행의 이모지(🌈♾️🌙✨👇) — 테스트 엔진엔 이모지 폰트가 없어 두부가 된다
  final emoji = File('/System/Library/Fonts/Apple Color Emoji.ttc');
  if (emoji.existsSync()) await load('Apple Color Emoji', emoji);
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) await load('MaterialIcons', icons);
  }
}

void main() {
  final export = Platform.environment['PAYWALL_EXPORT'] == '1';

  testWidgets('export paywall screenshots', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(_w * _dpr, _h * _dpr);
    tester.view.devicePixelRatio = _dpr;
    tester.view.padding = const FakeViewPadding(top: 62 * _dpr, bottom: 34 * _dpr);
    addTearDown(tester.view.reset);

    for (final lang in ['en', 'ko']) {
      final db = UnwindDatabase.withExecutor(NativeDatabase.memory());
      await db.settingsDao.setValue('onboardingCompleted', 'true');
      await db.settingsDao.setValue('languageCode', lang);

      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            purchasesServiceProvider.overrideWithValue(_StorePrices(lang)),
          ],
          child: RepaintBoundary(
            key: key,
            child: UnwindHapticsScope(
              haptics: UnwindHaptics(enabled: false),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  brightness: Brightness.dark,
                  fontFamily: UnwindType.fontFamily,
                  scaffoldBackgroundColor: UnwindColors.ink,
                ),
                locale: Locale(lang),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const PaywallScreen(),
              ),
            ),
          ),
        ),
      );

      // 몸통 PNG 에셋 로드(실 IO) + 요금제 로드 대기
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();
      }
      // 까르르 인사(0.5s + 1.3s)가 끝나 평온한 얼굴로
      await tester.pump(const Duration(milliseconds: 2500));

      Future<void> capture(String name) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: _dpr);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          return data!.buffer.asUint8List();
        });
        File('build/paywall/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!);
      }

      // ① 첫 화면 — Todd + 혜택
      await capture(lang);

      // ② 끝까지 스크롤 — 세 요금제(월간·연간·평생)가 모두 보이는 컷.
      // 인앱 상품 심사 스크린샷은 이쪽 (상품이 화면에 보여야 한다)
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await capture('${lang}_plans');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 80));
      await db.close();
    }
  }, skip: !export);
}
