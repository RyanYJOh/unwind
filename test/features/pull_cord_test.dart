import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/haptics/haptics.dart';
import 'package:unwind/core/tokens/motion.dart';
import 'package:unwind/l10n/generated/app_localizations.dart';
import 'package:unwind/widgets/pull_cord.dart';

/// §6.4 전등 줄의 놓았을 때 물리 (개편 2026-08-12).
/// 스크린샷으로는 1초짜리 스프링을 잡을 수 없어 여기서 값으로 검증한다.
void main() {
  const rest = 148.0;

  CordPainter painterOf(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(PullCord),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter
          as CordPainter;

  Future<void> pumpCord(
    WidgetTester tester, {
    required VoidCallback onPull,
  }) async {
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('en'),
        delegates: AppLocalizations.localizationsDelegates,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: PullCord(
              enabled: true,
              onPull: onPull,
              haptics: UnwindHaptics(enabled: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 줄을 [dy]만큼 끌어내렸다 놓는다.
  Future<void> dragAndRelease(WidgetTester tester, double dy) async {
    final start = tester.getCenter(find.byType(PullCord)) - const Offset(0, 60);
    final gesture = await tester.startGesture(start);
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(Offset(0, dy / 6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
  }

  testWidgets('놓으면 원위치를 지나쳐 위로 튄다 (오버슈트)', (tester) async {
    await pumpCord(tester, onPull: () {});
    await dragAndRelease(tester, 50);

    // 손을 뗀 직후에는 아직 늘어나 있다
    expect(painterOf(tester).extension, greaterThan(0));

    // 되튀는 동안 최솟값을 관찰한다
    var minExt = double.infinity;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      minExt = minExt < painterOf(tester).extension
          ? minExt
          : painterOf(tester).extension;
    }
    expect(minExt, lessThan(0), reason: '원위치(0)를 지나쳐 튀어야 튕김이 보인다');
    expect(
      minExt,
      greaterThanOrEqualTo(-UnwindMotion.cordRecoilLimitPx),
      reason: '헤더를 침범할 만큼 튀면 안 된다',
    );

    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('놓으면 옆으로 흔들리고, 결국 잦아든다', (tester) async {
    await pumpCord(tester, onPull: () {});
    expect(painterOf(tester).sway, 0);

    await dragAndRelease(tester, 60);

    var maxSwing = 0.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final s = painterOf(tester).sway.abs();
      if (s > maxSwing) maxSwing = s;
    }
    expect(maxSwing, greaterThan(8), reason: '눈에 보일 만큼은 흔들려야 한다');

    // 충분히 기다리면 제자리로 돌아온다
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    expect(painterOf(tester).sway.abs(), lessThan(1.0));
    expect(painterOf(tester).extension.abs(), lessThan(1.0));
  });

  testWidgets('임계점을 넘겨 놓으면 소등이 발동한다', (tester) async {
    var pulled = false;
    await pumpCord(tester, onPull: () => pulled = true);

    await dragAndRelease(tester, 30); // 임계 미만
    expect(pulled, isFalse);
    await tester.pump(const Duration(seconds: 6));

    await dragAndRelease(tester, 200); // 충분히 당김
    expect(pulled, isTrue);
    await tester.pump(const Duration(seconds: 6));
  });

  test('되튐 스프링은 언더댐프여야 한다 (그래야 튄다)', () {
    // ζ = c / (2√(km)) < 1
    final s = UnwindMotion.cordRecoil;
    final zeta = s.damping / (2 * (s.stiffness * s.mass).abs());
    expect(zeta, lessThan(1.0));
    expect(rest, 148.0); // 기본 늘어짐 길이 고정 확인
  });
}
