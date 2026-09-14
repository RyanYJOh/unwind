import 'dart:math' as math;

import 'package:flutter/material.dart'
    show Icons, MaterialLocalizations, TimeOfDay;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics.dart';
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

    String? repeatType;
    final recurrenceId = todo.recurrenceId;
    if (recurrenceId != null) {
      final db = ref.read(databaseProvider);
      final rec = await (db.select(db.recurrences)
            ..where((r) => r.id.equals(recurrenceId)))
          .getSingleOrNull();
      repeatType = rec?.rule.name;
    }
    ToddAnalytics.track(
      'Click toggle-to-do',
      ToddAnalytics.todoEventProps(
        title: todo.title,
        targetDateKey: todo.date,
        hasMemo: todo.memo != null && todo.memo!.isNotEmpty,
        isAutoPostpone: todo.recurrenceId == null && todo.autoDefer,
        repeatType: repeatType,
        scheduledTimeMinutes: todo.scheduledTimeMinutes,
      ),
    );
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

  /// 지난주 청구서를 연다 — 요일 무관 (정책 개정 2026-08-28, 월요일
  /// 게이트 폐지. 발송 알림은 여전히 월요일 09:00 하나다).
  Future<void> _openBill() async {
    final todayKey = ref.read(todayKeyProvider);
    ToddAnalytics.track('Click weekly-bill');
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
    ToddAnalytics.track('Click pull-light-string', {
      'target_date': ToddAnalytics.isoDate(todayKey),
    });

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

  // ── 편집 모드 (2026-09-14) ─────────────────────────────────
  // 아이폰 홈 화면처럼: 롱프레스하면 모든 등이 달달 떨고, 좌상단 ✕와 우측
  // 손잡이가 생긴다. 시간 없는 항목은 롱프레스한 채로 곧장 끌어 옮길 수 있다.
  // 끝내는 법: 하단 "완료" / 빈 곳 탭 / 다른 날짜·화면으로 이동 / 마지막 삭제.
  bool _editing = false;

  /// 끌어 놓은 직후의 낙관적 순서 (시간 없는 항목 id). DB 스트림이 같은
  /// 순서를 돌려주면 걷는다 — 없으면 놓는 순간 옛 자리로 튀었다가 돌아온다.
  List<String>? _localOrder;

  void _enterEdit() {
    if (_editing || _dominoRunning) return;
    setState(() => _editing = true);
  }

  void _exitEdit() {
    if (!_editing) return;
    setState(() => _editing = false);
  }

  /// [_localOrder]를 입힌다. 모르는 항목(방금 추가된 것)은 원래 순서대로 뒤에.
  List<Todo> _applyLocalOrder(List<Todo> untimed) {
    final order = _localOrder;
    if (order == null) return untimed;
    final byId = {for (final t in untimed) t.id: t};
    final placed = [for (final id in order) ?byId[id]];
    final placedIds = {for (final t in placed) t.id};
    return [
      ...placed,
      for (final t in untimed)
        if (!placedIds.contains(t.id)) t,
    ];
  }

  /// [newIndex]는 옮긴 뒤의 자리 (onReorderItem 규약 — 뺀 자리를 이미 반영).
  Future<void> _reorder(List<Todo> untimed, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final next = [...untimed];
    next.insert(newIndex, next.removeAt(oldIndex));
    setState(() => _localOrder = [for (final t in next) t.id]);
    await ref.read(todoRepositoryProvider).reorder(next);
  }

  /// 손에 들린 타일 — 살짝 커지고 떨림을 멈춘다 (블러 그림자 없이, §11).
  Widget _dragProxy(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: UnwindJiggle.still(child: child),
      builder: (context, child) => Transform.scale(
        scale: 1 + 0.03 * Curves.easeOut.transform(animation.value),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 열람 날짜의 방 (개편 2026-08-09) — 기본은 오늘
    final todos = ref.watch(viewedTodosProvider).value ?? const <Todo>[];
    // 순서 변경 (2026-09-14) — 시간 지정 항목은 시간순으로 앞에 고정되고,
    // 시간 없는 항목만 옮길 수 있다 (DAO 정렬과 같은 규칙).
    final timed = [
      for (final t in todos)
        if (t.scheduledTimeMinutes != null) t,
    ];
    final untimed = _applyLocalOrder([
      for (final t in todos)
        if (t.scheduledTimeMinutes == null) t,
    ]);

    // 다른 날짜로 가면 편집을 끝낸다 — 그 방의 목록은 다른 목록이다
    ref.listen<String>(viewedDayKeyProvider, (prev, next) {
      if (prev == next) return;
      _localOrder = null;
      _exitEdit();
    });
    // DB가 끌어 놓은 순서를 따라잡으면 낙관적 순서를 걷는다.
    // 마지막 항목을 지우면 편집할 것이 없으니 편집도 끝낸다.
    ref.listen<AsyncValue<List<Todo>>>(viewedTodosProvider, (prev, next) {
      final list = next.value;
      if (list == null) return;
      final order = _localOrder;
      if (order != null) {
        final ids = [
          for (final t in list)
            if (t.scheduledTimeMinutes == null) t.id,
        ];
        var caughtUp = ids.length == order.length;
        for (var i = 0; caughtUp && i < ids.length; i++) {
          caughtUp = ids[i] == order[i];
        }
        if (caughtUp) setState(() => _localOrder = null);
      }
      if (list.isEmpty) _exitEdit();
    });
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
                      // 홈은 헤더·Todd·체크리스트가 **한 덩어리로** 스크롤된다
                      // (개정 2026-09-14 — 이전엔 리스트만 스크롤). 고정은
                      // 하단 주 칩·스트립, 그리고 우상단 전등 줄(아래 Stack의
                      // 형제라 스크롤 밖에 있다)뿐이다.
                      Expanded(
                        // 편집 모드에서 빈 곳을 탭하면 편집이 끝난다 (아이폰
                        // 홈 화면). 타일·버튼의 탭은 더 안쪽이 먼저 가져간다.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          excludeFromSemantics: true,
                          onTap: _editing ? _exitEdit : null,
                          child: CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: _TopBar(
                                  // 다른 화면으로 가면 편집 모드를 끝낸다
                                  onSettings: () {
                                    _exitEdit();
                                    showSettingsScreen(context);
                                  },
                                  onBill: () {
                                    _exitEdit();
                                    _openBill();
                                  },
                                ),
                              ),
                              // 유령 영역 — 고정 높이로 체크리스트와의 간격 축소.
                              // 오늘: Todd (탭하면 반응, 잠들었을 땐 무반응).
                              // 과거·미래: Todd는 오늘의 방에 있다 — 빈 자리만.
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 136,
                                  child: !isViewingToday
                                      ? _ToddAway(label: l10n.toddAway)
                                      : _buildTodd(l10n, toddMode, reduce),
                                ),
                              ),
                              if (todos.isEmpty)
                                // 빈 방 문구는 Todd 아래 남은 화면의 가운데 —
                                // 스크롤 전과 같은 자리
                                const SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: _EmptyRoom(),
                                )
                              else ...[
                                // 시간 지정 항목 — 시간순으로 놓이므로 옮길 수 없다
                                SliverPadding(
                                  padding: const EdgeInsets.only(
                                    top: UnwindSpacing.s4,
                                  ),
                                  sliver: SliverList.builder(
                                    itemCount: timed.length,
                                    itemBuilder: (context, i) => _buildRow(
                                      context,
                                      l10n,
                                      timed[i],
                                      asleep,
                                      seed: i,
                                    ),
                                  ),
                                ),
                                // 시간 없는 항목 — 롱프레스한 채로, 또는 편집 모드
                                // 손잡이로 순서를 바꾼다. 따로 두어야 끌던 항목이
                                // 시간 지정 항목 사이로 들어갔다 튕겨 나오지 않는다.
                                SliverPadding(
                                  padding: const EdgeInsets.only(
                                    bottom: UnwindSpacing.s16,
                                  ),
                                  sliver: SliverReorderableList(
                                    itemCount: untimed.length,
                                    proxyDecorator: _dragProxy,
                                    onReorderStart: (_) {
                                      haptics.medium(); // 들어 올림
                                      _enterEdit();
                                    },
                                    onReorderEnd: (_) => haptics.light(),
                                    onReorderItem: (from, to) =>
                                        _reorder(untimed, from, to),
                                    itemBuilder: (context, i) => _buildRow(
                                      context,
                                      l10n,
                                      untimed[i],
                                      asleep,
                                      seed: timed.length + i,
                                      untimed: untimed,
                                      reorderIndex: i,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
                                _WeekPill(onOpen: _exitEdit),
                                const Spacer(),
                                // 편집 모드면 FAB 자리가 "완료" — 엄지가 닿는
                                // 자리에서 끝낸다 (2026-09-14)
                                AnimatedSwitcher(
                                  duration: Duration(
                                    milliseconds: reduce ? 0 : 200,
                                  ),
                                  child: _editing
                                      ? UnwindButton(
                                          key: const ValueKey('edit-done'),
                                          label: l10n.editDone,
                                          icon: Icons.check_rounded,
                                          expand: false,
                                          onPressed: _exitEdit,
                                        )
                                      : Opacity(
                                        key: const ValueKey('fab'),
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
                      // 편집 중엔 전등 줄도 쉰다 — 떨리는 방을 소등하면 헷갈린다
                      enabled: cordEnabled && !_dominoRunning && !_editing,
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

  /// 오늘의 Todd — 탭하면 반응 (잠들었을 땐 무반응, [_pokeTodd]).
  Widget _buildTodd(
    AppLocalizations l10n,
    ToddModeState toddMode,
    bool reduce,
  ) {
    return Center(
      child: UnwindPressable(
        onTap: _pokeTodd,
        depth: 0,
        pressScale: 1.0, // 반응은 캐릭터가 한다
        haptic: UnwindHapticKind.none, // _pokeTodd가 고른다
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
                  // 시각 무관: 전부 체크 시 잠들고, 밤의 빈 방도 잠든다
                  isAsleep: toddMode.mode == ToddMode.asleep,
                  mode: toddMode.mode,
                  activity: toddMode.activity,
                  dazzle: toddMode.dazzle,
                  // 전날 불을 남겼으면 눈 밑에 다크서클
                  darkCircles: ref.watch(darkCirclesProvider),
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
    );
  }

  /// 할 일 한 줄. [untimed]·[reorderIndex]를 주면 순서를 옮길 수 있는 항목
  /// (시간 없는 항목 — SliverReorderableList 안)이다. [seed]는 떨림 박자.
  Widget _buildRow(
    BuildContext context,
    AppLocalizations l10n,
    Todo todo,
    bool asleep, {
    required int seed,
    List<Todo>? untimed,
    int? reorderIndex,
  }) {
    final isOn =
        todo.status == TodoStatus.pending &&
        !_visualOffOverride.contains(todo.id);
    final reorderable = untimed != null && reorderIndex != null;

    // 편집 모드의 손잡이 — 누르는 즉시 끌린다. 스크린 리더는 위·아래 동작으로.
    Widget? handle;
    if (reorderable && _editing) {
      final i = reorderIndex;
      handle = ReorderableDragStartListener(
        index: i,
        child: UnwindDragHandle(
          semanticLabel: l10n.reorderTaskLabel(todo.title),
          moveUpLabel: l10n.moveUp,
          moveDownLabel: l10n.moveDown,
          onMoveUp: i > 0 ? () => _reorder(untimed, i, i - 1) : null,
          onMoveDown: i < untimed.length - 1
              ? () => _reorder(untimed, i, i + 1)
              : null,
        ),
      );
    }

    Widget row = Dismissible(
      key: ValueKey(todo.id),
      // 편집 중엔 스와이프를 멈춘다 — 삭제는 ✕가 맡는다
      direction: _dominoRunning || _editing
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
      child: UnwindJiggle(
        active: _editing,
        seed: seed,
        child: UnwindTodoTile(
          title: todo.title,
          hasMemo: (todo.memo ?? '').trim().isNotEmpty,
          hasRepeat: todo.recurrenceId != null,
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
          // 롱프레스 = 편집 모드 (2026-09-14). 옮길 수 있는 항목은 바깥의
          // 끌기 리스너가 롱프레스를 받아 들어 올리면서 편집 모드를 켠다.
          onLongPress: _dominoRunning || reorderable ? null : _enterEdit,
          longPressHaptic: UnwindHapticKind.lift,
          editing: _editing,
          onRemove: () => _delete(todo, confirmSingle: true),
          removeSemanticsLabel: l10n.removeTaskLabel(todo.title),
          reorderHandle: handle,
          fixedOrderSemanticsLabel: l10n.orderFixedByTime,
        ),
      ),
    );

    // 스크린 리더는 롱프레스로 끌 수 없다 — 편집 모드로 가는 동작을 준다 (§12)
    row = Semantics(
      customSemanticsActions: {
        if (!_editing && !_dominoRunning)
          CustomSemanticsAction(label: l10n.editListAction): _enterEdit,
      },
      child: row,
    );

    if (!reorderable) return row;
    // 롱프레스한 채 곧장 끌기 — 아이폰 홈 화면처럼 편집 모드가 아니어도 된다
    // (들어 올리는 순간 onReorderStart가 편집 모드를 켠다)
    return ReorderableDelayedDragStartListener(
      key: ValueKey('reorder-${todo.id}'),
      index: reorderIndex,
      enabled: !_dominoRunning,
      child: row,
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
    // 청구서는 매일 열람 가능 (정책 개정 2026-08-28) — 미확인 점도 요일 무관
    final hasUnread = unread.any((b) => b.weekStart == lastMonday);

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
  /// 주간 뷰를 열기 직전 — 홈 편집 모드를 끝낸다 (2026-09-14)
  final VoidCallback onOpen;

  const _WeekPill({required this.onOpen});

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
      onTap: () {
        onOpen();
        showWeekScreen(context, mondayKey: mondayKey);
      },
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
