import 'package:flutter/services.dart';

/// 햅틱 래퍼 — 설정(§6.7)의 hapticsEnabled로 일괄 차단 가능해야 한다.
/// §9.5: Reduce Motion이 켜져도 햅틱은 유지한다(모션이 아니다).
class UnwindHaptics {
  bool enabled;

  UnwindHaptics({this.enabled = true});

  /// 개별 체크(§9.2), 소등 도미노의 각 등(§9.3)
  Future<void> light() async {
    if (enabled) await HapticFeedback.lightImpact();
  }

  /// 개별 체크 "타닥" — light → medium 연속 (개정 2026-08-07, §9.2)
  Future<void> tadak() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 45));
    await HapticFeedback.mediumImpact();
  }

  /// 전등 줄 tension 틱 (개정 2026-08-07, §6.4) — 가장 가벼운 틱
  Future<void> tensionTick() async {
    if (enabled) await HapticFeedback.selectionClick();
  }

  /// 전등 줄 임계점 통과(§6.4)
  Future<void> medium() async {
    if (enabled) await HapticFeedback.mediumImpact();
  }

  /// 마지막 등 — 길고 낮은 울림(§9.3)
  Future<void> heavy() async {
    if (enabled) await HapticFeedback.heavyImpact();
  }

  /// 입력 시트 날짜 변경(§6.3)
  Future<void> selection() async {
    if (enabled) await HapticFeedback.selectionClick();
  }
}
