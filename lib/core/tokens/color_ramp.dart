import 'dart:math' as math;
import 'dart:ui';

/// §8.1 조도 램프 — 앱의 모든 색은 t 하나에서 파생된다.
/// 정거장(S0~S5) 값은 PRD 표를 그대로 옮긴 것. 임의 변경 금지.
class RampStop {
  final double t;
  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color lamp;
  final Color shadow;

  const RampStop({
    required this.t,
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.lamp,
    required this.shadow,
  });
}

/// S0 정오 ~ S5 밤 (§8.1)
const kRamp = <RampStop>[
  RampStop(
    t: 0.00, // S0 정오
    bg: Color(0xFFF7F4EE),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF2B2724),
    textSecondary: Color(0xFF6B635A),
    textMuted: Color(0xFFA69C90),
    border: Color(0xFFE6DFD4),
    lamp: Color(0xFFD98A32),
    shadow: Color(0x1A5A422C), // rgba(90,66,44,.10)
  ),
  RampStop(
    t: 0.30, // S1 오후
    bg: Color(0xFFF2E7D6),
    surface: Color(0xFFFBF4E9),
    surfaceRaised: Color(0xFFFFFAF2),
    textPrimary: Color(0xFF3A3128),
    textSecondary: Color(0xFF776A58),
    textMuted: Color(0xFFAA9C86),
    border: Color(0xFFE2D4BE),
    lamp: Color(0xFFCE7C2A),
    shadow: Color(0x1F5A3C1E), // rgba(90,60,30,.12)
  ),
  RampStop(
    t: 0.55, // S2 노을
    bg: Color(0xFFE5B98F),
    surface: Color(0xFFEFCCA8),
    surfaceRaised: Color(0xFFF4D8B9),
    textPrimary: Color(0xFF4A3020),
    textSecondary: Color(0xFF7A543A),
    textMuted: Color(0xFFA5805F),
    border: Color(0xFFD3A97F),
    lamp: Color(0xFFC06B28),
    shadow: Color(0x29502C14), // rgba(80,44,20,.16)
  ),
  // S3 조정됨(사용자 승인 2026-08-06): 원래 bg #A8735A / surface #B58269 /
  // surfaceRaised #BE8D74 / border #8E5C46는 §12 대비 4.5:1을 어떤 텍스트
  // 색으로도 만족할 수 없어(중간 명도) 배경 계열을 어둡게 내림.
  RampStop(
    t: 0.70, // S3 땅거미
    bg: Color(0xFF8D5C44),
    surface: Color(0xFF97664D),
    surfaceRaised: Color(0xFFA06F56),
    textPrimary: Color(0xFFFBF1E8),
    textSecondary: Color(0xFFE7CDBB),
    textMuted: Color(0xFFC6A28C),
    border: Color(0xFF714733),
    lamp: Color(0xFFE3A165),
    shadow: Color(0x38321A0E), // rgba(50,26,14,.22)
  ),
  RampStop(
    t: 0.85, // S4 황혼
    bg: Color(0xFF6E5B7E),
    surface: Color(0xFF7B688B),
    surfaceRaised: Color(0xFF857295),
    textPrimary: Color(0xFFEFE6F2),
    textSecondary: Color(0xFFCDBFD6),
    textMuted: Color(0xFFA08FAC),
    border: Color(0xFF59476A),
    lamp: Color(0xFFEDAE68),
    shadow: Color(0x4D1C1028), // rgba(28,16,40,.30)
  ),
  RampStop(
    t: 1.00, // S5 밤
    bg: Color(0xFF16131F),
    surface: Color(0xFF201C2B),
    surfaceRaised: Color(0xFF2A2537),
    textPrimary: Color(0xFFE6E2F0),
    textSecondary: Color(0xFFA79EBE),
    textMuted: Color(0xFF6E6685),
    border: Color(0xFF322C45),
    lamp: Color(0xFFF5C87E),
    shadow: Color(0x73000000), // rgba(0,0,0,.45)
  ),
];

/// textPrimary 크로스페이드 기준점 (§8.1 — 어두운↔밝은 쪽을 가로질러 보간 금지,
/// 180ms 크로스페이드로 전환)
/// 조정됨(사용자 승인 2026-08-06): 0.62 → 0.67. §12 대비 4.5:1을 전 구간에서
/// 만족시키기 위해 배경이 충분히 어두워진 뒤 밝은 글자로 전환한다.
const kTextFlipT = 0.67;
const kTextCrossfadeMs = 180;

/// textPrimary 어두운 쪽 곡선 — 같은 밝기 측 내부이므로 보간해도 안전하다.
/// 마지막 정거장(0.65, 깊은 갈색)은 조정됨: 전환 직전 어두워진 배경 위에서
/// 4.5:1을 유지하기 위해 S2 값보다 깊게 내려간다.
const kTextDarkCurve = <(double, Color)>[
  (0.00, Color(0xFF2B2724)), // S0 textPrimary
  (0.30, Color(0xFF3A3128)), // S1 textPrimary
  (0.55, Color(0xFF4A3020)), // S2 textPrimary
  (0.65, Color(0xFF241610)), // 조정됨 — 전환 직전 심화
];

