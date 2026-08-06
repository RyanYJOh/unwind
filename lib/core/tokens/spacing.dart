/// §8.3 간격 · 반경 · 터치 타깃. 값 임의 변경 금지.
abstract final class UnwindSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
}

abstract final class UnwindRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double pill = 999;
}

abstract final class UnwindTouch {
  /// 최소 터치 타깃 (§8.3, §12)
  static const double minTarget = 44;
}
