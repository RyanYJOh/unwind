import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/tokens/palette.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/domain/models/todd_state.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/main.dart';
import 'package:unwind/widgets/night_sky.dart';
import 'package:unwind/widgets/todd/ghost_contract.dart';
import 'package:unwind/widgets/todd/ghost_painter_view.dart';

/// 앱스토어 스크린샷 추출기 (2026-08-27, 발주자 컨펌).
///
///   SHOT_EXPORT=1 flutter test test/tools/appstore_shot_export_test.dart
///
/// 출력: build/appstore/{en,ko}/0N_*.png — 정확히 1320×2868 (6.9").
/// 4프레임 × 2개 언어. 조도 스토리 아크: 1(낮) → 4(밤)으로 점점 어두워진다.
/// 2·3번의 폰 목업 내부는 **실제 앱 위젯**(UnwindApp)을 스테이징해 캡처한다.
/// 평소 flutter test에서는 skip.

// ── 캔버스 ──────────────────────────────────────────────────
const _canvasW = 440.0; // ×3 = 1320
const _canvasH = 956.0; // ×3 = 2868
const _screenW = 402.0; // 폰 목업 내부 논리 크기 (iPhone 17)
const _screenH = 874.0;
const _keyboardH = 244.0; // F3 가짜 키보드 영역 (viewInsets와 일치)

// ── 카피 ────────────────────────────────────────────────────
class _Copy {
  final String title;
  final String sub;
  const _Copy(this.title, this.sub);
}

const _copies = <String, List<_Copy>>{
  'en': [
    _Copy('Meet Todd', 'The cutest, coziest to-do app'),
    _Copy('Check it off,\nlights out', 'Every to-do is a light in Todd’s room'),
    _Copy('Add in a snap', 'Title, time, done — in seconds'),
    _Copy('Tuck Todd in\ntonight', 'End your day, and he sleeps tight'),
  ],
  'ko': [
    _Copy('안녕, 나는 토드야', '가장 귀엽고, 가장 편한 투두 앱'),
    _Copy('할 일을 끝내면,\n불도 꺼져', '할 일이 불을 끄는 스위치야'),
    _Copy('적고, 저장, 끝', '3초면 충분한 할 일 추가'),
    _Copy('토드가 편하게\n잘 수 있도록 도와줘', '할 일을 모두 끝내면 토드가 편히 잠들어'),
  ],
};

const _todoTitles = <String, List<String>>{
  'en': ['Drink 2L of water', 'Morning stretch', 'Read 30 minutes', 'Tidy up my room'],
  'ko': ['물 2L 마시기', '아침 스트레칭', '책 30분 읽기', '방 정리하기'],
};

const _composeTitle = <String, String>{
  'en': 'Water the plants',
  'ko': '화분에 물 주기',
};

// ── 폰트 ────────────────────────────────────────────────────
Future<void> _loadFonts() async {
  Future<void> load(String family, File file) async {
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  await load('Pretendard', File('assets/fonts/PretendardVariable.ttf'));
  await load('JetBrainsMono', File('assets/fonts/JetBrainsMono-Variable.ttf'));
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons =
        File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await load('MaterialIcons', icons);
  }
}

TextStyle _title() => const TextStyle(
  fontFamily: 'Pretendard',
  fontVariations: [FontVariation('wght', 800)],
  fontSize: 44,
  height: 1.14,
  letterSpacing: -0.6,
  color: UnwindColors.textPrimary,
  decoration: TextDecoration.none,
);

TextStyle _sub() => const TextStyle(
  fontFamily: 'Pretendard',
  fontVariations: [FontVariation('wght', 600)],
  fontSize: 20.5,
  height: 1.35,
  letterSpacing: -0.2,
  color: UnwindColors.textSecondary,
  decoration: TextDecoration.none,
);

