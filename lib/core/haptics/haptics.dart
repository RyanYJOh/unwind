import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 햅틱 어휘 — 설정(§6.7)의 hapticsEnabled로 일괄 차단 가능해야 한다.
/// §9.5: Reduce Motion이 켜져도 햅틱은 유지한다(모션이 아니다).
///
/// 개편 2026-08-12 (디자인 시스템 v2): **모든 인터랙션에 햅틱이 붙는다.**
/// 개별 화면이 직접 `HapticFeedback`을 부르지 않고, 여기 정의된 의미 단위만
/// 쓴다. `lib/ui/`의 컴포넌트들은 [UnwindHapticsScope]를 통해 자동으로
/// 발사하므로, 컴포넌트를 쓰면 햅틱은 공짜다.
class UnwindHaptics {
  bool enabled;

  UnwindHaptics({this.enabled = true});

  // ── 기본 어휘 ─────────────────────────────────────────────
  /// 탭 가능한 모든 것의 기본 — 버튼·칩·행·아이콘
  Future<void> tap() async {
    if (enabled) await HapticFeedback.lightImpact();
  }

  /// 값이 한 칸 움직임 — 날짜 이동, 피커, 세그먼트 전환
  Future<void> selection() async {
    if (enabled) await HapticFeedback.selectionClick();
  }

  /// 스위치 토글. 끄는 쪽이 이 앱의 주된 행동이라 더 묵직하다.
  Future<void> toggle({required bool on}) async {
    if (!enabled) return;
    if (on) {
      await tadak();
    } else {
      await switchOff();
    }
  }

  /// 등을 **끄는** "철커덕" — medium → heavy (개정 2026-08-12, §9.2).
  /// 진짜 벽 스위치를 내리는 무게감을 준다. 이 앱에서 가장 중요한 촉감이라
  /// 다른 어떤 인터랙션보다 세다.
  Future<void> switchOff() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 55));
    await HapticFeedback.heavyImpact();
  }

  /// 등을 **켜는** "타닥" — light → medium 연속 (§9.2)
  Future<void> tadak() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 45));
    await HapticFeedback.mediumImpact();
  }

  // ── 결과 피드백 ───────────────────────────────────────────
  /// 저장·추가 성공
  Future<void> success() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 70));
    await HapticFeedback.lightImpact();
  }

  /// 되돌릴 수 없는 것 직전 / 막힌 조작
  Future<void> warning() async {
    if (enabled) await HapticFeedback.mediumImpact();
  }

  /// 삭제 확정 등 무거운 결과
  Future<void> error() async {
    if (!enabled) return;
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.mediumImpact();
  }

  // ── 시트·오버레이 ─────────────────────────────────────────
  Future<void> sheetOpen() => selection();
  Future<void> sheetClose() => tap();

  // ── 연출 전용 (도미노·전등 줄) ────────────────────────────
  /// 소등 도미노의 각 등(§9.3)
  Future<void> light() async {
    if (enabled) await HapticFeedback.lightImpact();
  }

  /// 전등 줄 임계점 통과(§6.4)
  Future<void> medium() async {
    if (enabled) await HapticFeedback.mediumImpact();
  }

  /// 마지막 등 — 길고 낮은 울림(§9.3)
  Future<void> heavy() async {
    if (enabled) await HapticFeedback.heavyImpact();
  }

  /// 전등 줄 tension 틱 (개정 2026-08-07, §6.4) — 가장 가벼운 틱
  Future<void> tensionTick() async {
    if (enabled) await HapticFeedback.selectionClick();
  }
}

/// 햅틱을 위젯 트리에 흘려보낸다.
///
/// `lib/ui/`의 컴포넌트는 Riverpod을 모른다(§5.6 성능 계약과 같은 이유로
/// 순수 위젯으로 유지). 대신 앱 루트에서 이 스코프를 꽂아 두면 어디서든
/// `UnwindHapticsScope.of(context)`로 설정이 반영된 인스턴스를 얻는다.
class UnwindHapticsScope extends InheritedWidget {
  final UnwindHaptics haptics;

  const UnwindHapticsScope({
    super.key,
    required this.haptics,
    required super.child,
  });

  /// 스코프가 없으면(테스트·프리뷰) 켜진 기본 인스턴스로 폴백한다.
  static UnwindHaptics of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<UnwindHapticsScope>()
          ?.haptics ??
      _fallback;

  static final _fallback = UnwindHaptics();

  @override
  bool updateShouldNotify(UnwindHapticsScope oldWidget) =>
      oldWidget.haptics != haptics ||
      oldWidget.haptics.enabled != haptics.enabled;
}
