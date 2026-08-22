import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueNotifier;

/// 디자인 시스템 v2 팔레트 — "Midnight Amber" (개편 2026-08-12).
///
/// **PRD §8.1의 조도 램프(S0 정오~S5 밤)를 대체한다.** 근거는
/// `docs/prd-amendments.md` 2026-08-12 항목.
///
/// - 앱은 **항상 다크**다. 색은 더 이상 조도 t에서 파생되지 않는다.
/// - 조도 `t`는 색이 아니라 **빛의 양**만 몬다 — CornerGlow의 세기,
///   창문 셀의 밝기, 켜진 등의 발광. "남은 할 일 = 남은 빛" 은유는 그대로.
/// - 포인트 컬러는 둘뿐: [accent](앰버 = 빛/램프)와 [danger](코랄 = 삭제·경고).
///   그 외에는 전부 슬레이트-네이비 중립색이다. **새 색 추가 금지.**
///
/// 듀오링고 문법의 3D 버튼은 **blur 없는 solid offset shadow**([solid])라
/// §11 "블러 금지" 제약과 그대로 맞아떨어진다.
abstract final class UnwindColors {
  // ── 중립 (슬레이트-네이비) ────────────────────────────────
  /// 앱 배경 — 가장 어두운 바닥
  static const ink = Color(0xFF0D1520);

  /// 시트·모달 뒤에 까는 더 깊은 바닥
  static const inkDeep = Color(0xFF070D15);

  /// 카드·타일·시트 본체
  static const surface = Color(0xFF16212D);

  /// 입력 필드·칩처럼 한 단 올라온 면
  static const surfaceAlt = Color(0xFF1E2C3A);

  /// 선택·눌림 상태의 면
  static const surfaceHigh = Color(0xFF27394A);

  /// 기본 테두리 (2px)
  static const border = Color(0xFF2B3B4C);

  /// 강조 테두리 — 인터랙티브 요소의 윤곽
  static const borderStrong = Color(0xFF3E5468);

  /// 3D 압출면 — **blur 0**의 오프셋 그림자 전용 (§11)
  static const solid = Color(0xFF060B12);

  /// 작은 중립 알약의 압출면 — [solid]는 [ink]와 명도 차가 거의 없어
  /// 그림자가 보이지 않는다. 알약 채움(surfaceHigh)보다 확실히 어둡다.
  static const pillDeep = Color(0xFF101B26);

  /// 모달 배리어
  static const scrim = Color(0x8C000000);

  // ── 텍스트 ────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF2F7FB);
  static const textSecondary = Color(0xFF9BB0C2);

  /// surfaceAlt(입력 필드 힌트) 위에서도 4.5:1을 넘도록 잡은 값 (§12).
  static const textMuted = Color(0xFF8098AD);
  static const textDisabled = Color(0xFF4E6376);

  // ── 포인트 1: 조명 색 = 빛 (선택형 2026-08-22, 기본 앰버) ──
  static UnwindLightColor _light = UnwindLightColor.amber;

  /// 지금 방을 밝히는 조명 색
  static UnwindLightColor get lightColor => _light;

  /// 팔레트 세대 — 조명 색이 바뀔 때 +1. [UnwindScreen]이 듣고 화면을
  /// 통째로 다시 인플레이트한다: 색이 정적 게터라 자동 전파가 없고,
  /// const 서브트리는 rebuild를 잘라먹으므로 키 교체가 유일하게 확실한
  /// 전면 갱신이다.
  static final paletteEpoch = ValueNotifier<int>(0);

  /// 조명 색 적용 — 같은 값이면 no-op (빌드 중 불러도 안전한 멱등 호출).
  static void setLightColor(UnwindLightColor c) {
    if (_light == c) return;
    _light = c;
    paletteEpoch.value++;
  }

  /// 켜진 등, CTA, 선택 상태. 이 앱의 유일한 주 강조색 — 조명 색을 따른다.
  static Color get accent => _light.seed;

  /// 조명 색의 압출면 — 3D 버튼 바닥 / 눌린 상태
  static Color get accentDeep => _light.deep;

  /// 조명 색 채움 (선택된 칩·스위치 트랙 등)
  static Color get accentSoft => _light.seed.withValues(alpha: 0x24 / 255);

  /// 조명 색 윤곽 (켜진 타일 테두리)
  static Color get accentEdge => _light.seed.withValues(alpha: 0x8C / 255);

  /// 조명 색 위에 얹는 글자·아이콘
  static Color get onAccent => _light.ink;

  // ── 코너 글로우의 4겹 (corner_glow.dart) — seed에서 파생 ──
  // 앰버의 파생 결과가 기존 손튜닝 값(#D89A2A/#FFB224/#FFD07A/#FFF0CC)과
  // 거의 일치하도록 계수를 잡았다.
  static Color get glowWash =>
      Color.lerp(_light.seed, const Color(0xFF000000), 0.15)!;
  static Color get glowMid => _light.seed;
  static Color get glowCore =>
      Color.lerp(_light.seed, const Color(0xFFFFFFFF), 0.40)!;
  static Color get glowHot =>
      Color.lerp(_light.seed, const Color(0xFFFFFFFF), 0.78)!;