// ── 앱 화면 캡처 (실제 위젯) ────────────────────────────────
Future<ui.Image> _captureApp(
  WidgetTester tester, {
  required String lang,
  required Map<String, String> settings,
  double viewInsetsBottom = 0,
  required Future<void> Function(WidgetTester tester, ProviderContainer c) stage,
  Duration settle = const Duration(milliseconds: 1200),
}) async {
  final db = UnwindDatabase.withExecutor(NativeDatabase.memory());
  await db.settingsDao.setValue('onboardingCompleted', 'true');
  await db.settingsDao.setValue('languageCode', lang);
  for (final e in settings.entries) {
    await db.settingsDao.setValue(e.key, e.value);
  }

  tester.view.physicalSize = const Size(_screenW * 3, _screenH * 3);
  tester.view.devicePixelRatio = 3;
  // 상태바·홈 인디케이터 영역 — 목업에서 상태바를 직접 그린다
  tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
  tester.view.viewInsets = viewInsetsBottom > 0
      ? FakeViewPadding(bottom: viewInsetsBottom * 3)
      : FakeViewPadding.zero;

  final key = GlobalKey();
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: Consumer(
        builder: (context, ref, child) {
          container = ProviderScope.containerOf(context);
          return child!;
        },
        child: RepaintBoundary(key: key, child: const UnwindApp()),
      ),
    ),
  );

  // 에셋(몸통 PNG·청구서 아이콘) 비동기 로드 대기 — 실 IO라 runAsync 필요
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }

  await stage(tester, container);

  // 조도 애니메이션·Todd 포즈가 자리 잡을 시간
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(settle);

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 3.0));

  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 80));
  await db.close();
  tester.view.viewInsets = FakeViewPadding.zero;
  return image!;
}

// ── 최종 프레임 렌더 → PNG ──────────────────────────────────
Future<void> _renderPng(
  WidgetTester tester,
  Widget frame,
  String outPath, {
  Duration settle = const Duration(milliseconds: 900),
  // 이벤트 포즈용 2차 pump — settle 중에 발화한 이벤트(간지럼 등)의
  // 애니메이션을 원하는 지점까지 진행시킨다 (발화 프레임에 캡처하면 t=0)
  Duration pose = Duration.zero,
}) async {
  tester.view.physicalSize = const Size(_canvasW * 3, _canvasH * 3);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewInsets = FakeViewPadding.zero;

  final key = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(_canvasW, _canvasH)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(key: key, child: frame),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }
  await tester.pump(settle);
  if (pose > Duration.zero) await tester.pump(pose);

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  File(outPath)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

// ── 프레임 뼈대 ─────────────────────────────────────────────
class _Frame extends StatelessWidget {
  final _Copy copy;
  final double glow; // 코너 글로우 세기 (0~1) — 낮→밤 아크
  final Widget child;
  final Widget? background;

  const _Frame({
    required this.copy,
    required this.glow,
    required this.child,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _canvasW,
      height: _canvasH,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          const ColoredBox(color: UnwindColors.ink),
          ?background,
          // 우상단 앰버 글로우 — 앱과 같은 문법 (§11 블러 금지: gradient)
          if (glow > 0)
            IgnorePointer(
              child: CustomPaint(painter: _GlowPainter(light: glow)),
            ),
          Column(
            children: [
              const SizedBox(height: 74),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  copy.title,
                  textAlign: TextAlign.center,
                  style: _title(),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  copy.sub,
                  textAlign: TextAlign.center,
                  style: _sub(),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ],
      ),
    );
  }
}

