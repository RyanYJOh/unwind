import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/haptics/haptics.dart';
import '../../core/sound/sound_player.dart';
import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/color_ramp.dart';
import '../../core/tokens/motion.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../domain/models/lumi_state.dart';
import '../../domain/services/brightness_engine.dart';
import '../../core/tokens/design_variant.dart';
import '../../widgets/ceiling_light.dart';
import '../../widgets/lamp_row.dart';
import '../../widgets/lumi/lumi_view.dart';
import '../../widgets/night_sky.dart';
import '../../widgets/pull_cord.dart';
import '../../l10n/generated/app_localizations.dart';

/// §13 M0 — 감각 프로토타입.
/// 투두 기능 없음: 하드코딩 더미 5개, DB 없음, 입력 없음, 네비게이션 없음.
/// 목적: "손끝에서 기분이 좋은가"의 검증. M0 승인 전 M1 시작 금지.
class M0PrototypeScreen extends StatefulWidget {
  /// 온보딩(§6.6)에서 샘플 방으로 재사용한다.
  final List<String>? itemTitles;
  final VoidCallback? onSequenceComplete;
  final bool showReset;

  const M0PrototypeScreen({
    super.key,
    this.itemTitles,
    this.onSequenceComplete,
    this.showReset = true,
  });

  @override
  State<M0PrototypeScreen> createState() => _M0PrototypeScreenState();
}

class _M0Item {
  final String title;
  bool done;
  bool visualOn; // 소등 시퀀스 중 상태(pending)와 무관하게 불만 꺼진다 (§6.4)
  _M0Item(this.title)
      : done = false,
        visualOn = true;
}

