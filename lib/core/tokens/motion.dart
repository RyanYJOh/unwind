import 'package:flutter/animation.dart';

/// §9 모션 · 감각 명세 — 이 숫자를 임의로 바꾸지 마라.
abstract final class UnwindMotion {
  // §9.1 이징
  static const switchOff = Curves.easeOutQuint;
  static const theme = Curves.easeInOutCubic;
  static const settle = Curves.easeOutQuint;
  static const spring = SpringDescription(mass: 1, stiffness: 380, damping: 22);

  // §6.4 전등 줄 물리 (개편 2026-08-12) — 놓으면 진짜 줄처럼 논다.
  // 두 축을 각각 damped spring으로 적분한다 (flutter/physics).
  /// 세로 되튐. ζ≈0.34 — 원위치를 지나쳐 두어 번 통통 튄다.
  /// (이전 spring은 ζ≈0.56에 오버슈트를 잘라내 튕김이 보이지 않았다)
  static const cordRecoil = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 12,
  );

  /// 가로 흔들림 — 느리고 길게 남는 진자 (주기 ≈ 0.97s, ζ≈0.25).
  static const cordSway = SpringDescription(
    mass: 1,
    stiffness: 42,
    damping: 3.2,
  );

  /// 줄이 원위치 위로 되튈 수 있는 한계 (px) — 헤더를 침범하지 않게
  static const cordRecoilLimitPx = 20.0;

  /// 놓는 순간 옆으로 실리는 힘 (당긴 정도에 비례)
  static const cordSwayKick = 260.0;

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
  static const toddFallAsleepMs = 1400;
  static const starsFadeInMs = 2000;

  // §6.4 전등 줄 제스처
  static const cordMaxDragPx = 72.0;
  static const cordThresholdPx = 56.0;

  // §9.4 기타
  static const sheetMs = 320; // theme
  static const weekExpandMs = 380; // settle
  static const billEnterMs = 600; // settle
  static const pageMs = 280;

  /// 바텀시트 드래그 닫기 — 높이의 이 비율 이상 내리면 닫힌다
  static const sheetDismissFraction = 0.35;

  /// 아래로 이 속도(px/s) 이상이면 비율과 무관하게 닫힌다
  static const sheetDismissVelocity = 800.0;

  /// 전등 줄 코치마크 구멍 링이 숨 쉬는 주기
  static const coachPulseMs = 1400;

  /// 온보딩 청구서 아이콘 — 눌러 보라고 주기적으로 살짝 흔든다.
  static const billWigglePeriodMs = 1500;

  /// 최대 기울기 (rad, ≈8°)
  static const billWiggleAmp = 0.14;

  // §9.5 Reduce Motion — 도미노 대신 전체 페이드
  static const reducedFadeMs = 400;

  // §7.3 Todd
  static const toddReactScale = 0.03; // 몸이 0.03 커졌다 돌아옴
  static const toddReactMs = 150;
  static const toddBlinkMinS = 4, toddBlinkMaxS = 8; // t 0.0–0.3
  static const toddYawnMinS = 12, toddYawnMaxS = 20; // t 0.3–0.6
}