/// 마케팅 캔버스용 코너 글로우 — 앱 CornerGlow와 같은 4겹 radial 문법을
/// 캔버스 비율에 맞게 다시 그린다 (위젯 재사용 시 화면 크기 가정이 달라짐).
class _GlowPainter extends CustomPainter {
  final double light;
  const _GlowPainter({required this.light});

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 1.02, -size.height * 0.02);
    void layer(double radius, Color color) {
      final paint = Paint()
        ..shader = ui.Gradient.radial(origin, radius, [
          color,
          color.withValues(alpha: 0),
        ]);
      canvas.drawCircle(origin, radius, paint);
    }

    // 내비(ink) 베이스가 살아 있어야 한다 — 글로우가 캔버스 전체를 덮으면
    // 탁한 카키색이 된다 (1차 시안에서 확인). 코너에 타이트하게.
    final l = light.clamp(0.0, 1.0);
    layer(size.height * 0.95 * l, UnwindColors.glowWash.withValues(alpha: 0.16 * l));
    layer(size.height * 0.6 * l, UnwindColors.glowMid.withValues(alpha: 0.2 * l));
    layer(size.height * 0.36 * l, UnwindColors.glowCore.withValues(alpha: 0.34 * l));
    layer(size.height * 0.17 * l, UnwindColors.glowHot.withValues(alpha: 0.46 * l));
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => old.light != light;
}

