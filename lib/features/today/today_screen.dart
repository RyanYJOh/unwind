import 'dart:math' as math;

import 'package:flutter/material.dart'
    show Icons, MaterialLocalizations, TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/motion.dart';
import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';
import '../../domain/models/todd_state.dart';
import '../../ui/ui.dart';
import '../../widgets/corner_glow.dart';
import '../../widgets/todd/poke_squish.dart';
import '../../widgets/todd/todd_view.dart';
import '../../widgets/night_sky.dart';
import '../../widgets/pull_cord.dart';
import '../../core/utils/dates.dart';
import '../bill/bill_screen.dart';
import '../compose/compose_sheet.dart';
import '../settings/settings_screen.dart';
import '../week/week_label.dart';
import '../week/week_screen.dart';
import '../week/weekly_strip.dart';
import 'providers.dart';
import 'pull_cord_coach.dart';
import 'todo_actions.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.1 홈 — 오늘의 방. DB 스트림 구독 (§3.2), 조도는 brightnessProvider 단일값.
///
/// 디자인 시스템 v2(2026-08-12): 베이스는 항상 다크. 조도 t는 색이 아니라
/// [CornerGlow]의 세기만 몬다 — "남은 할 일 = 남은 빛".
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

  /// Todd에게 보내는 이벤트 — 체크 반응 / 톡 건드리기.
  /// 같은 이벤트를 연속 발사할 수 있도록 tick을 올린다.
  ToddEvent _toddEvent = ToddEvent.react;
  int _toddTick = 0;

  /// 톡 스쿼시 재생 틱 (ToddPokeSquish, 공용화 2026-08-22)
  int _squishTick = 0;

  final _cordKey = GlobalKey();
  Offset? _coachHole;

  @override
  void initState() {
    super.initState();
    _theme = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: UnwindMotion.themeMoveMs),
    );
    _tAnim = const AlwaysStoppedAnimation(0.0);

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: UnwindMotion.pulseRiseMs + UnwindMotion.pulseFallMs,
      ),
    );
    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: UnwindMotion.pulseAmount,
        ).chain(CurveTween(curve: UnwindMotion.pulseRise)),
        weight: UnwindMotion.pulseRiseMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: UnwindMotion.pulseAmount,
          end: 0.0,
        ).chain(CurveTween(curve: UnwindMotion.pulseFall)),
        weight: UnwindMotion.pulseFallMs.toDouble(),
      ),
    ]).animate(_pulse);

    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: UnwindMotion.breathPeriodMs),
    );
    _zoom = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: UnwindMotion.cordZoomOutMs),
    );
    _stars = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: UnwindMotion.starsFadeInMs),
    );

    // 초기 t 반영 (프레임 후 provider 값으로 점프 없이 세팅)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = ref.read(brightnessProvider);
      setState(() => _tAnim = AlwaysStoppedAnimation(t));
      if (ref.read(isAsleepProvider)) _stars.value = 1.0;
    });
  }

  int _coachMeasureTries = 0;

  void _presentCoach() {
    if (!mounted || _coachHole != null) return;
    final center = PullCord.handleCenterOf(_cordKey);
    if (center == null) {
      if (_coachMeasureTries++ < 8) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _presentCoach());
      }
      return;
    }
    _coachMeasureTries = 0;
    setState(() => _coachHole = center);
  }

  void _dismissCoach() {
    if (_coachHole == null && !ref.read(pullCordCoachVisibleProvider)) return;
    if (_coachHole != null) setState(() => _coachHole = null);
    ref.read(pullCordCoachVisibleProvider.notifier).dismiss();
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

  double get _displayT => (_tAnim.value + _pulseAnim.value).clamp(0.0, 1.0);

  void _animateThemeTo(double target, {Duration? duration}) {
    if ((target - _displayTStatic).abs() < 1e-9) return;
    _tAnim = Tween(
      begin: _displayTStatic,
      end: target,
    ).animate(CurvedAnimation(parent: _theme, curve: UnwindMotion.theme));
    _theme.duration =
        duration ?? const Duration(milliseconds: UnwindMotion.themeMoveMs);
    _theme.forward(from: 0);
  }

  // ── 개별 체크 (§9.2) ────────────────────────────────────────
  // 햅틱은 UnwindLampSwitch가 발사한다 (디자인 시스템 v2 — 컴포넌트가 담당).
  Future<void> _toggle(Todo todo) async {
    if (_dominoRunning) return;
    final repo = ref.read(todoRepositoryProvider);
    // 열람 중인 날짜 기준 (개편 2026-08-09) — 과거 날짜 편집도 그 날에 적용
    final viewedKey = ref.read(viewedDayKeyProvider);
    final asleep = ref.read(isAsleepProvider);

    // 취침 후 스위치 ON = 유령 깨우기 (개정 2026-08-07, undo)
    if (asleep) {
      await repo.wake(viewedKey);
      if (todo.status == TodoStatus.done) {
        await repo.setDone(todo, false); // 완료였던 항목은 되돌린다
      }
      // pending 항목은 상태 유지 — 깨어나면 등이 다시 켜진다
      return;
    }

    final done = todo.status != TodoStatus.done;
    if (done) {
      _pulse.forward(from: 0);
      setState(() {
        _toddEvent = ToddEvent.react;
        _toddTick++;
      });
    }
    await repo.setDone(todo, done); // 동기 쓰기 → 스트림이 UI 갱신 (§3.2)
  }

  // ── Todd를 톡 건드리기 (개편 2026-08-12) ─────────────────────
  // 반응 자체는 렌더러가 자기 모드를 보고 고른다(간지럼 / 실눈 두리번).
  // 여기서는 **잠들어 있으면 아무것도 하지 않는다** — 햅틱조차 없다.
  void _pokeTodd() {
    if (_dominoRunning) return;
    final mode = ref.read(toddModeProvider).mode;
    if (mode == ToddMode.asleep) return; // 무반응. 깨우지 않는다 — 스쿼시도 없다.

    final haptics = ref.read(hapticsProvider);
    // 졸린 밤엔 겨우 눈만 뜨니 촉감도 한 번, 낮엔 까르르 두 번
    if (mode == ToddMode.nightAwake) {
      haptics.tap();
    } else {
      haptics.success();
    }
    setState(() {
      _toddEvent = ToddEvent.poke;
      _toddTick++;
      _squishTick++; // 온보딩과 같은 스쿼시&바운스 물성 (공용화 2026-08-22)
    });
  }

  /// 월요일에만 지난주 청구서를 연다. 다른 요일이면 안내 영수증.
  Future<void> _openBill() async {
    final todayKey = ref.read(todayKeyProvider);
    if (!isMondayKey(todayKey)) {
      if (!mounted) return;
      await showBillMondayOnly(context);
      return;
    }
    final bill = await ref
        .read(billRepositoryProvider)
        .ensureLastWeekBill(
          todayKey,
          wakeHour: ref.read(wakeHourProvider),
          bedtimeHour: ref.read(bedtimeHourProvider),
        );
    if (!mounted || bill == null) return;
    await showBillScreen(context, bill);
  }

  // ── 소등 시퀀스 (§9.3) ──────────────────────────────────────
  Future<void> _runLightsOut() async {
    if (_dominoRunning) return;
    _dismissCoach();
    // 전등 줄은 오늘을 볼 때만 활성 — viewed == today가 보장된다
    final todos = ref.read(viewedTodosProvider).value ?? const <Todo>[];
    final repo = ref.read(todoRepositoryProvider);
    final haptics = ref.read(hapticsProvider);
    final todayKey = ref.read(viewedDayKeyProvider);
    final reduce = MediaQuery.disableAnimationsOf(context);

    setState(() => _dominoRunning = true);

    final lit = [
      for (final t in todos)
        if (t.status == TodoStatus.pending) t,
    ];
    final n = lit.length;

    if (!reduce) _zoom.forward(from: 0);

    final dominoMs = n == 0
        ? 0
        : (n - 1) * UnwindMotion.dominoIntervalMs + UnwindMotion.lampOffMs;
    _animateThemeTo(
      1.0,
      duration: Duration(
        milliseconds: reduce
            ? UnwindMotion.reducedFadeMs
            : math.max(dominoMs, UnwindMotion.themeMoveMs),
      ),
    );

    // 70ms 도미노 — 절대 동시에 꺼지지 않는다.
    for (var k = 0; k < n; k++) {
      if (k > 0) {
        await Future.delayed(
          const Duration(milliseconds: UnwindMotion.dominoIntervalMs),
        );
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
      } else {
        haptics.light();
      }
    }

    await Future.delayed(
      Duration(
        milliseconds: reduce
            ? UnwindMotion.reducedFadeMs
            : UnwindMotion.lampOffMs,
      ),
    );
    if (!mounted) return;

    // +500ms 정적 (§9.3 — 임의 단축 금지)
    await Future.delayed(
      const Duration(milliseconds: UnwindMotion.silenceAfterLastMs),
    );
    if (!mounted) return;

    // DB 기록 (개정 2026-08-15): 일괄 소등 = 일괄 완료 — 남은 등을 전부
    // 체크(done)하고 lightsOutAt/finalT를 기록한다 (§6.4)
    await repo.pullCord(todayKey, DateTime.now());

    if (reduce) {
      _stars.value = 1.0;
    } else {
      _stars.forward(from: 0);
    }
    if (mounted) setState(() => _dominoRunning = false);
  }

  // ── 삭제 (§6.1) ────────────────────────────────────────────
  // 규칙은 features/today/todo_actions.dart 한 곳에만 있다 — 주간 뷰와 공유.
  Future<bool> _delete(Todo todo, {required bool confirmSingle}) {
    if (_dominoRunning) return Future.value(false);
    return deleteTodoWithUndo(context, ref, todo, confirmSingle: confirmSingle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 열람 날짜의 방 (개편 2026-08-09) — 기본은 오늘
    final todos = ref.watch(viewedTodosProvider).value ?? const <Todo>[];
    final asleep = ref.watch(isAsleepProvider);
    // Todd 생활 모드 (개편 2026-08-08): 시각·체크 상태가 결정
    final toddMode = ref.watch(toddModeProvider);
    // Todd는 오직 오늘의 방에만 있다 (개정 2026-08-15) — 과거·미래 열람은
    // 빈 자리(바닥 그림자)만 남는다.
    final isViewingToday =
        ref.watch(viewedDayKeyProvider) == ref.watch(todayKeyProvider);
    final cordEnabled = ref.watch(pullCordEnabledProvider);
    final haptics = ref.watch(hapticsProvider);
    final reduce = MediaQuery.disableAnimationsOf(context);

    // 조도 목표 변화 → 빛 애니메이션 (도미노 중에는 시퀀스가 직접 몬다)
    ref.listen<double>(brightnessProvider, (prev, next) {
      if (!_dominoRunning) _animateThemeTo(next);
    });

    // 깨어나면(undo) 소등 오버라이드 해제 + 별이 걷힌다 (개정 2026-08-07)
    ref.listen<bool>(isAsleepProvider, (prev, next) {
      if (prev == true && next == false) {
        setState(() => _visualOffOverride.clear());
        _stars.reverse();
      }
    });

    // §10 밤 리마인더 조건 갱신 활성화
    ref.watch(morningGreetingSchedulerProvider);
    ref.watch(nightReminderSchedulerProvider);
    ref.watch(todoReminderSchedulerProvider);

    // 온보딩 직후, 오늘 방에 할 일을 새로 넣어 2개가 되면 전등 줄 안내
    ref.listen<bool>(pullCordCoachVisibleProvider, (prev, next) {
      if (next && prev != true) {
        Future<void>.delayed(
          const Duration(milliseconds: UnwindMotion.sheetMs),
          _presentCoach,
        );
      }
    });

    // §10 알림 탭 라우팅: 청구서 알림 → 월요일 게이트와 같은 경로
    ref.listen<String?>(notificationTapProvider, (prev, next) async {
      if (next == null) return;
      ref.read(notificationTapProvider.notifier).clear();
      if (next == 'bill') await _openBill();
      // 'home': 앱이 열리면 홈이 기본 화면
    });

    return UnwindScreen(
      safeArea: false,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _zoom,
            builder: (context, inner) {
              final scale =
                  UnwindMotion.cordZoomScale -
                  (UnwindMotion.cordZoomScale - 1.0) *
                      UnwindMotion.settle.transform(_zoom.value);
              return Transform.scale(
                scale: _zoom.value > 0 ? scale : 1.0,
                child: inner,
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
                            opacity: Curves.easeInOut.transform(_stars.value),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 코너 글로우: 다크 베이스 위 순수한 빛. 남은 할 일 = 남은 빛.
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_theme, _pulse, _breath]),
                    builder: (context, _) => CornerGlow(
                      light: 1 - _displayT,
                      breath: reduce
                          ? 0
                          : BreathAnimation(_breath).value * (1 - _displayT),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        onSettings: () => showSettingsScreen(context),
                        onBill: _openBill,
                      ),
                      // 유령 영역 — 고정 높이로 체크리스트와의 간격 축소.
                      // 오늘: Todd (탭하면 반응, 잠들었을 땐 무반응).
                      // 과거·미래: Todd는 오늘의 방에 있다 — 빈 자리만 남는다.
                      SizedBox(
                        height: 136,
                        child: !isViewingToday
                            ? _ToddAway(label: l10n.toddAway)
                            : Center(
                                child: UnwindPressable(
                                  onTap: _pokeTodd,
                                  depth: 0,
                                  pressScale: 1.0, // 반응은 캐릭터가 한다
                                  haptic:
                                      UnwindHapticKind.none, // _pokeTodd가 고른다
                                  isButton: false,
                                  semanticLabel: l10n.toddPokeLabel,
                                  child: Center(
                                    child: ToddPokeSquish(
                                      tick: _squishTick,
                                      child: AnimatedBuilder(
                                        animation: _theme,
                                        builder: (context, _) => ToddView(
                                        state: ToddState(
                                          brightness: _displayTStatic,
                                          // 시각 무관: 전부 체크 시 잠들고,
                                          // 밤의 빈 방도 잠든다
                                          isAsleep:
                                              toddMode.mode == ToddMode.asleep,
                                          mode: toddMode.mode,
                                          activity: toddMode.activity,
                                          dazzle: toddMode.dazzle,
                                          // 전날 불을 남겼으면 눈 밑에 다크서클
                                          darkCircles: ref.watch(
                                            darkCirclesProvider,
                                          ),
                                          event: _toddEvent,
                                          eventTick: _toddTick,
                                        ),
                                          reduceMotion: reduce,
                                          size: 118,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      Expanded(
                        child: todos.isEmpty
                            ? const _EmptyRoom()
                            : ListView.builder(
                                padding: const EdgeInsets.only(
                                  top: UnwindSpacing.s4,
                                  bottom: UnwindSpacing.s16,
                                ),
                                itemCount: todos.length,
                                itemBuilder: (context, i) =>
                                    _buildRow(context, l10n, todos[i], asleep),
                              ),
                      ),
                      // 하단 — 주 칩 + 이번 주 스트립 (개편 2026-08-13).
                      // Bill이 상단으로 갔으니 스트립이 너비를 다 쓴다.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          UnwindSpacing.s16,
                          0,
                          UnwindSpacing.s16,
                          UnwindSpacing.s8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 주 칩과 FAB는 같은 줄에 앉고 **하단 라인을 맞춘다**
                            // (개정 2026-08-13). 가운데 정렬하면 작은 칩이 위로
                            // 떠서 스트립과 멀어진다.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const _WeekPill(),
                                const Spacer(),
                                Opacity(
                                  opacity: asleep ? 0.55 : 1.0,
                                  child: UnwindIconButton(
                                    icon: Icons.add_rounded,
                                    iconSize: 32,
                                    size: 64,
                                    style: UnwindIconButtonStyle.accent,
                                    semanticLabel: l10n.addTaskLabel,
                                    onPressed: () {
                                      // 과거 날짜 열람 중엔 그 날짜로 추가
                                      final viewed = ref.read(
                                        viewedDayKeyProvider,
                                      );
                                      final today = ref.read(todayKeyProvider);
                                      showComposeSheet(
                                        context,
                                        initialDate: viewed != today
                                            ? viewed
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            // FAB가 스트립에 붙지 않게 한 칸 띄운다
                            const SizedBox(height: UnwindSpacing.s12),
                            AnimatedBuilder(
                              animation: _theme,
                              builder: (context, _) =>
                                  WeeklyStrip(currentT: _displayTStatic),
                            ),
                          ],
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
                      key: _cordKey,
                      enabled: cordEnabled && !_dominoRunning,
                      haptics: haptics,
                      onPull: _runLightsOut,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_coachHole != null)
            Positioned.fill(
              child: UnwindCoachMark(
                holeCenter: _coachHole!,
                holeRadius: UnwindSpacing.s24,
                message: l10n.pullCordCoach,
                onDismiss: _dismissCoach,
                reduceMotion: reduce,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    AppLocalizations l10n,
    Todo todo,
    bool asleep,
  ) {
    final isOn =
        todo.status == TodoStatus.pending &&
        !_visualOffOverride.contains(todo.id);

    return Dismissible(
      key: ValueKey(todo.id),
      direction: _dominoRunning
          ? DismissDirection.none
          : DismissDirection.endToStart,
      // 스와이프도 롱프레스와 같은 경로 — 반복 항목이면 범위를 묻는다.
      // 사용자가 취소하면 false를 돌려 항목이 제자리로 돌아온다.
      confirmDismiss: (_) => _delete(todo, confirmSingle: false),
      background: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UnwindSpacing.s20,
          vertical: UnwindSpacing.s4,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: UnwindColors.danger,
            borderRadius: BorderRadius.circular(UnwindRadius.md),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: UnwindSpacing.s20),
              child: Semantics(
                label: l10n.delete,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: UnwindColors.onDanger,
                  size: UnwindSpacing.s24,
                ),
              ),
            ),
          ),
        ),
      ),
      child: UnwindTodoTile(
        title: todo.title,
        timeLabel: todo.scheduledTimeMinutes == null
            ? null
            : MaterialLocalizations.of(context).formatTimeOfDay(
                TimeOfDay(
                  hour: todo.scheduledTimeMinutes! ~/ 60,
                  minute: todo.scheduledTimeMinutes! % 60,
                ),
                alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                  context,
                ),
              ),
        isOn: isOn,
        isDone: todo.status == TodoStatus.done,
        switchSemanticsOn: l10n.lampOn,
        switchSemanticsOff: l10n.lampOff,
        onToggle: _dominoRunning ? null : () => _toggle(todo),
        onTap: asleep || _dominoRunning
            ? null
            : () => showComposeSheet(context, existing: todo),
        onLongPress: _dominoRunning
            ? null
            : () => _delete(todo, confirmSingle: true),
      ),
    );
  }
}

/// 상단 행 — 설정 + 날짜 타이틀 + 청구서 (월요일·미확인이면 점)
class _TopBar extends ConsumerWidget {
  final VoidCallback onSettings;
  final VoidCallback onBill;

  const _TopBar({required this.onSettings, required this.onBill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final viewedKey = ref.watch(viewedDayKeyProvider);
    final todayKey = ref.watch(todayKeyProvider);
    final isPast = viewedKey != todayKey;
    final unread = ref.watch(unreadBillsProvider).value ?? const <WeeklyBill>[];
    final lastMonday = lastMondayKeyOf(todayKey);
    final hasUnread =
        isMondayKey(todayKey) && unread.any((b) => b.weekStart == lastMonday);

    final String title;
    if (isPast) {
      final d = parseDayKey(viewedKey);
      title = l10n.monthDay(
        l10n.monthsShort.split(',')[d.month - 1],
        d.month,
        d.day,
      );
    } else {
      title = l10n.today;
    }

    // 개편 2026-08-13: 청구서가 좌측 끝(이전 설정 자리)으로, 설정은 제목
    // 오른쪽으로 작게. 미확인이면 아이콘 우측 상단에 코랄 점
    // (개정 2026-08-16: 옆의 "Bill" 칩에서 점으로).
    return UnwindHeader(
      title: title,
      leading: UnwindPressable(
        onTap: onBill,
        depth: 0,
        semanticLabel: hasUnread ? l10n.notifBillArrived : l10n.billBadge,
        child: UnwindBadgeDot(
          visible: hasUnread,
          child: Image.asset(
            'assets/images/bill.png',
            width: UnwindSpacing.s40,
            height: UnwindSpacing.s40,
            fit: BoxFit.contain,
          ),
        ),
      ),
      titleTrailing: UnwindIconButton(
        icon: Icons.settings_outlined,
        iconSize: 18,
        size: 32,
        // 기본 textSecondary는 밝아진 코너 글로우 위에서 2.2:1까지 떨어진다
        // (§12는 UI 요소에 3:1을 요구한다). 홈 헤더에서만 한 단 올린다.
        color: UnwindColors.textPrimary,
        semanticLabel: l10n.settingsTitle,
        onPressed: onSettings,
      ),
    );
  }
}

/// 스트립이 보고 있는 주로 들어가는 알약 (개편 2026-08-13).
/// 스트립을 넘기면 라벨이 따라 바뀌고, 누르면 **그 주의** 주간 뷰가 열린다.
class _WeekPill extends ConsumerWidget {
  const _WeekPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayKey = ref.watch(todayKeyProvider);
    final mondayKey = stripMondayKey(
      todayKey,
      ref.watch(stripWeekOffsetProvider),
    );
    return UnwindPill(
      label: weekLabel(context, mondayKey: mondayKey, todayKey: todayKey),
      chevron: true, // 이동임을 알리는 작은 › (재도입 2026-08-15)
      onTap: () => showWeekScreen(context, mondayKey: mondayKey),
    );
  }
}

/// Todd의 빈 자리 (개정 2026-08-15) — 과거·미래 날짜의 방.
/// Todd는 오직 오늘의 방에만 있으므로 떠 있던 자리 아래 바닥 그림자만
/// 남긴다 (문구는 뺐다 — 2차 개정 2026-08-15: 그림자만으로 부재가 읽힌다).
/// 탭해도 반응 없음. [label]은 스크린 리더용 설명으로만 쓴다.
class _ToddAway extends StatelessWidget {
  final String label;

  const _ToddAway({required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Todd가 떠 있던 높이만큼 비워 둔다 — 부재가 읽히는 여백
          const SizedBox(height: 58),
          // 바닥 그림자 — 블러 없는 솔리드 타원 (§11, 디자인 시스템 §5.2)
          Container(
            width: 76,
            height: 13,
            decoration: const BoxDecoration(
              color: Color(0x30000000),
              borderRadius: BorderRadius.all(Radius.elliptical(38, 6.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UnwindSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.emptyRoomTitle,
              textAlign: TextAlign.center,
              style: UnwindType.headline.copyWith(
                color: UnwindColors.textPrimary,
              ),
            ),
            const SizedBox(height: UnwindSpacing.s8),
            Text(
              l10n.emptyRoomSubtitle,
              textAlign: TextAlign.center,
              style: UnwindType.body.copyWith(
                color: UnwindColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