/// textPrimary 밝은 쪽 곡선.
const kTextLightCurve = <(double, Color)>[
  (0.70, Color(0xFFFBF1E8)), // S3 textPrimary
  (0.85, Color(0xFFEFE6F2)), // S4 textPrimary
  (1.00, Color(0xFFE6E2F0)), // S5 textPrimary
];

/// t 시점의 파생 색 묶음.
/// textPrimary는 보간하지 않는다 — [textPrimaryDark]/[textPrimaryLight]와
/// [textFlipProgress]를 노출하고, 위젯 레벨에서 두 색을 겹쳐 크로스페이드한다.
class UnwindColors {
  final double t;
  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color lamp;
  final Color shadow;

  /// 어두운 글자(정오측, S2 이하) / 밝은 글자(밤측, S3 이상)
  final Color textPrimaryDark;
  final Color textPrimaryLight;

  /// 0.0 = 어두운 글자만, 1.0 = 밝은 글자만 (t == kTextFlipT 에서 뒤집힘)
  final double textFlipProgress;

  const UnwindColors({
    required this.t,
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.lamp,
    required this.shadow,
    required this.textPrimaryDark,
    required this.textPrimaryLight,
    required this.textFlipProgress,
  });

  /// 크로스페이드를 쓸 수 없는 자리(예: 시스템 UI)용 스냅 값.
  Color get textPrimarySnap =>
      textFlipProgress < 0.5 ? textPrimaryDark : textPrimaryLight;
}

/// §8.1 / 부록 A — OKLab 공간 보간.
/// RGB 직선 보간은 중간이 회색 진흙이 된다. textPrimary는 보간하지 않는다.
UnwindColors lerpRamp(double t) {
  final tc = t.clamp(0.0, 1.0);

  // 1. t를 감싸는 두 정거장을 찾는다
  var a = kRamp.first;
  var b = kRamp.last;
  for (var i = 0; i < kRamp.length - 1; i++) {
    if (tc >= kRamp[i].t && tc <= kRamp[i + 1].t) {
      a = kRamp[i];
      b = kRamp[i + 1];
      break;
    }
  }

  // 2. 지역 비율
  final u = (b.t - a.t) == 0 ? 0.0 : (tc - a.t) / (b.t - a.t);

  // 3. textPrimary 제외 전부 OKLab 보간
  Color lerp(Color Function(RampStop) pick) =>
      _lerpOklab(pick(a), pick(b), u);

  return UnwindColors(
    t: tc,
    bg: lerp((s) => s.bg),
    surface: lerp((s) => s.surface),
    surfaceRaised: lerp((s) => s.surfaceRaised),
    textSecondary: lerp((s) => s.textSecondary),
    textMuted: lerp((s) => s.textMuted),
    border: lerp((s) => s.border),
    lamp: lerp((s) => s.lamp),
    shadow: lerp((s) => s.shadow),
    // 4. textPrimary: 어두운↔밝은 쪽을 가로질러 보간하지 않는다.
    //    각 쪽 곡선 내부에서만 보간하고, kTextFlipT에서 크로스페이드.
    textPrimaryDark: _sampleCurve(kTextDarkCurve, tc),
    textPrimaryLight: _sampleCurve(kTextLightCurve, tc),
    textFlipProgress: tc < kTextFlipT ? 0.0 : 1.0,
  );
}

/// 같은 밝기 측 곡선 안에서 OKLab 보간. 범위 밖은 끝값으로 클램프.
Color _sampleCurve(List<(double, Color)> curve, double t) {
  if (t <= curve.first.$1) return curve.first.$2;
  if (t >= curve.last.$1) return curve.last.$2;
  for (var i = 0; i < curve.length - 1; i++) {
    final (ta, ca) = curve[i];
    final (tb, cb) = curve[i + 1];
    if (t >= ta && t <= tb) {
      final u = (tb - ta) == 0 ? 0.0 : (t - ta) / (tb - ta);
      return _lerpOklab(ca, cb, u);
    }
  }
  return curve.last.$2;
}

// ---------------------------------------------------------------------------
// OKLab 변환 (https://bottosson.github.io/posts/oklab/)
// ---------------------------------------------------------------------------

Color _lerpOklab(Color x, Color y, double u) {
  final la = _toOklab(x);
  final lb = _toOklab(y);
  final l = la[0] + (lb[0] - la[0]) * u;
  final aa = la[1] + (lb[1] - la[1]) * u;
  final bb = la[2] + (lb[2] - la[2]) * u;
  final alpha = x.a + (y.a - x.a) * u;
  return _fromOklab(l, aa, bb, alpha);
}

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