/// 중앙 후광 — 캐릭터 히어로(F1) 뒤의 따뜻한 빛
class _HaloPainter extends CustomPainter {
  final Offset center; // 0~1 비율
  final double radius; // height 비율
  final Color color;
  final double alpha;
  const _HaloPainter({
    required this.center,
    required this.radius,
    required this.color,
    required this.alpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * center.dx, size.height * center.dy);
    final r = size.height * radius;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(c, r, [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) => false;
}

/// 다이아몬드 스파클 장식 (앱 checkOff 별과 같은 모양 문법)
class _SparklePainter extends CustomPainter {
  final List<(double, double, double, double)> sparks; // x비율, y비율, 크기, 알파
  const _SparklePainter(this.sparks);

  @override
  void paint(Canvas canvas, Size size) {
    for (final (fx, fy, s, a) in sparks) {
      final c = Offset(size.width * fx, size.height * fy);
      final path = Path()
        ..moveTo(c.dx, c.dy - s)
        ..quadraticBezierTo(c.dx + s * 0.18, c.dy - s * 0.18, c.dx + s, c.dy)
        ..quadraticBezierTo(c.dx + s * 0.18, c.dy + s * 0.18, c.dx, c.dy + s)
        ..quadraticBezierTo(c.dx - s * 0.18, c.dy + s * 0.18, c.dx - s, c.dy)
        ..quadraticBezierTo(c.dx - s * 0.18, c.dy - s * 0.18, c.dx, c.dy - s)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = UnwindColors.accent.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => false;
}

// ── 폰 목업 ─────────────────────────────────────────────────
class _Device extends StatelessWidget {
  final ui.Image screen;
  final double width;
  final String lang;
  final bool keyboard;

  const _Device({
    required this.screen,
    required this.width,
    required this.lang,
    this.keyboard = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * (_screenH / _screenW);
    const bezel = 8.0;
    final screenRadius = BorderRadius.circular(55 * width / _screenW);
    final scale = width / _screenW;

    return Container(
      width: width + bezel * 2,
      height: height + bezel * 2,
      decoration: BoxDecoration(
        color: const Color(0xFF05080D),
        borderRadius: BorderRadius.circular(55 * scale + bezel),
        border: Border.all(color: const Color(0xFF3A4A5C), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF03060A),
            offset: Offset(0, 14),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(bezel),
      child: ClipRRect(
        borderRadius: screenRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RawImage(image: screen, fit: BoxFit.cover),
            // 상태바 (테스트 렌더에는 없는 영역 — 목업이 직접 그린다)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 62 * scale,
              child: _StatusBar(scale: scale),
            ),
            if (keyboard)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _keyboardH * scale,
                child: _FakeKeyboard(lang: lang, scale: scale),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final double scale;
  const _StatusBar({required this.scale});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dynamic Island
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: EdgeInsets.only(top: 12 * scale),
            width: 124 * scale,
            height: 36 * scale,
            decoration: BoxDecoration(
              color: const Color(0xFF000000),
              borderRadius: BorderRadius.circular(19 * scale),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 40 * scale,
            right: 30 * scale,
            top: 18 * scale,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '9:41',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontVariations: const [FontVariation('wght', 700)],
                  fontSize: 16.5 * scale,
                  color: UnwindColors.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              CustomPaint(
                size: Size(72 * scale, 13 * scale),
                painter: _StatusIconsPainter(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 셀룰러 바 · 와이파이 · 배터리 — 단순 도형으로
class _StatusIconsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = UnwindColors.textPrimary;
    final h = size.height;

    // 셀룰러 4바
    for (var i = 0; i < 4; i++) {
      final barH = h * (0.45 + i * 0.18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * h * 0.42, h - barH, h * 0.26, barH),
          Radius.circular(h * 0.1),
        ),
        ink,
      );
    }

    // 와이파이 3호
    final wifiC = Offset(size.width * 0.48, h * 0.98);
    for (var i = 0; i < 3; i++) {
      final r = h * (0.35 + i * 0.32);
      canvas.drawArc(
        Rect.fromCircle(center: wifiC, radius: r),
        -2.42,
        1.7,
        false,
        Paint()
          ..color = UnwindColors.textPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.16
          ..strokeCap = StrokeCap.round,
      );
    }

    // 배터리
    final bw = h * 1.85;
    final left = size.width - bw;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, h * 0.08, bw - h * 0.22, h * 0.86),
      Radius.circular(h * 0.26),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = UnwindColors.textPrimary.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + h * 0.14, h * 0.22, bw - h * 0.5, h * 0.58),
        Radius.circular(h * 0.14),
      ),
      ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - h * 0.14, h * 0.36, h * 0.12, h * 0.3),
        Radius.circular(h * 0.06),
      ),
      Paint()..color = UnwindColors.textPrimary.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── 가짜 iOS 키보드 (F3) ────────────────────────────────────
class _FakeKeyboard extends StatelessWidget {
  final String lang;
  final double scale;
  const _FakeKeyboard({required this.lang, required this.scale});

  static const _rowsEn = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
  static const _rowsKo = ['ㅂㅈㄷㄱㅅㅛㅕㅑㅐㅔ', 'ㅁㄴㅇㄹㅎㅗㅓㅏㅣ', 'ㅋㅌㅊㅍㅠㅜㅡ'];

  @override
  Widget build(BuildContext context) {
    final rows = lang == 'ko' ? _rowsKo : _rowsEn;
    final keyH = 43.0 * scale;
    final gap = 6.0 * scale;
    final side = 3.5 * scale;

    Widget key(String label, {double flex = 1, bool dark = false, bool accent = false}) {
      return Expanded(
        flex: (flex * 10).round(),
        child: Container(
          height: keyH,
          margin: EdgeInsets.symmetric(horizontal: side),
          decoration: BoxDecoration(
            color: accent
                ? UnwindColors.accent
                : dark
                ? const Color(0xFF4A4A4D)
                : const Color(0xFF6B6B6E),
            borderRadius: BorderRadius.circular(5.5 * scale),
            boxShadow: const [
              BoxShadow(color: Color(0xFF1C1C1E), offset: Offset(0, 1)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontVariations: const [FontVariation('wght', 500)],
              fontSize: (label.length > 1 ? 15 : 21) * scale,
              color: accent ? UnwindColors.onAccent : const Color(0xFFF5F5F7),
              decoration: TextDecoration.none,
            ),
          ),
        ),
      );
    }

    Widget row(List<Widget> keys) => Padding(
      padding: EdgeInsets.symmetric(horizontal: 3 * scale, vertical: gap / 2),
      child: Row(children: keys),
    );

    return Container(
      color: const Color(0xFF2B2B2D),
      padding: EdgeInsets.only(top: 8 * scale),
      child: Column(
        children: [
          row([for (final c in rows[0].split('')) key(c)]),
          row([
            SizedBox(width: 18 * scale),
            for (final c in rows[1].split('')) key(c),
            SizedBox(width: 18 * scale),
          ]),
          row([
            key('⇧', flex: 1.35, dark: true),
            for (final c in rows[2].split('')) key(c),
            key('⌫', flex: 1.35, dark: true),
          ]),
          row([
            key('123', flex: 1.3, dark: true),
            key(lang == 'ko' ? '스페이스' : 'space', flex: 4.6),
            key(lang == 'ko' ? '완료' : 'done', flex: 1.6, accent: true),
          ]),
          const Spacer(),
          Container(
            width: 140 * scale,
            height: 5 * scale,
            margin: EdgeInsets.only(bottom: 8 * scale),
            decoration: BoxDecoration(
              color: UnwindColors.textPrimary.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(3 * scale),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 프레임 1 · 4 콘텐츠 ─────────────────────────────────────
/// 이벤트(간지럼 등)는 didUpdateWidget에서만 발화하므로, 첫 프레임을 그린
/// 뒤 timer로 이벤트를 쏜다 — settle pump가 원하는 포즈 지점까지 진행시킨다.
class _HeroTodd extends StatefulWidget {
  final ToddMode mode;
  final GhostEvent? event;
  final double size;
  const _HeroTodd({required this.mode, this.event, required this.size});

  @override
  State<_HeroTodd> createState() => _HeroToddState();
}

class _HeroToddState extends State<_HeroTodd> {
  var _tick = 0;

  @override
  void initState() {
    super.initState();
    if (widget.event == null) return;
    // asleep(allDone)은 초기 빌드에서 소비돼야 완성 포즈가 나온다.
    // 표정 이벤트(간지럼)는 didUpdateWidget에서만 발화 — 지연 후 쏜다.
    if (widget.mode == ToddMode.asleep) {
      _tick = 1;
    } else {
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (mounted) setState(() => _tick = 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GhostPainterView(
        sleepiness: widget.mode == ToddMode.asleep ? 1.0 : 0.1,
        event: _tick == 0 ? null : widget.event,
        eventTick: _tick,
        size: widget.size,
        mode: widget.mode,
        dazzle: 0,
      ),
    );
  }
}

// ── 메인 ────────────────────────────────────────────────────
void main() {
  final export = Platform.environment['SHOT_EXPORT'] == '1';
  final only = Platform.environment['SHOT_ONLY']; // 예: "en2" — 반복 작업용

  testWidgets(
    'export App Store screenshots',
    (tester) async {
      await _loadFonts();

      for (final lang in ['en', 'ko']) {
        final copy = _copies[lang]!;
        final out = 'build/appstore/$lang';
        bool want(int n) => only == null || only == '$lang$n';

        // ── 1. 히어로 — 캐릭터 풀블리드 ─────────────────────
        if (want(1)) {
          await _renderPng(
            tester,
            _Frame(
              copy: copy[0],
              glow: 0.95,
              background: CustomPaint(
                painter: const _HaloPainter(
                  center: Offset(0.5, 0.56),
                  radius: 0.3,
                  color: Color(0xFFFFB558),
                  alpha: 0.34,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _SparklePainter([
                        (0.16, 0.22, 10.0, 0.9),
                        (0.84, 0.16, 7.0, 0.75),
                        (0.88, 0.5, 11.0, 0.9),
                        (0.12, 0.62, 6.5, 0.6),
                        (0.2, 0.86, 8.0, 0.75),
                        (0.8, 0.82, 6.0, 0.6),
                      ]),
                    ),
                  ),
                  const Align(
                    alignment: Alignment(0, -0.22),
                    child: _HeroTodd(
                      mode: ToddMode.day,
                      event: GhostEvent.poke,
                      size: 430,
                    ),
                  ),
                ],
              ),
            ),
            '$out/01_meet_todd.png',
            settle: const Duration(milliseconds: 200),
            pose: const Duration(milliseconds: 620),
          );
        }

        // ── 2. 체크 = 소등 (실제 홈 화면) ───────────────────
        if (want(2)) {
          final now = DateTime.now();
          final bedtime = now.hour <= 5 ? 22 : now.hour; // 지금이 밤이 되게
          final home = await _captureApp(
            tester,
            lang: lang,
            settings: {'bedtimeHour': '$bedtime'},
            stage: (tester, c) async {
              final repo = c.read(todoRepositoryProvider);
              final today = c.read(todayKeyProvider);
              final titles = _todoTitles[lang]!;
              for (var i = 0; i < titles.length; i++) {
                await repo.add(
                  title: titles[i],
                  date: today,
                  scheduledTimeMinutes: i == 3 ? 21 * 60 + 30 : null,
                );
              }
              await tester.pump(const Duration(milliseconds: 200));
              final db = c.read(databaseProvider);
              final todos = await db.select(db.todos).get();
              for (final t in todos.take(3)) {
                await repo.setDone(t, true);
                await tester.pump(const Duration(milliseconds: 150));
              }
            },
            settle: const Duration(milliseconds: 2600),
          );
          await _renderPng(
            tester,
            _Frame(
              copy: copy[1],
              glow: 0.4,
              child: Padding(
                padding: const EdgeInsets.only(top: 34),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: OverflowBox(
                    maxHeight: double.infinity,
                    alignment: Alignment.topCenter,
                    child: _Device(screen: home, width: 356, lang: lang),
                  ),
                ),
              ),
            ),
            '$out/02_lights_out.png',
          );
          home.dispose();
        }

        // ── 3. 초간편 추가 (실제 입력 시트 + 키보드) ────────
        if (want(3)) {
          final compose = await _captureApp(
            tester,
            lang: lang,
            settings: const {},
            viewInsetsBottom: _keyboardH,
            stage: (tester, c) async {
              await tester.tap(find.byIcon(Icons.add_rounded).last);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 450));
              await tester.enterText(
                find.byType(TextField).first,
                _composeTitle[lang]!,
              );
              await tester.pump(const Duration(milliseconds: 120));
              // 시간 행: 한 번 열어 9:00 확정, 다시 닫아 값만 남긴다
              final timeLabel = lang == 'ko' ? '시간' : 'Time';
              await tester.tap(find.text(timeLabel));
              await tester.pump(const Duration(milliseconds: 250));
              await tester.tap(find.text(timeLabel));
              await tester.pump(const Duration(milliseconds: 250));
            },
            settle: const Duration(milliseconds: 500),
          );
          await _renderPng(
            tester,
            _Frame(
              copy: copy[2],
              glow: 0.28,
              child: Padding(
                padding: const EdgeInsets.only(top: 34),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: OverflowBox(
                    maxHeight: double.infinity,
                    alignment: Alignment.topCenter,
                    child: _Device(
                      screen: compose,
                      width: 348,
                      lang: lang,
                      keyboard: true,
                    ),
                  ),
                ),
              ),
            ),
            '$out/03_quick_add.png',
          );
          compose.dispose();
        }

        // ── 4. 밤 — 잠든 토드 풀블리드 ──────────────────────
        if (want(4)) {
          await _renderPng(
            tester,
            _Frame(
              copy: copy[3],
              glow: 0,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF090E17)),
                  // 달이 타이틀과 겹치지 않게 하늘을 아래로 내린다 —
                  // 달은 서브 아래 좌측, 별은 토드 주변에 흩어진다
                  Transform.translate(
                    offset: const Offset(0, 230),
                    child: CustomPaint(painter: NightSkyPainter(opacity: 0.9)),
                  ),
                  const CustomPaint(
                    painter: _HaloPainter(
                      center: Offset(0.5, 0.58),
                      radius: 0.36,
                      color: Color(0xFF8FB4E8),
                      alpha: 0.12,
                    ),
                  ),
                ],
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  _HeroTodd(
                    mode: ToddMode.asleep,
                    event: GhostEvent.allDone,
                    size: 360,
                  ),
                ],
              ),
            ),
            '$out/04_good_night.png',
            settle: const Duration(milliseconds: 2200),
          );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
    skip: !export,
  );
}
