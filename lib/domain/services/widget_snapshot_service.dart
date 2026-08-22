import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';

import '../../data/db/tables/tables.dart';
import 'brightness_engine.dart';

/// iOS 홈 위젯에 넘기는 오늘의 스냅샷 (PRD 개정 2026-08-15).
///
/// 앱은 로컬 온리라 할 일 변경은 전부 앱 안에서만 일어난다 — 변이 때마다
/// 이 스냅샷을 App Group에 쓰면 위젯 숫자는 항상 정확하다.
/// 위젯(Swift)은 이 값 + 자기 시계로 Todd 모드를 판정한다. 위젯 쪽 판정
/// 로직은 ios/ToddWidget/ToddWidget.swift — toddModeProvider(§4)와 규칙을
/// 맞춰야 한다.
class WidgetSnapshot {
  /// 앱이 마지막으로 알고 있던 논리적 오늘. 위젯이 자기 시계로 계산한
  /// 오늘과 다르면(기상시간 지남 + 앱 미실행) 개수를 숨기고 아침 상태만
  /// 보여준다 — 롤오버(자동 미루기·반복 전개)는 앱에서만 실행되므로
  /// 확정 전 숫자를 보여주지 않는다 (발주자 결정 2026-08-15).
  final String dayKey;

  /// 남은(pending) 항목 수 — deferred 제외
  final int remaining;

  /// 오늘 카운트되는 전체 항목 수 (deferred 제외)
  final int total;

  final bool lightsOut;

  /// 조도 t (0=빛 가득, 1=소등) — 밤 표정(눈부심/꾸벅꾸벅) 분기용
  final double brightness;

  /// 오늘의 다크서클 (어제 restless 봉인)
  final bool darkCircles;

  final int wakeHour;
  final int bedtimeHour;

  /// 앱 언어 — 위젯 문구는 시스템이 아니라 앱 설정을 따른다
  final String languageCode;

  const WidgetSnapshot({
    required this.dayKey,
    required this.remaining,
    required this.total,
    required this.lightsOut,
    required this.brightness,
    required this.darkCircles,
    required this.wakeHour,
    required this.bedtimeHour,
    required this.languageCode,
  });

  /// 오늘 방의 할 일 상태에서 위젯 스냅샷을 만든다.
  factory WidgetSnapshot.fromTodos({
    required String dayKey,
    required Iterable<TodoStatus> statuses,
    required bool lightsOut,
    required double peakProgress,
    required bool darkCircles,
    required int wakeHour,
    required int bedtimeHour,
    required String languageCode,
  }) {
    final counted = statuses.where((s) => s != TodoStatus.deferred);
    final pending = counted.where((s) => s == TodoStatus.pending).length;
    final total = counted.length;
    final double t;
    if (lightsOut) {
      t = 1.0;
    } else if (total == 0) {
      t = BrightnessEngine.emptyRoomT;
    } else {
      t = peakProgress.clamp(0.0, 1.0);
    }
    return WidgetSnapshot(
      dayKey: dayKey,
      remaining: pending,
      total: total,
      lightsOut: lightsOut,
      brightness: t,
      darkCircles: darkCircles,
      wakeHour: wakeHour,
      bedtimeHour: bedtimeHour,
      languageCode: languageCode,
    );
  }
}

class WidgetSnapshotService {
  /// Runner·ToddWidget 양쪽 엔타이틀먼트와 일치해야 한다
  static const appGroupId = 'group.com.unwindapp.unwind';

  /// Swift 쪽 Widget kind 문자열과 일치해야 한다
  static const iOSWidgetName = 'ToddWidget';

  static const _channel = MethodChannel('unwind/widget_snapshot');

  int _epoch = 0;
  Future<void> _chain = Future<void>.value();
  Timer? _debounce;
  WidgetSnapshot? _pending;

