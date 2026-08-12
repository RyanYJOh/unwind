import 'dart:math' as math;

/// §5 조도 엔진 — 이 앱의 심장. 순수 로직만 담고 단위 테스트를 반드시 작성한다.
///
/// t: 0.0(가장 밝음) ~ 1.0(완전한 밤)
class BrightnessEngine {
  /// §5.3 할 일 0개(빈 방)일 때 고정값
  static const emptyRoomT = 0.15;

  /// 그날 도달한 최대 진행률. days.peakProgress로 영속화된다.
  double _peakProgress;

  /// 전등 줄을 당겼는가 (§5.3 — 당긴 후 t=1.0 고정)
  bool _lightsOut;

  // 명명 인자는 private 필드 initializing formal을 쓸 수 없다.
  BrightnessEngine({double peakProgress = 0.0, bool lightsOut = false})
    // ignore: prefer_initializing_formals
    : _peakProgress = peakProgress,
      // ignore: prefer_initializing_formals
      _lightsOut = lightsOut;

  double get peakProgress => _peakProgress;
  bool get lightsOut => _lightsOut;

  /// §5.1 진행률 계산
  static double rawProgress({required int doneCount, required int totalCount}) {
    return doneCount / math.max(totalCount, 1);
  }

  /// §5.2 단조 감소 규칙 + §5.3 경계 조건이 적용된 현재 조도.
  double t({required int doneCount, required int totalCount}) {
    if (_lightsOut) return 1.0;
    if (totalCount == 0) return emptyRoomT;
    return _peakProgress;
  }

  /// 항목 추가: peakProgress 유지 (rawProgress가 떨어져도 무시)
  void onItemAdded({required int doneCount, required int totalCount}) {
    // 의도적으로 아무것도 하지 않는다 — 미리 계획하는 행동에 벌을 주지 않는다.
  }

  /// 항목 완료: peakProgress = max(peak, raw)
  void onItemCompleted({required int doneCount, required int totalCount}) {
    _peakProgress = math.max(
      _peakProgress,
      rawProgress(doneCount: doneCount, totalCount: totalCount),
    );
  }

  /// 완료 취소: peakProgress = raw (명시적 되돌리기이므로 하강 허용)
  void onItemUncompleted({required int doneCount, required int totalCount}) {
    _peakProgress = rawProgress(doneCount: doneCount, totalCount: totalCount);
  }

  /// 항목 삭제: peakProgress = max(peak, raw)
  void onItemDeleted({required int doneCount, required int totalCount}) {
    _peakProgress = math.max(
      _peakProgress,
      rawProgress(doneCount: doneCount, totalCount: totalCount),
    );
  }

  /// 전등 줄을 당김 (§6.4) — 이후 항목을 추가해도 t=1.0 유지
  void pullCord() {
    _lightsOut = true;
    _peakProgress = 1.0;
  }

  /// 자정 롤오버 (§5.3) — 새 날의 값으로 재계산
  void rollover() {
    _peakProgress = 0.0;
    _lightsOut = false;
  }
}
