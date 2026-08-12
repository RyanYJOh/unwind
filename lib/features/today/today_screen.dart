import 'dart:convert' show jsonEncode;
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
import '../../data/repositories/todo_repository.dart';
import '../../domain/models/lumi_state.dart';
import '../../ui/ui.dart';
import '../../widgets/corner_glow.dart';
import '../../widgets/lumi/lumi_view.dart';
import '../../widgets/night_sky.dart';
import '../../widgets/pull_cord.dart';
import '../../core/utils/dates.dart';
import '../../domain/services/bill_calculator.dart';
import '../bill/bill_screen.dart';
import '../compose/compose_sheet.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_screen.dart';
import '../week/week_screen.dart';
import '../week/weekly_strip.dart';
import 'providers.dart';
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

  /// Lumi에게 보내는 이벤트 — 체크 반응 / 톡 건드리기.
  /// 같은 이벤트를 연속 발사할 수 있도록 tick을 올린다.
  LumiEvent _lumiEvent = LumiEvent.react;
  int _lumiTick = 0;

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
    final sound = ref.read(soundPlayerProvider);
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
      sound.click();
      _pulse.forward(from: 0);
      setState(() {
        _lumiEvent = LumiEvent.react;
        _lumiTick++;
      });
    }
    await repo.setDone(todo, done); // 동기 쓰기 → 스트림이 UI 갱신 (§3.2)
  }

  // ── Lumi를 톡 건드리기 (개편 2026-08-12) ─────────────────────
  // 반응 자체는 렌더러가 자기 모드를 보고 고른다(간지럼 / 실눈 두리번).
  // 여기서는 **잠들어 있으면 아무것도 하지 않는다** — 햅틱조차 없다.
  void _pokeLumi() {
    if (_dominoRunning) return;
    final mode = ref.read(lumiModeProvider).mode;
    if (mode == LumiMode.asleep) return; // 무반응. 깨우지 않는다.

    final haptics = ref.read(hapticsProvider);
    // 졸린 밤엔 겨우 눈만 뜨니 촉감도 한 번, 낮엔 까르르 두 번
    if (mode == LumiMode.nightAwake) {
      haptics.tap();
    } else {
      haptics.success();
    }
    setState(() {
      _lumiEvent = LumiEvent.poke;
      _lumiTick++;
    });
  }

  // ── 더미 청구서 미리보기 (개발용, 2026-08-08) ────────────────
  // 실데이터 없이 청구서 화면을 확인하기 위한 가짜 지난주 청구서.
  void _openDummyBill() {
    final todayKey = ref.read(todayKeyProvider);
    final lastMonday = dayKey(
      addDays(parseDayKey(weekMondayKey(todayKey)), -7),
    );
    const kwhByDay = [0.42, 0.30, 0.55, 0.18, 0.36, 0.24, 0.12];
    const lightsOutByDay = [true, true, false, true, true, false, true];
    final days = [
      for (var i = 0; i < 7; i++)
        DayBill(
          date: dayKey(addDays(parseDayKey(lastMonday), i)),
          kwh: kwhByDay[i],
          lightsOut: lightsOutByDay[i],
          sleepMinutes: lightsOutByDay[i] ? 420 + i * 10 : 0,
        ),
    ];
    final totalKwh = days.fold<double>(0, (sum, d) => sum + d.kwh);
    final sleepTotal = days.fold<int>(0, (sum, d) => sum + d.sleepMinutes);
    showBillScreen(
      context,
      WeeklyBill(
        weekStart: lastMonday,
        kwh: totalKwh,
        amount: round10(totalKwh * kUnitPrice + kBaseFee),
        sleepMinutes: sleepTotal,
        generatedAt: DateTime.now(),
        isRead: true,
        payload: jsonEncode([for (final d in days) d.toJson()]),
      ),
    );
  }

  // ── 소등 시퀀스 (§9.3) ──────────────────────────────────────
  Future<void> _runLightsOut() async {
    if (_dominoRunning) return;
    // 전등 줄은 오늘을 볼 때만 활성 — viewed == today가 보장된다
    final todos = ref.read(viewedTodosProvider).value ?? const <Todo>[];
    final repo = ref.read(todoRepositoryProvider);
    final haptics = ref.read(hapticsProvider);
    final sound = ref.read(soundPlayerProvider);
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
        sound.lastNote();
      } else {
        haptics.light();
        sound.dominoNote(k);
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

    // DB 기록: 상태는 pending 유지, lightsOutAt/finalT만 (§6.4)
    await repo.pullCord(todayKey, DateTime.now());

    if (reduce) {
      _stars.value = 1.0;
    } else {
      _stars.forward(from: 0);
    }
    if (mounted) setState(() => _dominoRunning = false);
  }

  // ── 삭제 (§6.1) — 롱프레스와 스와이프가 같은 경로를 쓴다 ───────
  //
  // 반복 항목은 **어느 경로로 지우든** 범위를 먼저 묻는다
  // (개정 2026-08-12: 스와이프가 이 확인을 건너뛰던 버그).
  // 지운 뒤에는 되돌리기가 붙은 상단 토스트를 띄운다.
  Future<bool> _delete(Todo todo, {required bool confirmSingle}) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(todoRepositoryProvider);

    if (todo.recurrenceId != null) {
      final deleteFuture = await showUnwindActions<bool>(
        context,
        title: todo.title,
        cancelLabel: l10n.close,
        actions: [
          UnwindAction(
            label: l10n.deleteThisTask,
            value: false,
            destructive: true,
          ),
          UnwindAction(
            label: l10n.deleteFutureRecurring,
            value: true,
            destructive: true,
          ),
        ],
      );
      if (deleteFuture == null || !mounted) return false;
      final undo = deleteFuture
          ? await repo.removeRecurringFrom(todo)
          : await repo.remove(todo);
      _showDeletedToast(todo, undo);
      return true;
    }

    if (confirmSingle) {
      final ok = await showUnwindConfirm(
        context,
        title: todo.title,
        confirmLabel: l10n.delete,
        cancelLabel: l10n.close,
      );
      if (!ok || !mounted) return false;
    }
    final undo = await repo.remove(todo);
    _showDeletedToast(todo, undo);
    return true;
  }

  void _showDeletedToast(Todo todo, TodoUndo undo) {
    if (!mounted) return;
    showUnwindToast(
      context,
      title: todo.title,
      body: AppLocalizations.of(context).toastTaskDeleted,
      actionLabel: AppLocalizations.of(context).undo,
      onAction: () => undo(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 열람 날짜의 방 (개편 2026-08-09) — 기본은 오늘
    final todos = ref.watch(viewedTodosProvider).value ?? const <Todo>[];
    final asleep = ref.watch(isAsleepProvider);
    // Lumi 생활 모드 (개편 2026-08-08): 시각·체크 상태가 결정
    final lumiMode = ref.watch(lumiModeProvider);
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
    ref.watch(nightReminderSchedulerProvider);
    ref.watch(todoReminderSchedulerProvider);

    // §10 알림 탭 라우팅: 청구서 알림 → 청구서 화면
    ref.listen<String?>(notificationTapProvider, (prev, next) async {
      if (next == null) return;
      ref.read(notificationTapProvider.notifier).clear();
      if (next == 'bill') {
        final bills = await ref
            .read(billRepositoryProvider)
            .watchUnread()
            .first;
        if (context.mounted && bills.isNotEmpty) {
          showBillScreen(context, bills.first);
        }
      }
      // 'home': 앱이 열리면 홈이 기본 화면
    });

    return UnwindScreen(
      safeArea: false,
      child: AnimatedBuilder(
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
                    onBill: (bill) => showBillScreen(context, bill),
                  ),
                  // 유령 영역 — 고정 높이로 체크리스트와의 간격 축소.
                  // 탭하면 Lumi가 반응한다 (잠들었을 땐 무반응).
                  SizedBox(
                    height: 136,
                    child: Center(
                      child: UnwindPressable(
                        onTap: _pokeLumi,
                        depth: 0,
                        pressScale: 1.0, // 반응은 캐릭터가 한다
                        haptic: UnwindHapticKind.none, // _pokeLumi가 고른다
                        isButton: false,
                        semanticLabel: l10n.lumiPokeLabel,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _theme,
                            builder: (context, _) => LumiView(
                              state: LumiState(
                                brightness: _displayTStatic,
                                // 시각 무관: 전부 체크 시 잠들고, 밤의 빈 방도 잠든다
                                isAsleep: lumiMode.mode == LumiMode.asleep,
                                mode: lumiMode.mode,
                                activity: lumiMode.activity,
                                dazzle: lumiMode.dazzle,
                                event: _lumiEvent,
                                eventTick: _lumiTick,
                              ),
                              reduceMotion: reduce,
                              size: 118,
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
                              bottom: UnwindSpacing.s48 * 2 + UnwindSpacing.s24,
                            ),
                            itemCount: todos.length,
                            itemBuilder: (context, i) =>
                                _buildRow(context, l10n, todos[i], asleep),
                          ),
                  ),
                  // 최근 30일 스트립 + Bill 버튼
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      UnwindSpacing.s16,
                      0,
                      UnwindSpacing.s16,
                      UnwindSpacing.s8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _theme,
                            builder: (context, _) =>
                                WeeklyStrip(currentT: _displayTStatic),
                          ),
                        ),
                        const SizedBox(width: UnwindSpacing.s12),
                        // Bill — 이미지 그대로, 감싸는 컨테이너·패딩 없음
                        UnwindPressable(
                          onTap: _openDummyBill,
                          depth: 0,
                          semanticLabel: l10n.billBadge,
                          child: Image.asset(
                            'assets/images/bill.png',
                            width: 65,
                            height: 65,
                            fit: BoxFit.contain,
                          ),
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
                  enabled: cordEnabled && !_dominoRunning,
                  haptics: haptics,
                  onPull: _runLightsOut,
                ),
              ),
            ),
            // FAB (§6.1) — 방에 등을 하나 더 놓는다.
            Positioned(
              right: UnwindSpacing.s20,
              bottom: UnwindSpacing.s8 + 70,
              child: SafeArea(
                child: Opacity(
                  opacity: asleep ? 0.55 : 1.0,
                  child: UnwindIconButton(
                    icon: Icons.add_rounded,
                    iconSize: 32,
                    size: 64,
                    style: UnwindIconButtonStyle.accent,
                    semanticLabel: l10n.addTaskLabel,
                    onPressed: () {
                      // 과거 날짜 열람 중엔 그 날짜로 추가
                      final viewed = ref.read(viewedDayKeyProvider);
                      final today = ref.read(todayKeyProvider);
                      showComposeSheet(
                        context,
                        initialDate: viewed != today ? viewed : null,
                      );
                    },
                  ),
                ),
              ),
            ),
            // 주간 뷰 오버레이 — 토글 + 영속 (§6.2 개정). 현재 진입점 없음.
            Positioned.fill(
              child: Consumer(
                builder: (context, ref, _) {
                  final weekOpen =
                      ref.watch(
                        settingsControllerProvider.select(
                          (s) => s.value?.weekViewOpen,
                        ),
                      ) ??
                      false;
                  return IgnorePointer(
                    ignoring: !weekOpen,
                    child: AnimatedSlide(
                      offset: weekOpen ? Offset.zero : const Offset(0, -1.1),
                      duration: const Duration(
                        milliseconds: UnwindMotion.weekExpandMs,
                      ),
                      curve: UnwindMotion.settle,
                      child: WeekScreen(
                        onCollapse: () => ref
                            .read(settingsControllerProvider.notifier)
                            .setWeekViewOpen(false),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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

/// 상단 행 — 설정 + 날짜 타이틀 + 미확인 청구서 배지
class _TopBar extends ConsumerWidget {
  final VoidCallback onSettings;
  final void Function(WeeklyBill) onBill;

  const _TopBar({required this.onSettings, required this.onBill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final viewedKey = ref.watch(viewedDayKeyProvider);
    final isPast = viewedKey != ref.watch(todayKeyProvider);
    final unread = ref.watch(unreadBillsProvider).value ?? const <WeeklyBill>[];

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

    return UnwindHeader(
      title: title,
      leadingIcon: Icons.settings_outlined,
      leadingLabel: l10n.settingsTitle,
      onLeading: onSettings,
      trailing: unread.isEmpty
          ? null
          : UnwindPressable(
              onTap: () => onBill(unread.first),
              depth: 0,
              semanticLabel: l10n.notifBillArrived,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: UnwindSpacing.s12,
                  vertical: UnwindSpacing.s8,
                ),
                // 배지는 코너 글로우가 가장 밝은 자리에 앉는다 —
                // 반투명 채움은 눈부신 배경에 묻히므로 불투명 앰버로.
                decoration: BoxDecoration(
                  color: UnwindColors.accent,
                  borderRadius: BorderRadius.circular(UnwindRadius.pill),
                ),
                child: Text(
                  l10n.billBadge,
                  style: UnwindType.label.copyWith(
                    color: UnwindColors.onAccent,
                  ),
                ),
              ),
            ),
    );
  }
}

/// §6.1 빈 상태 — 사과가 아니라 초대 (§8.5)
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
