import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/analytics/tracking_consent.dart';

/// ATT 동의 (2026-09-02) — 첫 실행 프롬프트의 Dart 쪽 계약.
/// 네이티브 문자열은 `AppDelegate.trackingStatusName()`과 맞춰져 있다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock(String? Function(String method) reply) {
    messenger.setMockMethodCallHandler(TrackingConsent.channel, (call) async {
      calls.add(call.method);
      return reply(call.method);
    });
  }

  setUp(() {
    calls.clear();
    TrackingConsent.resetForTest();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(TrackingConsent.channel, null);
    TrackingConsent.resetForTest();
  });

  test('네이티브 상태 문자열을 enum으로 옮긴다', () async {
    mock((_) => 'authorized');
    expect(await TrackingConsent.requestOnLaunch(), TrackingStatus.authorized);
    expect(calls, ['request']);
  });

  test('모르는 값·null은 unsupported로 떨어진다', () async {
    mock((_) => null);
    expect(await TrackingConsent.status(), TrackingStatus.unsupported);
    expect(TrackingStatus.fromName('무엇'), TrackingStatus.unsupported);
  });

  test('프로세스당 한 번만 요청한다 — 프롬프트가 겹치지 않게', () async {
    mock((_) => 'denied');
    final first = await TrackingConsent.requestOnLaunch();
    final second = await TrackingConsent.requestOnLaunch();
    expect(first, TrackingStatus.denied);
    expect(second, TrackingStatus.denied);
    expect(calls, ['request']); // 두 번째는 첫 호출의 결과를 그대로 쓴다
  });

  test('채널이 없는 환경(테스트·Android)에서도 던지지 않는다', () async {
    // 핸들러를 달지 않으면 MissingPluginException이 난다
    expect(await TrackingConsent.requestOnLaunch(), TrackingStatus.unsupported);
  });
}
