import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:home_widget/home_widget.dart';

/// iOS 홈 위젯에 넘기는 오늘의 스냅샷 (PRD 개정 2026-08-15).
///
/// 앱은 로컬 온리라 할 일 변경은 전부 앱 안에서만 일어난다 — 변이 때마다
/// 이 스냅샷을 App Group UserDefaults에 쓰면 위젯 숫자는 항상 정확하다.
/// 위젯(Swift)은 이 값 + 자기 시계로 Lumi 모드를 판정한다. 위젯 쪽 판정
/// 로직은 ios/LumiWidget/LumiWidget.swift — lumiModeProvider(§4)와 규칙을
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
}

class WidgetSnapshotService {
  /// Runner·LumiWidget 양쪽 엔타이틀먼트와 일치해야 한다
  static const appGroupId = 'group.com.unwindapp.unwind';

  /// Swift 쪽 Widget kind 문자열과 일치해야 한다
  static const iOSWidgetName = 'LumiWidget';

  bool _groupSet = false;

  Future<void> write(WidgetSnapshot s) async {
    // 홈 위젯은 iOS만 (발주자 결정 2026-08-15). 테스트·macOS에선 no-op.
    if (kIsWeb || !Platform.isIOS) return;
    try {
      if (!_groupSet) {
        await HomeWidget.setAppGroupId(appGroupId);
        _groupSet = true;
      }
      await Future.wait([
        HomeWidget.saveWidgetData('dayKey', s.dayKey),
        HomeWidget.saveWidgetData('remaining', s.remaining),
        HomeWidget.saveWidgetData('total', s.total),
        HomeWidget.saveWidgetData('lightsOut', s.lightsOut),
        HomeWidget.saveWidgetData('brightness', s.brightness),
        HomeWidget.saveWidgetData('darkCircles', s.darkCircles),
        HomeWidget.saveWidgetData('wakeHour', s.wakeHour),
        HomeWidget.saveWidgetData('bedtimeHour', s.bedtimeHour),
        HomeWidget.saveWidgetData('languageCode', s.languageCode),
      ]);
      await HomeWidget.updateWidget(iOSName: iOSWidgetName);
    } catch (_) {
      // 위젯 미설치·플러그인 부재 — 앱 동작에 영향을 주지 않는다
    }
  }
}
