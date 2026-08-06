import 'package:flutter/animation.dart';

/// §9 모션 · 감각 명세 — 이 숫자를 임의로 바꾸지 마라.
abstract final class UnwindMotion {
  // §9.1 이징
  static const switchOff = Curves.easeOutQuint;
  static const theme = Curves.easeInOutCubic;
  static const settle = Curves.easeOutQuint;
  static const spring = SpringDescription(mass: 1, stiffness: 380, damping: 22);

  // §9.2 개별 체크
  static const checkHapticDelayMs = 0;
  static const iconPressMs = 140; // scale 1.0 → 0.94 → 1.0
  static const iconPressScale = 0.94;
  static const lampOffMs = 220; // 필라멘트 식듯이, switchOff
  static const afterglowDelayMs = 60; // 잔광 시작
  static const afterglowMs = 200; // 잔광 지속 — 생략 불가
  static const textFadeMs = 180; // opacity 1.0 → 0.4
  static const textFadedOpacity = 0.4;
  static const themeMoveMs = 520; // 전역 테마 이동 + 체크 펄스

  // §5.4 체크 펄스
  static const pulseAmount = 0.035;
  static const pulseRiseMs = 120; // easeOutQuad
  static const pulseRise = Curves.easeOutQuad;
  static const pulseFallMs = 280; // easeInOutCubic
  static const pulseFall = Curves.easeInOutCubic;

  // §5.5 호흡
  static const breathPeriodMs = 4000;
  static const breathAmplitude = 0.012; // × (1 - t)

  // §9.3 소등 시퀀스 — 전등 줄
  static const cordZoomOutMs = 900; // 1.02 → 1.00, settle
  static const cordZoomScale = 1.02;
  static const dominoIntervalMs = 70; // 등 간격 고정 — "타라라락"
  static const silenceAfterLastMs = 500; // 정적. 아무 일도 일어나지 않는다.
  static const lumiFallAsleepMs = 1400;
  static const starsFadeInMs = 2000;

  // §6.4 전등 줄 제스처
  static const cordMaxDragPx = 72.0;
  static const cordThresholdPx = 56.0;

  // §9.4 기타
  static const sheetMs = 320; // theme
  static const weekExpandMs = 380; // settle
  static const billEnterMs = 600; // settle
  static const pageMs = 280;

  // §9.5 Reduce Motion — 도미노 대신 전체 페이드
  static const reducedFadeMs = 400;

  // §7.3 Lumi
  static const lumiReactScale = 0.03; // 몸이 0.03 커졌다 돌아옴
  static const lumiReactMs = 150;
  static const lumiBlinkMinS = 4, lumiBlinkMaxS = 8; // t 0.0–0.3
  static const lumiYawnMinS = 12, lumiYawnMaxS = 20; // t 0.3–0.6
}
