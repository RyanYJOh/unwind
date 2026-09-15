import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/domain/services/widget_snapshot_service.dart';

/// 위젯 스냅샷 서비스의 리로드 절약 계약 (2026-09-11).
///
/// WidgetKit은 위젯마다 하루 40~70회의 리로드 버짓을 주고, 소진되면
/// 포그라운드 앱의 리로드까지 다음 날까지 무시한다. 그래서 persist 한 번
/// (= 리로드 한 번)은 **내용이 바뀌었을 때만** 나가야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  WidgetSnapshot snap({int remaining = 2, int total = 3}) => WidgetSnapshot(
    dayKey: '2026-09-11',
    remaining: remaining,
    total: total,
    lightsOut: false,
    brightness: 0.3,
    darkCircles: false,
    wakeHour: 5,
    bedtimeHour: 22,
    languageCode: 'ko',
  );

  late List<MethodCall> calls;
  late bool fail;

  setUp(() {
    calls = [];
    fail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WidgetSnapshotService.channel, (call) async {
          calls.add(call);
          if (fail) throw PlatformException(code: 'persist-failed');
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WidgetSnapshotService.channel, null);
  });

  List<MethodCall> persists() =>
      calls.where((c) => c.method == 'persist').toList();

  test('같은 스냅샷을 다시 플러시하면 persist(=리로드)가 나가지 않는다', () async {
    final service = WidgetSnapshotService(platformSupported: true);
    await service.flush(snap());
    await service.flush(snap());
    await service.flush(snap());
    expect(persists(), hasLength(1));
    expect(service.lastResult, startsWith('unchanged'));
  });

  test('내용이 바뀌면 다시 쓴다', () async {
    final service = WidgetSnapshotService(platformSupported: true);
    await service.flush(snap(remaining: 2));
    await service.flush(snap(remaining: 1));
    expect(service.lastResult, 'ok 2026-09-11 1/3');
    await service.flush(snap(remaining: 1));
    final p = persists();
    expect(p, hasLength(2));
    expect(p.last.arguments['remaining'], 1);
    expect(service.lastResult, 'unchanged 2026-09-11 1/3');
  });

  test('persist가 실패했으면 같은 값이라도 다음에 반드시 다시 쓴다', () async {
    final service = WidgetSnapshotService(platformSupported: true);
    fail = true;
    await service.flush(snap());
    expect(service.lastResult, startsWith('FAILED'));
    fail = false;
    await service.flush(snap());
    expect(persists(), hasLength(2));
    expect(service.lastResult, startsWith('ok'));
  });

  test('디스크가 이미 같은 내용이면(브리지 false) 기록만 남기고 다음에도 다시 쓰지 않는다', () async {
    final service = WidgetSnapshotService(platformSupported: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WidgetSnapshotService.channel, (call) async {
          calls.add(call);
          return false; // 브리지: 파일이 이미 같은 페이로드
        });
    await service.flush(snap());
    expect(service.lastResult, contains('same-on-disk'));
    await service.flush(snap());
    expect(persists(), hasLength(1));
  });

  test('persist 뒤에 확인 리로드를 따로 쏘지 않는다', () async {
    final service = WidgetSnapshotService(platformSupported: true);
    await service.flush(snap());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls.map((c) => c.method), ['persist']);
  });

  testWidgets('write는 180ms 버스트를 한 번으로 합친다', (tester) async {
    final service = WidgetSnapshotService(platformSupported: true);
    service.write(snap(remaining: 3));
    service.write(snap(remaining: 2));
    service.write(snap(remaining: 1));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    final p = persists();
    expect(p, hasLength(1));
    expect(p.single.arguments['remaining'], 1);
  });

  test('iOS가 아니면 채널을 건드리지 않는다', () async {
    final service = WidgetSnapshotService(platformSupported: false);
    await service.flush(snap());
    expect(calls, isEmpty);
    expect(service.lastResult, 'not written yet');
  });
}