class _M0PrototypeScreenState extends State<M0PrototypeScreen>
    with TickerProviderStateMixin {
  // ── 더미 데이터 (M0: 하드코딩 / 온보딩: 주입) ─────────────────
  late final List<_M0Item> _items = [
    for (final t in widget.itemTitles ??
        const ['치과 예약 전화하기', '장보기', '운동 30분', '회의록 정리해서 보내기', '화분에 물 주기'])
      _M0Item(t),
  ];

  final _engine = BrightnessEngine();
  final _haptics = UnwindHaptics();
  final _sound = SoundPlayer();

  // ── 조도 애니메이션 ──────────────────────────────────────────
  late final AnimationController _theme; // 전역 테마 이동
  late Animation<double> _tAnim;
  double _tTarget = 0.0;

  late final AnimationController _pulse; // §5.4 체크 펄스
  late final Animation<double> _pulseAnim;

  late final AnimationController _breath; // §5.5 호흡
  late final AnimationController _zoom; // §9.3 줌아웃
  late final AnimationController _stars; // §9.3 별/달빛 스며듦

  // ── 시퀀스 상태 ─────────────────────────────────────────────
  bool _pulled = false;
  bool _asleep = false;
  bool _showReset = false;
  int _reactTick = 0;

  @override
  void initState() {
    super.initState();
    _theme = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: UnwindMotion.themeMoveMs));
    _tAnim = AlwaysStoppedAnimation(_tTarget);

    _pulse = AnimationController(
        vsync: this,
        duration: const Duration(
            milliseconds:
                UnwindMotion.pulseRiseMs + UnwindMotion.pulseFallMs));
    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: UnwindMotion.pulseAmount)
            .chain(CurveTween(curve: UnwindMotion.pulseRise)),
        weight: UnwindMotion.pulseRiseMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(begin: UnwindMotion.pulseAmount, end: 0.0)
            .chain(CurveTween(curve: UnwindMotion.pulseFall)),
        weight: UnwindMotion.pulseFallMs.toDouble(),
      ),
    ]).animate(_pulse);

    _breath = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: UnwindMotion.breathPeriodMs));

    _zoom = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: UnwindMotion.cordZoomOutMs));
    _stars = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: UnwindMotion.starsFadeInMs));

    _sound.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // §5.5 / §9.5: Reduce Motion 시 호흡 비활성
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat();
    }
  }

  @override
  void dispose() {
    _theme.dispose();
    _pulse.dispose();
    _breath.dispose();
    _zoom.dispose();
    _stars.dispose();
    _sound.dispose();
    super.dispose();
  }

  int get _doneCount => _items.where((i) => i.done).length;

  void _animateThemeTo(double target, {Duration? duration}) {
    _tAnim = Tween(begin: _displayTStatic, end: target).animate(
        CurvedAnimation(parent: _theme, curve: UnwindMotion.theme));
    _tTarget = target;
    _theme.duration =
        duration ?? const Duration(milliseconds: UnwindMotion.themeMoveMs);
    _theme.forward(from: 0);
  }

  /// 펄스를 제외한 현재 테마 t (애니메이션 중간값 포함)
  double get _displayTStatic => _tAnim.value;

  /// §5.4 t_display = t_target + pulse, 1.0 넘지 않도록 clamp
  double get _displayT =>
      (_tAnim.value + _pulseAnim.value).clamp(0.0, 1.0);

  // ── 개별 체크 (§9.2) ────────────────────────────────────────
  void _toggle(int index) {
    if (_pulled) return;
    final item = _items[index];
    setState(() {
      item.done = !item.done;
      item.visualOn = !item.done;
    });

    if (item.done) {
      _haptics.tadak(); // "타닥" (개정 2026-08-07)
      _sound.click(); // 0ms: 짧은 딸깍
      _engine.onItemCompleted(
          doneCount: _doneCount, totalCount: _items.length);
      _pulse.forward(from: 0); // 체크 펄스
      _reactTick++; // Lumi 반응 (§7.3)
    } else {
      _haptics.tadak();
      _engine.onItemUncompleted(
          doneCount: _doneCount, totalCount: _items.length);
    }
    _animateThemeTo(
        _engine.t(doneCount: _doneCount, totalCount: _items.length));
  }

  // ── 소등 시퀀스 (§9.3) ──────────────────────────────────────
  Future<void> _runLightsOut() async {
    if (_pulled) return;
    setState(() => _pulled = true);
    _engine.pullCord();

    final reduce = MediaQuery.disableAnimationsOf(context);
    final lit = <int>[
      for (var i = 0; i < _items.length; i++)
        if (_items[i].visualOn) i
    ];
    final n = lit.length;

    // 0ms: 화면 전체 미세 줌아웃 1.02 → 1.00 (Reduce Motion 시 없음)
    if (!reduce) _zoom.forward(from: 0);

    // 전역 테마 → 1.0. 도미노 전체 길이에 맞춰 이동.
    final dominoMs = n == 0
        ? 0
        : (n - 1) * UnwindMotion.dominoIntervalMs + UnwindMotion.lampOffMs;
    _animateThemeTo(1.0,
        duration: Duration(
            milliseconds: reduce
                ? UnwindMotion.reducedFadeMs
                : math.max(dominoMs, UnwindMotion.themeMoveMs)));

    // 도미노 — 절대 동시에 꺼지지 않는다. 70ms 간격 순차 소등.
    // §9.5: Reduce Motion이어도 햅틱·사운드의 타라라락은 유지한다.
    for (var k = 0; k < n; k++) {
      if (k > 0) {
        await Future.delayed(
            const Duration(milliseconds: UnwindMotion.dominoIntervalMs));
      }
      if (!mounted) return;
      final isLast = k == n - 1;
      if (reduce) {
        // 시각은 전체 페이드 하나로 — 첫 등 시점에 일괄 시작
        if (k == 0) {
          setState(() {
            for (final i in lit) {
              _items[i].visualOn = false;
            }
          });
        }
      } else {
        setState(() => _items[lit[k]].visualOn = false);
      }
      if (isLast) {
        _haptics.heavy(); // 마지막 등 — 길고 낮은 울림
        _sound.lastNote(); // 항상 C3
      } else {
        _haptics.light();
        _sound.dominoNote(k); // C5 → A4 → F4 → D4 → C4 순환
      }
    }

    // 마지막 등 소등 완료까지 대기
    await Future.delayed(Duration(
        milliseconds: reduce
            ? UnwindMotion.reducedFadeMs
            : UnwindMotion.lampOffMs));
    if (!mounted) return;

    // +500ms: 정적. 아무 일도 일어나지 않는다. (임의 단축 금지 §1.3)
    await Future.delayed(
        const Duration(milliseconds: UnwindMotion.silenceAfterLastMs));
    if (!mounted) return;

    // Lumi 잠들기 1400ms + 별/달빛 스며듦 2000ms (동시 시작)
    setState(() => _asleep = true);
    if (reduce) {
      _stars.value = 1.0; // 스며듦 없음 — 즉시
    } else {
      _stars.forward(from: 0);
    }

    // TODO(unwind): 전부 완료하고 당긴 경우의 달빛 추가 연출 + 다른 자세,
    // 미룬 것이 있으면 담백한 버전 (§9.3) — M0 이후 사용자 승인 받고 구현.

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    if (widget.showReset) setState(() => _showReset = true);
    widget.onSequenceComplete?.call();
  }

  /// M0 테스트 전용 — 감각 반복 검증을 위한 리셋. 제품 기능 아님.
  void _reset() {
    setState(() {
      for (final i in _items) {
        i.done = false;
        i.visualOn = true;
      }
      _pulled = false;
      _asleep = false;
      _showReset = false;
      _engine.rollover();
      _stars.value = 0;
      _zoom.value = 0;
    });
    _animateThemeTo(0.0);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_theme, _pulse]),
      builder: (context, child) {
        final colors = lerpRamp(_displayT);
        return UnwindTheme(
          colors: colors,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: colors.textFlipProgress < 0.5
                ? SystemUiOverlayStyle.dark
                : SystemUiOverlayStyle.light,
            child: AnimatedBuilder(
              animation: _zoom,
              builder: (context, inner) {
                final scale = UnwindMotion.cordZoomScale -
                    (UnwindMotion.cordZoomScale - 1.0) *
                        UnwindMotion.settle.transform(_zoom.value);
                return Transform.scale(
                    scale: _zoom.isAnimating || _zoom.value > 0 ? scale : 1.0,
                    child: inner);
              },
              child: ColoredBox(
                color: colors.bg,
                // Material 조상 없이 Text를 쓰므로 기본 데코레이션(노란 밑줄) 제거
                child: DefaultTextStyle(
                  style: UnwindType.body.copyWith(
                      decoration: TextDecoration.none),
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
      child: Stack(
        children: [
          // 별/달빛 레이어 — 소등 후 아주 천천히 스며듦
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _stars,
                  builder: (context, _) => CustomPaint(
                    painter: NightSkyPainter(
                        opacity:
                            Curves.easeInOut.transform(_stars.value)),
                  ),
                ),
              ),
            ),
          ),
          // 천장 조명 (디자인 개편 2026-08-07)
          if (kRoomDesign == RoomDesign.ceilingLight)
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_theme, _pulse, _breath]),
                  builder: (context, _) => CeilingLight(
                    light: 1 - _displayT,
                    breath:
                        BreathAnimation(_breath).value * (1 - _displayT),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: UnwindSpacing.s16),
                // (M0: 주간 스트립 없음 — M2에서)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: UnwindSpacing.s24),
                  child: Builder(
                    builder: (context) => PrimaryText(
                        AppLocalizations.of(context).today,
                        style: UnwindType.title),
                  ),
                ),
                // 캐릭터 영역
                Expanded(
                  flex: 5,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _theme,
                      builder: (context, _) => LumiView(
                        state: LumiState(
                          brightness: _displayTStatic,
                          isAsleep: _asleep,
                          event: LumiEvent.react,
                          eventTick: _reactTick,
                        ),
                        reduceMotion: reduce,
                      ),
                    ),
                  ),
                ),
                // 등 목록 — 완료해도 사라지지 않고 제자리 (§6.1)
                Expanded(
                  flex: 6,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                        bottom: UnwindSpacing.s48),
                    itemCount: _items.length,
                    itemBuilder: (context, i) => LampRow(
                      title: _items[i].title,
                      isOn: _items[i].visualOn,
                      breath: reduce ? null : BreathAnimation(_breath),
                      onToggle: _pulled ? null : () => _toggle(i),
                      dominoBounce: _pulled, // 순차 통통 (개편)
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 전등 줄 — 우측, 항상 보인다 (§6.4)
          Positioned(
            top: 0,
            right: UnwindSpacing.s24,
            child: SafeArea(
              child: PullCord(
                enabled: !_pulled && _items.isNotEmpty,
                haptics: _haptics,
                onPull: _runLightsOut,
              ),
            ),
          ),
          // M0 리셋 (테스트 전용)
          if (_showReset)
            Positioned(
              bottom: UnwindSpacing.s32,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _reset,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(UnwindSpacing.s12),
                    child: Builder(
                      builder: (context) => Text(
                        AppLocalizations.of(context).m0Reset,
                        style: UnwindType.caption.copyWith(
                            color: UnwindTheme.of(context).textMuted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
