import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/haptics/haptics.dart';
import 'package:unwind/core/tokens/spacing.dart';
import 'package:unwind/ui/ui.dart';

/// 디자인 시스템 v2 컴포넌트 계약.
/// 물성(3D)·햅틱·접근성은 컴포넌트가 책임진다 — 화면이 아니라 여기서 검증한다.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {UnwindHaptics? h}) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: UnwindHapticsScope(
          haptics: h ?? UnwindHaptics(),
          child: Center(child: child),
        ),
      ),
    );
  }

  group('UnwindPressable', () {
    testWidgets('누르면 압출면 높이만큼 내려앉지만 레이아웃은 변하지 않는다', (tester) async {
      await pump(
        tester,
        UnwindPressable(
          onTap: () {},
          child: const SizedBox(width: 100, height: 40),
        ),
      );
      final finder = find.byType(UnwindPressable);
      final before = tester.getSize(finder);

      final gesture = await tester.press(finder);
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getSize(finder), before, reason: '눌러도 자리를 차지하는 크기는 같다');

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 120));
    });

    testWidgets('압출 높이만큼 아래 여백을 미리 잡는다', (tester) async {
      await pump(
        tester,
        UnwindPressable(
          onTap: () {},
          depth: UnwindDepth.base,
          child: const SizedBox(width: 100, height: 40),
        ),
      );
      expect(
        tester.getSize(find.byType(UnwindPressable)).height,
        40 + UnwindDepth.base,
      );
    });

    testWidgets('탭하면 햅틱이 나가고 콜백이 실행된다', (tester) async {
      var tapped = false;
      final log = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') log.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pump(
        tester,
        UnwindPressable(
          onTap: () => tapped = true,
          child: const SizedBox(width: 100, height: 40),
        ),
      );
      await tester.tap(find.byType(UnwindPressable));
      await tester.pump();
      await tester.idle();

      expect(tapped, isTrue);
      expect(log, isNotEmpty, reason: '모든 인터랙션에는 햅틱이 붙는다');
    });

    testWidgets('설정에서 햅틱을 끄면 아무것도 나가지 않는다', (tester) async {
      final log = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') log.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pump(
        tester,
        UnwindPressable(
          onTap: () {},
          child: const SizedBox(width: 100, height: 40),
        ),
        h: UnwindHaptics(enabled: false),
      );
      await tester.tap(find.byType(UnwindPressable));
      await tester.pump();
      await tester.idle();
      expect(log, isEmpty);
    });
  });

  group('터치 타깃 (§12: 44pt)', () {
    testWidgets('UnwindIconButton은 최소 44pt', (tester) async {
      await pump(
        tester,
        UnwindIconButton(
          icon: const IconData(0xe000, fontFamily: 'MaterialIcons'),
          onPressed: () {},
        ),
      );
      final size = tester.getSize(find.byType(UnwindIconButton));
      expect(size.width, greaterThanOrEqualTo(UnwindTouch.minTarget));
      expect(size.height, greaterThanOrEqualTo(UnwindTouch.minTarget));
    });

    testWidgets('UnwindLampSwitch는 최소 44pt', (tester) async {
      await pump(
        tester,
        UnwindLampSwitch(
          isOn: true,
          onTap: () {},
          semanticsOn: 'On',
          semanticsOff: 'Off',
        ),
      );
      final size = tester.getSize(find.byType(UnwindLampSwitch));
      expect(size.width, greaterThanOrEqualTo(UnwindTouch.minTarget));
      expect(size.height, greaterThanOrEqualTo(UnwindTouch.minTarget));
    });
  });

  group('UnwindLampSwitch 접근성', () {
    testWidgets('토글 상태와 값을 스크린리더에 보고한다', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        UnwindLampSwitch(
          isOn: true,
          onTap: () {},
          semanticsOn: 'On',
          semanticsOff: 'Off',
        ),
      );
      final node = tester.getSemantics(find.byType(UnwindLampSwitch));
      expect(node.label, 'On');
      expect(node.value, 'On');
      handle.dispose();
    });
  });

  group('UnwindButton', () {
    testWidgets('onPressed가 null이면 눌리지 않는다', (tester) async {
      await pump(
        tester,
        const SizedBox(
          width: 300,
          child: UnwindButton(label: 'Save', onPressed: null),
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pump();
      // 예외 없이 통과하면 된다 — 비활성 버튼은 조용하다
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
