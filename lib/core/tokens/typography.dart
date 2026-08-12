import 'package:flutter/widgets.dart';

/// §8.2 타이포그래피 — Pretendard Variable(본문) + JetBrains Mono(청구서 숫자).
///
/// 개편 2026-08-12 (디자인 시스템 v2): 듀오링고 문법에 맞춰 **전반적으로
/// 무겁게**. 제목은 w800, 라벨·버튼은 w700~w800. 가변 폰트가 확실히 굵은
/// 인스턴스를 쓰도록 [FontVariation]으로 wght 축을 직접 지정한다
/// (fontWeight만 주면 플랫폼에 따라 가짜 볼드가 나올 수 있다).
abstract final class UnwindType {
  static const fontFamily = 'Pretendard';
  static const monoFamily = 'JetBrainsMono';
  static const monoFallback = <String>[fontFamily]; // 한글은 Pretendard 폴백

  /// Dynamic Type 스케일 상한 (§8.2 — 그 이상은 클램프)
  static const maxTextScale = 1.3;

  static List<FontVariation> _wght(double w) => [FontVariation('wght', w)];

  static TextStyle _t({
    required double size,
    required double weight,
    double letterSpacing = 0,
    double height = 1.4,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: _wght(weight),
    letterSpacing: letterSpacing,
    height: height,
    decoration: TextDecoration.none,
  );

  /// 온보딩·청구서의 큰 제목
  static final display = _t(
    size: 32,
    weight: 800,
    letterSpacing: -0.6,
    height: 1.15,
  );

  /// 화면 제목 ("Today", "설정")
  static final title = _t(
    size: 24,
    weight: 800,
    letterSpacing: -0.4,
    height: 1.25,
  );

  /// 섹션 제목·시트 헤더
  static final headline = _t(
    size: 20,
    weight: 700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// 본문 — 할 일 제목, 설정 항목
  static final body = _t(
    size: 16,
    weight: 500,
    letterSpacing: -0.1,
    height: 1.45,
  );

  /// 강조 본문
  static final bodyStrong = _t(
    size: 16,
    weight: 700,
    letterSpacing: -0.1,
    height: 1.45,
  );

  /// 보조 라벨 — 값 표시, 칩
  static final label = _t(size: 14, weight: 700, height: 1.35);

  /// 캡션 — 설명 문구
  static final caption = _t(size: 12, weight: 600, letterSpacing: 0.1);

  /// 섹션 구분 라벨 (대문자 트래킹)
  static final overline = _t(size: 11, weight: 800, letterSpacing: 1.4);

  /// 버튼 라벨 — 듀오링고식으로 굵고 살짝 벌어진다
  static final button = _t(size: 16, weight: 800, letterSpacing: 0.4);

  /// 작은 버튼 라벨
  static final buttonSmall = _t(size: 14, weight: 800, letterSpacing: 0.3);

  /// 청구서 숫자
  static final mono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: monoFallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    decoration: TextDecoration.none,
  );
}