  /// 디바운스 창 — 체크 하나에도 todos·days 두 스트림이 잇달아 방출돼
  /// write가 연달아 두 번 나간다. 리로드를 그만큼 쏘면 WidgetKit이 진행
  /// 중인 타임라인 생성에 뒤 리로드를 합쳐 버려(coalescing) **옛 파일을
  /// 읽은 결과가 최종본으로 남는** 간헐 이슈가 있었다 (2026-08-22).
  /// 버스트가 잦아들고 한 번만 쓴다.
  static const _debounceMs = 180;

  /// 마지막 write 결과 — 릴리즈 빌드에선 debugPrint가 보이지 않아, 실기기에서
  /// 실패해도 아무 흔적이 없었다. 설정 > 위젯 진단(dev)이 이 값을 읽는다.
  String lastResult = 'not written yet';

  /// 오늘의 스냅샷을 App Group에 쓴다 (디바운스 — 마지막 스냅샷만).
  ///
  /// [widgetSyncProvider]가 빌드마다 fire-and-forget으로 부른다. 도미노
  /// 소등처럼 변이가 연속되면 마지막 것 하나로 합쳐 쓰고 리로드도 한 번만
  /// 요청한다. 백그라운드 진입 직전 등 **지금 당장** 써야 하면 [flush].
  void write(WidgetSnapshot s) {
    _pending = s;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), _commit);
  }

  /// 디바운스 없이 즉시 쓴다 — 온보딩 커밋 직후(위젯 안내 전에 디스크에
  /// 있어야 한다), 앱이 백그라운드로 갈 때(타이머가 suspend로 얼기 전에).
  Future<void> flush(WidgetSnapshot s) {
    _pending = s;
    return _commit();
  }

  Future<void> _commit() {
    _debounce?.cancel();
    _debounce = null;
    final s = _pending;
    _pending = null;
    if (s == null) return _chain;
    // 겹치는 write는 세대 번호로 직렬화해 마지막 스냅샷만 반영한다
    final epoch = ++_epoch;
    _chain = _chain.catchError((_) {}).then((_) async {
      if (epoch != _epoch) return;
      await _persist(s);
    });
    return _chain;
  }

  /// App Group이 실제로 붙었는지 네이티브에 그대로 묻는다 (dev 진단용).
  Future<Map<String, Object?>> diagnose() async {
    if (kIsWeb || !Platform.isIOS) return {'error': 'iOS only'};
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('diagnose', {
        'appGroupId': appGroupId,
      });
      return r ?? {'error': 'null response'};
    } catch (e) {
      return {'error': '$e'};
    }
  }

  Future<void> _persist(WidgetSnapshot s) async {
    // 홈 위젯은 iOS만 (발주자 결정 2026-08-15). 테스트·macOS에선 no-op.
    if (kIsWeb || !Platform.isIOS) return;
    try {
      // 네이티브 브리지가 UserDefaults를 플러시하고 JSON 파일을 원자적으로
      // 쓴 뒤에 타임라인을 리로드한다 — home_widget saveWidgetData는
      // 디스크 반영 전에 reload해서 첫 설치 위젯이 빈 폴백에 고정됐다.
      await _channel.invokeMethod<bool>('persist', {
        'appGroupId': appGroupId,
        'kind': iOSWidgetName,
        'dayKey': s.dayKey,
        'remaining': s.remaining,
        'total': s.total,
        'lightsOut': s.lightsOut,
        'brightness': s.brightness,
        'darkCircles': s.darkCircles,
        'wakeHour': s.wakeHour,
        'bedtimeHour': s.bedtimeHour,
        'languageCode': s.languageCode,
      });
      lastResult = 'ok ${s.dayKey} ${s.remaining}/${s.total}';
    } catch (e, st) {
      // 위젯 미설치여도 앱은 계속 돌아야 한다. 삼키되 원인은 남긴다.
      // 릴리즈 빌드에선 debugPrint가 아무 데도 안 보이므로 결과도 붙잡아 둔다.
      lastResult = 'FAILED: $e';
      debugPrint('WidgetSnapshot persist failed: $e\n$st');
    }
  }
}
