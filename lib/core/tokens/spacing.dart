/// §8.3 간격 · 반경 · 터치 타깃 · 깊이.
/// 값 하드코딩 금지 — UI는 이 상수만 쓴다.
abstract final class UnwindSpacing {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
}

/// 개편 2026-08-12: 듀오링고식으로 전반적으로 둥글고 두툼하게.
abstract final class UnwindRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;
}

abstract final class UnwindTouch {
  /// 최소 터치 타깃 (§8.3, §12)
  static const double minTarget = 44;

  /// 주 CTA 높이 — 듀오링고식 큼직한 버튼
  static const double ctaHeight = 56;

  /// 작은 버튼 높이
  static const double buttonSmallHeight = 44;

  /// 할 일 타일 최소 높이
  static const double tileHeight = 62;
}

/// 3D 압출 깊이 — **blur 0의 오프셋 그림자**로만 표현한다 (§11 블러 금지).
/// 누르면 이 만큼 내려앉고 그림자가 사라진다: "물성"의 전부.
abstract final class UnwindDepth {
  /// 주 CTA·타일
  static const double base = 4;

  /// 칩·작은 버튼
  static const double small = 3;

  /// 눌림 애니메이션 길이
  static const int pressMs = 60;
}

/// 테두리 두께 — 듀오링고는 얇은 선을 쓰지 않는다.
abstract final class UnwindStroke {
  static const double hair = 1;
  static const double base = 2;
  static const double thick = 2.5;
}