  // ── 포인트 2: 코랄 = 파괴적 액션·경고 ─────────────────────
  static const danger = Color(0xFFFF6B5A);
  static const dangerDeep = Color(0xFFC0402F);
  static const onDanger = Color(0xFF2A0B06);

  // ── 조도에서 파생되는 "빛" (색이 아니라 양) ───────────────
  /// 주간 스트립의 창문 색. [light] 1.0 = 대낮처럼 밝은 창, 0.0 = 소등.
  static Color window(double light) =>
      lerpOklab(darkWindow, accent, light.clamp(0.0, 1.0));

  /// 소등된 창 (빛이 하나도 남지 않은 방)
  static const darkWindow = Color(0xFF111A24);
}

/// 방 조명의 색 (발주자 지시 2026-08-22) — 설정에서 고른다.
///
/// seed(조명 본색)·deep(압출면)·ink(조명 위 글자)는 색마다 손으로 잡고,
/// 채움·윤곽·글로우·창문 램프는 seed에서 파생한다. 전부 다크 잉크 위에서
/// "방을 밝히는 빛"으로 읽히는 밝은 톤이고, danger 코랄과 겹치지 않는다.
/// 대비(§12)는 test/core/palette_test.dart가 전 색상을 자동 검증한다.
enum UnwindLightColor {
  /// 백열등 — 기본. 기존 "Midnight Amber" 값 그대로.
  amber(Color(0xFFFFB224), Color(0xFFC57F12), Color(0xFF1A1206)),

  /// 노을 — 따뜻한 선셋 오렌지
  sunset(Color(0xFFFF9457), Color(0xFFD26428), Color(0xFF241106)),

  /// 로즈 — 핑크 네온
  rose(Color(0xFFFF8FB8), Color(0xFFD65E8E), Color(0xFF260C18)),

  /// 라벤더 — 보랏빛 무드등
  lavender(Color(0xFFB99CFF), Color(0xFF8B68E0), Color(0xFF170D2B)),

  /// 하늘 — 맑은 스카이 블루
  sky(Color(0xFF62C6FF), Color(0xFF2F97D6), Color(0xFF071A26)),

  /// 민트 — 초록빛 조명
  mint(Color(0xFF52D6A0), Color(0xFF2BA475), Color(0xFF072016)),

  /// 달빛 — 차가운 은백색
  moon(Color(0xFFBFD4E8), Color(0xFF8FA9C2), Color(0xFF0D141C));

  /// 조명 본색 (= accent)
  final Color seed;

  /// 3D 압출면 (= accentDeep)
  final Color deep;

  /// 조명 위에 얹는 글자·아이콘 (= onAccent)
  final Color ink;

  const UnwindLightColor(this.seed, this.deep, this.ink);

  /// 설정 문자열 → 색. 모르는 값(다운그레이드 등)은 기본 앰버.
  static UnwindLightColor fromName(String? name) =>
      values.asNameMap()[name] ?? amber;
}

/// 두 색을 OKLab 공간에서 섞는다. RGB 직선 보간은 중간이 회색 진흙이 된다.
/// (부록 A — 램프는 폐기됐지만 이 유틸은 빛 표현에 계속 쓴다.)
Color lerpOklab(Color x, Color y, double u) {
  final la = _toOklab(x);
  final lb = _toOklab(y);
  final l = la[0] + (lb[0] - la[0]) * u;
  final aa = la[1] + (lb[1] - la[1]) * u;
  final bb = la[2] + (lb[2] - la[2]) * u;
  final alpha = x.a + (y.a - x.a) * u;
  return _fromOklab(l, aa, bb, alpha);
}

// ---------------------------------------------------------------------------
// OKLab 변환 (https://bottosson.github.io/posts/oklab/)
// ---------------------------------------------------------------------------

double _srgbToLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _linearToSrgb(double c) => c <= 0.0031308
    ? c * 12.92
    : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

List<double> _toOklab(Color c) {
  final r = _srgbToLinear(c.r);
  final g = _srgbToLinear(c.g);
  final b = _srgbToLinear(c.b);

  final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
  final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
  final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

  final l3 = _cbrt(l), m3 = _cbrt(m), s3 = _cbrt(s);

  return [
    0.2104542553 * l3 + 0.7936177850 * m3 - 0.0040720468 * s3,
    1.9779984951 * l3 - 2.4285922050 * m3 + 0.4505937099 * s3,
    0.0259040371 * l3 + 0.7827717662 * m3 - 0.8086757660 * s3,
  ];
}

Color _fromOklab(double l, double a, double b, double alpha) {
  final l3 = l + 0.3963377774 * a + 0.2158037573 * b;
  final m3 = l - 0.1055613458 * a - 0.0638541728 * b;
  final s3 = l - 0.0894841775 * a - 1.2914855480 * b;

  final ll = l3 * l3 * l3, mm = m3 * m3 * m3, ss = s3 * s3 * s3;

  final r = 4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss;
  final g = -1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss;
  final bl = -0.0041960863 * ll - 0.7034186147 * mm + 1.7076147010 * ss;

  return Color.from(
    alpha: alpha.clamp(0.0, 1.0),
    red: _linearToSrgb(r).clamp(0.0, 1.0),
    green: _linearToSrgb(g).clamp(0.0, 1.0),
    blue: _linearToSrgb(bl).clamp(0.0, 1.0),
  );
}

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
