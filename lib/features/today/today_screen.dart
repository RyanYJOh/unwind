import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show CupertinoActionSheet, CupertinoActionSheetAction, showCupertinoModalPopup;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/color_ramp.dart';
import '../../core/tokens/motion.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';
import '../../domain/models/lumi_state.dart';
import '../../widgets/lamp_row.dart';
import '../../widgets/lumi/lumi_view.dart';
import '../../widgets/night_sky.dart';
import '../../widgets/pull_cord.dart';
import '../bill/bill_screen.dart';
import '../compose/compose_sheet.dart';
import '../settings/settings_controller.dart';
import '../week/week_screen.dart';
import '../week/weekly_strip.dart';
import 'providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.1 홈 — 오늘의 방. DB 스트림 구독 (§3.2), 조도는 brightnessProvider 단일값.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with TickerProviderStateMixin {
  late final AnimationController _theme;
  late Animation<double> _tAnim;

  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;
  late final AnimationController _breath;
  late final AnimationController _zoom;
  late final AnimationController _stars;

  /// 소등 시퀀스 동안 pending 항목의 불을 시각적으로만 끄기 위한 오버라이드
  final Set<String> _visualOffOverride = {};
  bool _dominoRunning = false;
  int _reactTick = 0;

  @override
  void initState() {
    super.initState();
    _theme = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: UnwindMotion.themeMoveMs));
    _tAnim = const AlwaysStoppedAnimation(0.0);

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

    // 초기 t 반영 (프레임 후 provider 값으로 점프 없이 세팅)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = ref.read(brightnessProvider);
      setState(() => _tAnim = AlwaysStoppedAnimation(t));
      if (ref.read(isAsleepProvider)) _stars.value = 1.0;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    super.dispose();
  }

  double get _displayTStatic => _tAnim.value;

  double get _displayT =>
      (_tAnim.value + _pulseAnim.value).clamp(0.0, 1.0);

  void _animateThemeTo(double target, {Duration? duration}) {
    if ((target - _displayTStatic).abs() < 1e-9) return;
    _tAnim = Tween(begin: _displayTStatic, end: target).animate(
        CurvedAnimation(parent: _theme, curve: UnwindMotion.theme));
    _theme.duration =
        duration ?? const Duration(milliseconds: UnwindMotion.themeMoveMs);
    _theme.forward(from: 0);
  }

  // ── 개별 체크 (§9.2) ────────────────────────────────────────
  Future<void> _toggle(Todo todo) async {
    if (_dominoRunning) return;
    final repo = ref.read(todoRepositoryProvider);
    final haptics = ref.read(hapticsProvider);
    final sound = ref.read(soundPlayerProvider);
    final done = todo.status != TodoStatus.done;

    haptics.tadak(); // "타닥" — light→medium 연속 (개정 2026-08-07)
    if (done) {
      sound.click();
      _pulse.forward(from: 0);
      _reactTick++;
    }
    await repo.setDone(todo, done); // 동기 쓰기 → 스트림이 UI 갱신 (§3.2)
  }

  // ── 소등 시퀀스 (§9.3) ──────────────────────────────────────
  Future<void> _runLightsOut() async {
    if (_dominoRunning) return;
    final todos = ref.read(todayTodosProvider).value ?? const <Todo>[];
    final repo = ref.read(todoRepositoryProvider);
    final haptics = ref.read(hapticsProvider);
    final sound = ref.read(soundPlayerProvider);
    final todayKey = ref.read(todayKeyProvider);
    final reduce = MediaQuery.disableAnimationsOf(context);

    setState(() => _dominoRunning = true);

    final lit = [
      for (final t in todos)
        if (t.status == TodoStatus.pending) t
    ];
    final n = lit.length;

    if (!reduce) _zoom.forward(from: 0);

    final dominoMs = n == 0
        ? 0
        : (n - 1) * UnwindMotion.dominoIntervalMs + UnwindMotion.lampOffMs;
    _animateThemeTo(1.0,
        duration: Duration(
            milliseconds: reduce
                ? UnwindMotion.reducedFadeMs
                : math.max(dominoMs, UnwindMotion.themeMoveMs)));

    // 70ms 도미노 — 절대 동시에 꺼지지 않는다.
    for (var k = 0; k < n; k++) {
      if (k > 0) {
        await Future.delayed(
            const Duration(milliseconds: UnwindMotion.dominoIntervalMs));
      }
      if (!mounted) return;
      final isLast = k == n - 1;
      setState(() {
        if (reduce && k == 0) {
          _visualOffOverride.addAll([for (final t in lit) t.id]);
        } else if (!reduce) {
          _visualOffOverride.add(lit[k].id);
        }
      });
      if (isLast) {
        haptics.heavy();
        sound.lastNote();
      } else {
        haptics.light();
        sound.dominoNote(k);
      }
    }

    await Future.delayed(Duration(
        milliseconds:
            reduce ? UnwindMotion.reducedFadeMs : UnwindMotion.lampOffMs));
    if (!mounted) return;

    // +500ms 정적 (§9.3 — 임의 단축 금지)
    await Future.delayed(
        const Duration(milliseconds: UnwindMotion.silenceAfterLastMs));
    if (!mounted) return;

    // DB 기록: 상태는 pending 유지, lightsOutAt/finalT만 (§6.4)
    await repo.pullCord(todayKey, DateTime.now());

    if (reduce) {
      _stars.value = 1.0;
    } else {
      _stars.forward(from: 0);
    }
    // TODO(unwind): 전부 완료/미룸 여부에 따른 연출 분기 (§9.3) — 미결정 §15
    if (mounted) setState(() => _dominoRunning = false);
  }

  // ── 롱프레스 메뉴 (§6.1) ────────────────────────────────────
  void _showItemMenu(Todo todo) {
    final l10n = AppLocalizations.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(todo.title),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              showComposeSheet(context, existing: todo);
            },
            child: Text(l10n.edit),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(todoRepositoryProvider).remove(todo);
            },
            child: Text(l10n.delete),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.close),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final todos = ref.watch(todayTodosProvider).value ?? const <Todo>[];
    final asleep = ref.watch(isAsleepProvider);
    final cordEnabled = ref.watch(pullCordEnabledProvider);
    final haptics = ref.watch(hapticsProvider);
    final reduce = MediaQuery.disableAnimationsOf(context);

    // 조도 목표 변화 → 테마 애니메이션 (도미노 중에는 시퀀스가 직접 몬다)
    ref.listen<double>(brightnessProvider, (prev, next) {
      if (!_dominoRunning) _animateThemeTo(next);
    });

    // §10 밤 리마인더 조건 갱신 활성화
    ref.watch(nightReminderSchedulerProvider);

    // §10 알림 탭 라우팅: 청구서 알림 → 청구서 화면
    ref.listen<String?>(notificationTapProvider, (prev, next) async {
      if (next == null) return;
      ref.read(notificationTapProvider.notifier).clear();
      if (next == 'bill') {
        final bills =
            await ref.read(billRepositoryProvider).watchUnread().first;
        if (context.mounted && bills.isNotEmpty) {
          showBillScreen(context, bills.first);
        }
      }
      // 'home': 앱이 열리면 홈이 기본 화면
    });

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
                    scale: _zoom.value > 0 ? scale : 1.0, child: inner);
              },
              child: ColoredBox(
                color: colors.bg,
                child: DefaultTextStyle(
                  style: UnwindType.body
                      .copyWith(decoration: TextDecoration.none),
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _stars,
                  builder: (context, _) => CustomPaint(
                    painter: NightSkyPainter(
                        opacity: Curves.easeInOut.transform(_stars.value)),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: UnwindSpacing.s8),
                // 주간 스트립 (§6.2) — 아래로 당기면 주간 뷰
                AnimatedBuilder(
                  animation: _theme,
                  builder: (context, _) =>
                      WeeklyStrip(currentT: _displayTStatic),
                ),
                const SizedBox(height: UnwindSpacing.s8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: UnwindSpacing.s24),
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) =>
                            PrimaryText(l10n.today, style: UnwindType.title),
                      ),
                      const Spacer(),
                      // §6.5 미확인 청구서 배지
                      if ((ref.watch(unreadBillsProvider).value ?? const [])
                          .isNotEmpty)
                        Builder(builder: (context) {
                          final colors = UnwindTheme.of(context);
                          final bill = ref
                              .watch(unreadBillsProvider)
                              .value!
                              .first;
                          return GestureDetector(
                            onTap: () => showBillScreen(context, bill),
                            behavior: HitTestBehavior.opaque,
                            child: Semantics(
                              label: l10n.notifBillArrived,
                              button: true,
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(UnwindSpacing.s8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: colors.lamp),
                                    ),
                                    const SizedBox(width: UnwindSpacing.s4),
                                    Text(l10n.billBadge,
                                        style: UnwindType.label.copyWith(
                                            color: colors.textSecondary,
                                            decoration:
                                                TextDecoration.none)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _theme,
                      builder: (context, _) => LumiView(
                        state: LumiState(
                          brightness: _displayTStatic,
                          isAsleep: asleep,
                          event: LumiEvent.react,
                          eventTick: _reactTick,
                        ),
                        reduceMotion: reduce,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: todos.isEmpty
                      ? _EmptyRoom()
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                              bottom: UnwindSpacing.s48 * 2),
                          itemCount: todos.length,
                          itemBuilder: (context, i) {
                            final todo = todos[i];
                            final isOn =
                                todo.status == TodoStatus.pending &&
                                    !_visualOffOverride.contains(todo.id);
                            // 개정 2026-08-07: 스위치=토글, 패널 탭=편집
                            return LampRow(
                              title: todo.title,
                              isOn: isOn,
                              breath:
                                  reduce ? null : BreathAnimation(_breath),
                              onToggle: asleep || _dominoRunning
                                  ? null
                                  : () => _toggle(todo),
                              onTap: asleep || _dominoRunning
                                  ? null
                                  : () =>
                                      showComposeSheet(context, existing: todo),
                              onLongPress: _dominoRunning
                                  ? null
                                  : () => _showItemMenu(todo),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          // 전등 줄 (§6.4)
          Positioned(
            top: 0,
            right: UnwindSpacing.s24,
            child: SafeArea(
              child: PullCord(
                enabled: cordEnabled && !_dominoRunning,
                haptics: haptics,
                onPull: _runLightsOut,
              ),
            ),
          ),
          // FAB (§6.1) — 우측 하단, 조도가 낮을수록 더 또렷해진다
          Positioned(
            right: UnwindSpacing.s24,
            bottom: UnwindSpacing.s32,
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _theme,
                builder: (context, _) => _Fab(
                  t: _displayTStatic,
                  quiet: asleep, // 취침 후: 발광 제거, 불투명도 0.6
                  onTap: () => showComposeSheet(context),
                ),
              ),
            ),
          ),
          // 주간 뷰 오버레이 (개정 2026-08-07): 토글 + 영속 (§6.2 개정).
          // 위에서 펼쳐지는 380ms settle 전환 유지 (§9.4). 앱 재실행 시에도
          // weekViewOpen 설정에 따라 열린 채 시작된다.
          Positioned.fill(
            child: Consumer(builder: (context, ref, _) {
              final weekOpen = ref.watch(settingsControllerProvider
                      .select((s) => s.value?.weekViewOpen)) ??
                  false;
              return IgnorePointer(
                ignoring: !weekOpen,
                child: AnimatedSlide(
                  offset: weekOpen ? Offset.zero : const Offset(0, -1.1),
                  duration: const Duration(
                      milliseconds: UnwindMotion.weekExpandMs),
                  curve: UnwindMotion.settle,
                  child: WeekScreen(
                    onCollapse: () => ref
                        .read(settingsControllerProvider.notifier)
                        .setWeekViewOpen(false),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// §6.1 빈 상태 — 사과가 아니라 초대 (§8.5)
class _EmptyRoom extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryText(l10n.emptyRoomTitle, style: UnwindType.bodyStrong),
          const SizedBox(height: UnwindSpacing.s8),
          Text(l10n.emptyRoomSubtitle,
              style: UnwindType.label.copyWith(
                  color: colors.textSecondary,
                  decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

/// §6.1 FAB — 방에 마지막까지 남아 있는 작은 불빛.
class _Fab extends StatelessWidget {
  final double t;
  final bool quiet;
  final VoidCallback onTap;

  const _Fab({required this.t, required this.quiet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);
    // 조도가 낮을수록 또렷해진다: glow 강도 t에 비례. 취침 후엔 조용한 상태.
    final glow = quiet ? 0.0 : (0.25 + 0.75 * t);
    return Semantics(
      label: AppLocalizations.of(context).addTaskLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: quiet ? 0.6 : 1.0,
          child: SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _FabPainter(
                glow: glow,
                bodyColor: colors.surfaceRaised,
                iconColor: colors.textSecondary,
                glowColor: colors.lamp,
                shadowColor: colors.shadow,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FabPainter extends CustomPainter {
  final double glow;
  final Color bodyColor;
  final Color iconColor;
  final Color glowColor;
  final Color shadowColor;

  const _FabPainter({
    required this.glow,
    required this.bodyColor,
    required this.iconColor,
    required this.glowColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const r = 24.0;

    if (glow > 0.01) {
      final glowR = r * (1.6 + 0.5 * glow);
      canvas.drawCircle(
        c,
        glowR,
        Paint()
          ..shader = RadialGradient(colors: [
            glowColor.withValues(alpha: 0.4 * glow),
            glowColor.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: c, radius: glowR)),
      );
    }
    // 부드러운 그림자 (§8.4 — 검정 금지, 따뜻한 계열)
    canvas.drawCircle(c.translate(0, 2), r,
        Paint()..color = shadowColor.withValues(alpha: shadowColor.a * 0.9));
    canvas.drawCircle(c, r, Paint()..color = bodyColor);

    final p = Paint()
      ..color = iconColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-8, 0), c.translate(8, 0), p);
    canvas.drawLine(c.translate(0, -8), c.translate(0, 8), p);
  }

  @override
  bool shouldRepaint(_FabPainter old) =>
      old.glow != glow ||
      old.bodyColor != bodyColor ||
      old.iconColor != iconColor ||
      old.glowColor != glowColor ||
      old.shadowColor != shadowColor;
}
