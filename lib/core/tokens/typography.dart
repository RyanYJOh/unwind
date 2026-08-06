import 'package:flutter/widgets.dart';

/// §8.2 타이포그래피 — Pretendard Variable(본문) + JetBrains Mono(청구서 숫자).
/// 값 임의 변경 금지.
abstract final class UnwindType {
  static const fontFamily = 'Pretendard';
  static const monoFamily = 'JetBrainsMono';
  static const monoFallback = <String>[fontFamily]; // 한글은 Pretendard 폴백

  /// Dynamic Type 스케일 상한 (§8.2 — 그 이상은 클램프)
  static const maxTextScale = 1.3;

  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.5,
  );

  static const bodyStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    height: 1.5,
  );

  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );

  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const mono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );
}
