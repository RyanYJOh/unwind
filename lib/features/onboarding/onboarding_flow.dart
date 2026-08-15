import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPicker, CupertinoTheme, CupertinoThemeData;
import 'package:flutter/material.dart' show Icons, Brightness;
import 'package:flutter/services.dart' show TextCapitalization;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/motion.dart';
import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../data/db/tables/tables.dart';
import '../../domain/models/lumi_state.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/ui.dart';
import '../../widgets/corner_glow.dart';
import '../../widgets/lumi/lumi_view.dart';
import '../settings/settings_controller.dart';
import '../today/providers.dart';
import '../today/today_screen.dart';

/// 유저 취침시각 → Lumi 취침시간 (세계관: Lumi는 3시간 먼저 잔다)
int lumiBedtimeFrom(int userSleepHour) => (userSleepHour - 3 + 24) % 24;

/// 유저 기상시각 → Lumi 기상시간 = 하루의 경계 (1시간 먼저 일어난다)
int lumiWakeFrom(int userWakeHour) => (userWakeHour - 1 + 24) % 24;

/// §6.6 온보딩 (전면 개편 2026-08-15) — 컨셉 소개 → 소등 체험 → 청구서 →
/// 질문(매일 항목·취침/기상·이름) → 인사. 계정 없음, 저장은 마지막에 한 번.
///
/// [preview]: 개발용 미리보기 (설정 > Onboarding (dev)) — 아무것도 저장하지
/// 않고 플로우만 체험한 뒤 pop.
class OnboardingFlow extends ConsumerStatefulWidget {
  final bool preview;

  const OnboardingFlow({super.key, this.preview = false});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  static const _pageCount = 11;

  final _pageCtrl = PageController();
  int _page = 0;

  // ── 답변 상태 (커밋은 마지막에 한 번) ──
  final List<String> _habits = [];
  int _userSleepHour = 23;
  int _userWakeHour = 7;
  final _nameCtrl = TextEditingController();

  /// 소등 체험 페이지가 보고하는 남은 빛 (1.0 = 전부 켜짐)
  double _lightsLight = 1.0;

  int get _lumiBedtime => lumiBedtimeFrom(_userSleepHour);
  int get _lumiWake => lumiWakeFrom(_userWakeHour);

  /// 페이지별 방의 빛 — 플로우가 하나의 CornerGlow를 계속 몰아
  /// 페이지 전환 때 빛이 자연스럽게 이어진다.
  double get _glowTarget => switch (_page) {
    0 => 0.55, // 환영 — 밝은 낮의 방
    1 => 1.0, // 눈부신 밤
    2 => _lightsLight, // 체험 — 끄는 만큼 어두워진다
    3 => 0.30,
    8 => 0.22,
    10 => 0.50,
    _ => 0.32,
  };

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    FocusManager.instance.primaryFocus?.unfocus();
    _pageCtrl.animateToPage(
      _page + 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    _pageCtrl.animateToPage(
      _page - 1,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  /// 이름 페이지의 CTA — 답변을 커밋하고(미리보기는 건너뜀) 인사 페이지로.
  /// onboardingCompleted 플래그는 아직 세우지 않는다 — 세우는 순간
  /// main.dart의 home이 바뀌어 인사가 잘린다.
  Future<void> _finishQuestions() async {
    if (!widget.preview) {
      final l10n = AppLocalizations.of(context);
      final ctrl = ref.read(settingsControllerProvider.notifier);
      await ctrl.setBedtimeHour(_lumiBedtime);
      await ctrl.setWakeHour(_lumiWake);
      final name = _nameCtrl.text.trim();
      if (name.isNotEmpty) await ctrl.setUserName(name);

      // 매일 항목 → 매일 반복 규칙 (없다고 했으면 디폴트 하나)
      final habits = _habits.isEmpty ? [l10n.obHabitsDefault] : _habits;
      final db = ref.read(databaseProvider);
      for (final title in habits) {
        await db.recurrenceDao.create(
          title: title,
          rule: RecurrenceRule.daily,
          // 기상시간이 방금 바뀌었을 수 있으니 오늘 키는 커밋 후에 읽는다
          startDate: ref.read(todayKeyProvider),
        );
      }
      await ref
          .read(recurrenceExpanderProvider)
          .expand(ref.read(todayKeyProvider));
    }
    if (mounted) _next(); // 인사 페이지로
  }

  /// 인사가 끝났다 — 진짜 오늘의 방으로.
  Future<void> _complete() async {
    if (widget.preview) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .setOnboardingCompleted();
    // §10 권한은 온보딩 종료 후에 요청한다 (첫 실행 즉시 요청 금지)
    await ref.read(notificationServiceProvider).requestPermission();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: UnwindMotion.pageMs),
        pageBuilder: (_, animation, secondary) =>
            FadeTransition(opacity: animation, child: const TodayScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    // 인사 페이지에선 뒤로가기·진행 바를 걷는다 — 마무리는 조용하게
    final chromeVisible = _page < _pageCount - 1;

    return UnwindScreen(
      safeArea: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _glowTarget),
                duration: Duration(milliseconds: reduce ? 0 : 700),
                curve: Curves.easeOut,
                builder: (context, light, _) => CornerGlow(light: light),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 상단 — 뒤로 + 진행 바. 높이를 고정해 페이지 전환 시
                // 레이아웃이 흔들리지 않는다.
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: _page > 0 && chromeVisible
                            ? UnwindIconButton(
                                icon: Icons.arrow_back_rounded,
                                semanticLabel: l10n.close,
                                onPressed: _back,
                              )
                            : null,
                      ),
                      Expanded(
                        child: chromeVisible
                            ? _ProgressBar(
                                fraction: (_page + 1) / _pageCount,
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (p) => setState(() => _page = p),
                    children: [
                      _WelcomePage(onNext: _next),
                      _NightPage(onNext: _next),
                      _LightsPage(
                        onNext: _next,
                        onLightChanged: (light) =>
                            setState(() => _lightsLight = light),
                      ),
                      _BillPage(onNext: _next),
                      _QuestionsIntroPage(onNext: _next),
                      _HabitsPage(
                        habits: _habits,
                        onChanged: () => setState(() {}),
                        onNext: _next,
                      ),
                      _HourQuestionPage(
                        title: l10n.obSleepQTitle,
                        body: l10n.obSleepQBody,
                        // 저녁 19시 ~ 새벽 4시
                        hours: const [19, 20, 21, 22, 23, 0, 1, 2, 3, 4],
                        value: _userSleepHour,
                        resultText: (h) =>
                            l10n.obSleepQResult(l10n.hourLabel(lumiBedtimeFrom(h))),
                        onChanged: (h) => setState(() => _userSleepHour = h),
                        onNext: _next,
                      ),
                      _HourQuestionPage(
                        title: l10n.obWakeQTitle,
                        body: l10n.obWakeQBody,
                        hours: const [4, 5, 6, 7, 8, 9, 10, 11, 12],
                        value: _userWakeHour,
                        resultText: (h) =>
                            l10n.obWakeQResult(l10n.hourLabel(lumiWakeFrom(h))),
                        onChanged: (h) => setState(() => _userWakeHour = h),
                        onNext: _next,
                      ),
                      _SchedulePage(
                        bedHour: _lumiBedtime,
                        wakeHour: _lumiWake,
                        onNext: _next,
                      ),
                      _NamePage(
                        controller: _nameCtrl,
                        onFinish: _finishQuestions,
                      ),
                      _GreetingPage(
                        name: _nameCtrl.text.trim(),
                        onDone: _complete,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 얇은 진행 바 — 페이지가 넘어갈 때 앰버가 차오른다.
class _ProgressBar extends StatelessWidget {
  final double fraction;

  const _ProgressBar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UnwindRadius.pill),
        child: SizedBox(
          height: 5,
          child: Stack(
            children: [
              const ColoredBox(
                color: UnwindColors.surfaceHigh,
                child: SizedBox.expand(),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(end: fraction.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                builder: (context, f, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: f,
                  child: const ColoredBox(
                    color: UnwindColors.accent,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 페이지 공통 뼈대.
/// [hero]가 있으면 위에 고정하고, [child]가 없으면 콘텐츠를 세로 중앙에 둔다.
class _ObPage extends StatelessWidget {
  final Widget? hero;
  final String title;
  final String? body;
  final Widget? content;
  final String cta;
  final bool ctaEnabled;
  final VoidCallback onCta;
  final Widget? secondary;

  const _ObPage({
    required this.title,
    required this.cta,
    required this.onCta,
    this.ctaEnabled = true,
    this.hero,
    this.body,
    this.content,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      textAlign: TextAlign.center,
      style: UnwindType.display.copyWith(color: UnwindColors.textPrimary),
    );
    final bodyText = body == null
        ? null
        : Text(
            body!,
            textAlign: TextAlign.center,
            style: UnwindType.body.copyWith(color: UnwindColors.textSecondary),
          );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          UnwindSpacing.s24,
          0,
          UnwindSpacing.s24,
          UnwindSpacing.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (content == null)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hero != null) ...[
                      hero!,
                      const SizedBox(height: UnwindSpacing.s24),
                    ],
                    titleText,
                    if (bodyText != null) ...[
                      const SizedBox(height: UnwindSpacing.s12),
                      bodyText,
                    ],
                  ],
                ),
              )
            else ...[
              ?hero,
              const SizedBox(height: UnwindSpacing.s8),
              titleText,
              if (bodyText != null) ...[
                const SizedBox(height: UnwindSpacing.s8),
                bodyText,
              ],
              const SizedBox(height: UnwindSpacing.s12),
              Expanded(child: content!),
            ],
            if (secondary != null) ...[
              secondary!,
              const SizedBox(height: UnwindSpacing.s4),
            ],
            UnwindButton(label: cta, onPressed: ctaEnabled ? onCta : null),
          ],
        ),
      ),
    );
  }
}

/// "다음"을 1초 뒤에 열어 주는 페이지들의 공용 훅.
mixin _DelayedCta<T extends StatefulWidget> on State<T> {
  bool ctaReady = false;
  Timer? _ctaTimer;

  void startCtaDelay() {
    _ctaTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => ctaReady = true);
    });
  }

  void disposeCtaDelay() => _ctaTimer?.cancel();
}

// ── 1. 환영 ─────────────────────────────────────────────────

class _WelcomePage extends StatefulWidget {
  final VoidCallback onNext;

  const _WelcomePage({required this.onNext});

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage> with _DelayedCta {
  int _pokeTick = 0;

  @override
  void initState() {
    super.initState();
    startCtaDelay();
    // 들어오고 한 박자 뒤에 스스로 까르르 — 반가움의 첫인사
    Timer(const Duration(milliseconds: 500), _poke);
  }

  void _poke() {
    if (mounted) setState(() => _pokeTick++);
  }

  @override
  void dispose() {
    disposeCtaDelay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ObPage(
      hero: UnwindPressable(
        onTap: _poke,
        depth: 0,
        pressScale: 1.0, // 반응은 캐릭터가 한다
        haptic: UnwindHapticKind.tap,
        isButton: false,
        semanticLabel: l10n.lumiPokeLabel,
        child: LumiView(
          state: LumiState(
            brightness: 0.1,
            mode: LumiMode.day,
            event: _pokeTick > 0 ? LumiEvent.poke : null,
            eventTick: _pokeTick,
          ),
          reduceMotion: MediaQuery.disableAnimationsOf(context),
          size: 210,
        ),
      ),
      title: l10n.obWelcomeTitle,
      body: l10n.obWelcomeBody,
      cta: l10n.obNext,
      ctaEnabled: ctaReady,
      onCta: widget.onNext,
    );
  }
}

// ── 2. 눈부신 밤 ────────────────────────────────────────────

class _NightPage extends StatefulWidget {
  final VoidCallback onNext;

  const _NightPage({required this.onNext});

  @override
  State<_NightPage> createState() => _NightPageState();
}

class _NightPageState extends State<_NightPage> with _DelayedCta {
  @override
  void initState() {
    super.initState();
    startCtaDelay();
  }

  @override
  void dispose() {
    disposeCtaDelay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 홈과 같은 문법: 위 Lumi, 아래 켜진 등들 (여기선 읽기 전용)
    return _ObPage(
      hero: SizedBox(
        height: 132,
        child: Center(
          child: LumiView(
            state: const LumiState(
              brightness: 0.0,
              mode: LumiMode.nightAwake,
              dazzle: 0.95, // 찡그림 + 하품
            ),
            reduceMotion: MediaQuery.disableAnimationsOf(context),
            size: 118,
          ),
        ),
      ),
      title: l10n.obNightTitle,
      body: l10n.obNightBody,
      content: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (final title in [l10n.obDummy1, l10n.obDummy2, l10n.obDummy3])
            UnwindTodoTile(
              title: title,
              isOn: true,
              readOnlySwitch: true,
              switchSemanticsOn: l10n.lampOn,
              switchSemanticsOff: l10n.lampOff,
            ),
        ],
      ),
      cta: l10n.obNext,
      ctaEnabled: ctaReady,
      onCta: widget.onNext,
    );
  }
}

// ── 3. 소등 체험 ────────────────────────────────────────────

class _LightsPage extends StatefulWidget {
  final VoidCallback onNext;
  final ValueChanged<double> onLightChanged;

  const _LightsPage({required this.onNext, required this.onLightChanged});

  @override
  State<_LightsPage> createState() => _LightsPageState();
}

class _LightsPageState extends State<_LightsPage> {
  final _done = [false, false, false];

  bool get _allDone => _done.every((d) => d);

  void _toggle(int i) {
    setState(() => _done[i] = !_done[i]);
    final remaining = _done.where((d) => !d).length;
    widget.onLightChanged(remaining / _done.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titles = [l10n.obDummy1, l10n.obDummy2, l10n.obDummy3];
    final checked = _done.where((d) => d).length;

    return _ObPage(
      hero: SizedBox(
        height: 132,
        child: Center(
          child: LumiView(
            state: _allDone
                ? const LumiState(
                    brightness: 1.0,
                    isAsleep: true,
                    mode: LumiMode.asleep,
                  )
                : LumiState(
                    brightness: checked / 3,
                    mode: LumiMode.nightAwake,
                    dazzle: (3 - checked) / 3,
                  ),
            reduceMotion: MediaQuery.disableAnimationsOf(context),
            size: 118,
          ),
        ),
      ),
      title: _allDone ? l10n.obLightsDone : l10n.obLightsTitle,
      body: _allDone ? null : l10n.obLightsBody,
      content: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (var i = 0; i < titles.length; i++)
            UnwindTodoTile(
              title: titles[i],
              isOn: !_done[i],
              isDone: _done[i],
              onToggle: () => _toggle(i),
              switchSemanticsOn: l10n.lampOn,
              switchSemanticsOff: l10n.lampOff,
            ),
        ],
      ),
      cta: l10n.obNext,
      // 반드시 전부 끄고 나서야 넘어갈 수 있다 (발주자 요구)
      ctaEnabled: _allDone,
      onCta: widget.onNext,
    );
  }
}

// ── 4. 청구서 ───────────────────────────────────────────────

class _BillPage extends StatefulWidget {
  final VoidCallback onNext;

  const _BillPage({required this.onNext});

  @override
  State<_BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<_BillPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _unroll = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  bool _opened = false;

  @override
  void dispose() {
    _unroll.dispose();
    super.dispose();
  }

  void _open() {
    if (_opened) return;
    setState(() => _opened = true);
    _unroll.forward();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ObPage(
      title: l10n.obBillTitle,
      body: l10n.obBillBody,
      content: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UnwindPressable(
                onTap: _open,
                depth: 0,
                haptic: UnwindHapticKind.tap,
                semanticLabel: l10n.billBadge,
                child: Image.asset(
                  'assets/images/bill.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                ),
              ),
              // 영수증이 청구서 아래에서 주르륵 인쇄되어 내려온다
              SizeTransition(
                sizeFactor: CurvedAnimation(
                  parent: _unroll,
                  curve: Curves.easeOutCubic,
                ),
                alignment: Alignment.topCenter,
                child: const Padding(
                  padding: EdgeInsets.only(top: UnwindSpacing.s8),
                  child: _MiniReceipt(),
                ),
              ),
            ],
          ),
        ),
      ),
      cta: l10n.obNext,
      // 청구서를 한 번 눌러 봐야 넘어간다 — 직접 만져 보는 온보딩
      ctaEnabled: _opened,
      onCta: widget.onNext,
    );
  }
}

/// 청구서 미리보기 영수증 — 밝은 종이는 영수증에만 허용된 예외 (§5.1).
/// 내용은 장식용 프리뷰다 (실데이터 아님).
class _MiniReceipt extends StatelessWidget {
  const _MiniReceipt();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const ink = Color(0xFF1E2430);
    return ClipPath(
      clipper: _ReceiptEdgeClipper(),
      child: Container(
        width: 230,
        color: const Color(0xFFFBF7EE),
        padding: const EdgeInsets.fromLTRB(
          UnwindSpacing.s16,
          UnwindSpacing.s16,
          UnwindSpacing.s16,
          UnwindSpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.billTitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: UnwindType.caption.copyWith(
                color: ink,
                fontVariations: const [FontVariation('wght', 800)],
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: UnwindSpacing.s8),
            Container(height: 1.5, color: ink.withValues(alpha: 0.14)),
            const SizedBox(height: UnwindSpacing.s8),
            Text(
              l10n.nightsOut(5),
              textAlign: TextAlign.center,
              style: UnwindType.caption.copyWith(
                color: ink.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: UnwindSpacing.s4),
            Text(
              '0.42 kWh',
              style: UnwindType.caption.copyWith(
                color: ink.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: UnwindSpacing.s8),
            Text(
              l10n.wonAmount('1,540'),
              style: UnwindType.title.copyWith(color: ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// 영수증 아랫단의 지그재그 절취선.
class _ReceiptEdgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const tooth = 10.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - tooth);
    final teeth = (size.width / tooth).floor();
    for (var i = teeth; i >= 0; i--) {
      final x = i * tooth;
      path.lineTo(x + tooth / 2, size.height);
      path.lineTo(x, size.height - tooth);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_ReceiptEdgeClipper old) => false;
}

// ── 5. 질문 인트로 ──────────────────────────────────────────

class _QuestionsIntroPage extends StatelessWidget {
  final VoidCallback onNext;

  const _QuestionsIntroPage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ObPage(
      hero: LumiView(
        state: const LumiState(brightness: 0.2, mode: LumiMode.day),
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        size: 150,
      ),
      title: l10n.obQuestionsTitle,
      body: l10n.obQuestionsBody,
      cta: l10n.obNext,
      onCta: onNext,
    );
  }
}

// ── 6. 질문 1: 매일 하는 일 ─────────────────────────────────

class _HabitsPage extends StatefulWidget {
  final List<String> habits;
  final VoidCallback onChanged;
  final VoidCallback onNext;

  const _HabitsPage({
    required this.habits,
    required this.onChanged,
    required this.onNext,
  });

  @override
  State<_HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<_HabitsPage> {
  final _fieldCtrl = TextEditingController();
  final _fieldFocus = FocusNode();

  @override
  void dispose() {
    _fieldCtrl.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _add() {
    final text = _fieldCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.habits.add(text);
      _fieldCtrl.clear();
    });
    widget.onChanged();
    _fieldFocus.requestFocus(); // 연속 입력
  }

  void _remove(int i) {
    setState(() => widget.habits.removeAt(i));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ObPage(
      title: l10n.obHabitsTitle,
      body: l10n.obHabitsBody,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: UnwindTextField(
                  controller: _fieldCtrl,
                  focusNode: _fieldFocus,
                  hint: l10n.obHabitsHint,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: UnwindSpacing.s8),
              UnwindIconButton(
                icon: Icons.add_rounded,
                style: UnwindIconButtonStyle.accent,
                semanticLabel: l10n.add,
                onPressed: _add,
              ),
            ],
          ),
          const SizedBox(height: UnwindSpacing.s12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < widget.habits.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: UnwindSpacing.s8),
                    child: UnwindCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: UnwindSpacing.s16,
                        vertical: UnwindSpacing.s8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: UnwindColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: UnwindSpacing.s12),
                          Expanded(
                            child: Text(
                              widget.habits[i],
                              style: UnwindType.bodyStrong.copyWith(
                                color: UnwindColors.textPrimary,
                              ),
                            ),
                          ),
                          UnwindIconButton(
                            icon: Icons.close_rounded,
                            iconSize: 18,
                            size: 36,
                            semanticLabel: l10n.delete,
                            onPressed: () => _remove(i),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      secondary: widget.habits.isEmpty
          ? UnwindButton.ghost(label: l10n.obHabitsNone, onPressed: widget.onNext)
          : null,
      cta: l10n.obNext,
      ctaEnabled: widget.habits.isNotEmpty,
      onCta: widget.onNext,
    );
  }
}

// ── 7·8. 질문 2·3: 시간 ────────────────────────────────────

class _HourQuestionPage extends StatelessWidget {
  final String title;
  final String body;
  final List<int> hours;
  final int value;
  final String Function(int hour) resultText;
  final ValueChanged<int> onChanged;
  final VoidCallback onNext;

  const _HourQuestionPage({
    required this.title,
    required this.body,
    required this.hours,
    required this.value,
    required this.resultText,
    required this.onChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final initial = hours.indexOf(value).clamp(0, hours.length - 1);
    return _ObPage(
      title: title,
      body: body,
      content: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 190,
                decoration: BoxDecoration(
                  color: UnwindColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(UnwindRadius.md),
                  border: Border.all(
                    color: UnwindColors.border,
                    width: UnwindStroke.base,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.dark,
                    primaryColor: UnwindColors.accent,
                  ),
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController: FixedExtentScrollController(
                      initialItem: initial,
                    ),
                    onSelectedItemChanged: (i) => onChanged(hours[i]),
                    children: [
                      for (final h in hours)
                        Center(
                          child: Text(
                            l10n.hourLabel(h),
                            style: UnwindType.bodyStrong.copyWith(
                              color: UnwindColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: UnwindSpacing.s16),
              // 답을 고르는 즉시 Lumi의 시간이 어떻게 정해지는지 보여준다
              Text(
                resultText(value),
                textAlign: TextAlign.center,
                style: UnwindType.label.copyWith(color: UnwindColors.accent),
              ),
            ],
          ),
        ),
      ),
      cta: l10n.obNext,
      onCta: onNext,
    );
  }
}

// ── 9. Lumi의 하루 (원형 타임테이블) ────────────────────────

class _SchedulePage extends StatelessWidget {
  final int bedHour;
  final int wakeHour;
  final VoidCallback onNext;

  const _SchedulePage({
    required this.bedHour,
    required this.wakeHour,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _ObPage(
      title: l10n.obScheduleTitle,
      body: l10n.obScheduleBody(
        l10n.hourLabel(bedHour),
        l10n.hourLabel(wakeHour),
      ),
      content: Center(
        child: _ScheduleRing(
          bedHour: bedHour,
          wakeHour: wakeHour,
          bedLabel: l10n.hourLabel(bedHour),
          wakeLabel: l10n.hourLabel(wakeHour),
        ),
      ),
      cta: l10n.obNext,
      onCta: onNext,
    );
  }
}

/// 24시간 원형 타임테이블 — 자정이 위. 자는 시간은 차분한 슬레이트,
/// 깨어 있는 시간은 앰버 호로 돌고, 한가운데에서 Lumi가 잔다.
class _ScheduleRing extends StatelessWidget {
  final int bedHour;
  final int wakeHour;
  final String bedLabel;
  final String wakeLabel;

  const _ScheduleRing({
    required this.bedHour,
    required this.wakeHour,
    required this.bedLabel,
    required this.wakeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1.0 : 0.0, end: 1.0),
      duration: Duration(milliseconds: reduce ? 0 : 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(260),
              painter: _ScheduleRingPainter(
                bedHour: bedHour,
                wakeHour: wakeHour,
                bedLabel: bedLabel,
                wakeLabel: wakeLabel,
                progress: t,
              ),
            ),
            Opacity(opacity: t, child: child),
          ],
        ),
      ),
      child: LumiView(
        state: const LumiState(
          brightness: 1.0,
          isAsleep: true,
          mode: LumiMode.asleep,
        ),
        reduceMotion: reduce,
        size: 96,
      ),
    );
  }
}

class _ScheduleRingPainter extends CustomPainter {
  final int bedHour;
  final int wakeHour;
  final String bedLabel;
  final String wakeLabel;
  final double progress;

  const _ScheduleRingPainter({
    required this.bedHour,
    required this.wakeHour,
    required this.bedLabel,
    required this.wakeLabel,
    required this.progress,
  });

  static double _angleOf(double hour) => -math.pi / 2 + hour / 24 * 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 30; // 라벨 자리를 남긴다
    const stroke = 16.0;

    // 바닥 링
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = UnwindColors.surfaceAlt
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final sleepLen = ((wakeHour - bedHour + 24) % 24) / 24 * 2 * math.pi;
    final awakeLen = 2 * math.pi - sleepLen;
    final bedAngle = _angleOf(bedHour.toDouble());
    final wakeAngle = _angleOf(wakeHour.toDouble());
    final rect = Rect.fromCircle(center: c, radius: r);

    // 자는 시간 — 차분한 슬레이트 호
    canvas.drawArc(
      rect,
      bedAngle,
      sleepLen * progress,
      false,
      Paint()
        ..color = UnwindColors.borderStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    // 깨어 있는 시간 — 앰버 호
    canvas.drawArc(
      rect,
      wakeAngle,
      awakeLen * progress,
      false,
      Paint()
        ..color = UnwindColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // 경계 점 + 시각 라벨 (링 바깥)
    for (final (angle, label) in [(bedAngle, bedLabel), (wakeAngle, wakeLabel)]) {
      final p = c + Offset(math.cos(angle), math.sin(angle)) * r;
      canvas.drawCircle(p, 5.5, Paint()..color = UnwindColors.textPrimary);
      canvas.drawCircle(
        p,
        5.5,
        Paint()
          ..color = UnwindColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: UnwindType.caption.copyWith(
            color: UnwindColors.textPrimary,
            fontVariations: const [FontVariation('wght', 800)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelC = c + Offset(math.cos(angle), math.sin(angle)) * (r + 22);
      tp.paint(
        canvas,
        labelC - Offset(tp.width / 2, tp.height / 2),
      );
    }

    // 자는 구간 한가운데의 달, 깨어 있는 구간 한가운데의 해
    final moonAngle = bedAngle + sleepLen / 2;
    final sunAngle = wakeAngle + awakeLen / 2;
    _paintMoon(
      canvas,
      c + Offset(math.cos(moonAngle), math.sin(moonAngle)) * (r - 30),
    );
    _paintSun(
      canvas,
      c + Offset(math.cos(sunAngle), math.sin(sunAngle)) * (r - 30),
    );
  }

  void _paintMoon(Canvas canvas, Offset p) {
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: p, radius: 7)),
      Path()..addOval(Rect.fromCircle(center: p.translate(4, -2), radius: 6)),
    );
    canvas.drawPath(moon, Paint()..color = UnwindColors.textSecondary);
  }

  void _paintSun(Canvas canvas, Offset p) {
    canvas.drawCircle(p, 5, Paint()..color = UnwindColors.accent);
    final ray = Paint()
      ..color = UnwindColors.accent
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(p + dir * 7.5, p + dir * 10.5, ray);
    }
  }

  @override
  bool shouldRepaint(_ScheduleRingPainter old) =>
      old.bedHour != bedHour ||
      old.wakeHour != wakeHour ||
      old.progress != progress;
}

// ── 10. 이름 ────────────────────────────────────────────────

class _NamePage extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onFinish;

  const _NamePage({required this.controller, required this.onFinish});

  @override
  State<_NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<_NamePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasName = widget.controller.text.trim().isNotEmpty;
    return _ObPage(
      hero: LumiView(
        state: const LumiState(brightness: 0.2, mode: LumiMode.day),
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        size: 130,
      ),
      title: l10n.obNameTitle,
      content: Center(
        child: SingleChildScrollView(
          child: UnwindTextField(
            controller: widget.controller,
            hint: l10n.obNameHint,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) {
              if (widget.controller.text.trim().isNotEmpty) widget.onFinish();
            },
          ),
        ),
      ),
      secondary: hasName
          ? null
          : UnwindButton.ghost(
              label: l10n.obSkip,
              onPressed: () {
                widget.controller.clear();
                widget.onFinish();
              },
            ),
      cta: l10n.obBegin,
      ctaEnabled: hasName,
      onCta: widget.onFinish,
    );
  }
}

// ── 11. 인사 ────────────────────────────────────────────────

class _GreetingPage extends StatefulWidget {
  final String name;
  final VoidCallback onDone;

  const _GreetingPage({required this.name, required this.onDone});

  @override
  State<_GreetingPage> createState() => _GreetingPageState();
}

class _GreetingPageState extends State<_GreetingPage> {
  int _pokeTick = 0;
  Timer? _joyTimer;
  Timer? _doneTimer;
  bool _started = false;

  /// PageView가 페이지를 미리 만들 수 있으므로, 화면에 실제로 나타났을 때
  /// 타이머를 건다 — build에서 첫 노출을 감지한다.
  void _start() {
    if (_started) return;
    _started = true;
    _joyTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _pokeTick++);
    });
    _doneTimer = Timer(const Duration(milliseconds: 2100), widget.onDone);
  }

  @override
  void dispose() {
    _joyTimer?.cancel();
    _doneTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _start();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(UnwindSpacing.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LumiView(
            state: LumiState(
              brightness: 0.1,
              mode: LumiMode.day,
              event: _pokeTick > 0 ? LumiEvent.poke : null,
              eventTick: _pokeTick,
            ),
            reduceMotion: MediaQuery.disableAnimationsOf(context),
            size: 210,
          ),
          const SizedBox(height: UnwindSpacing.s24),
          Text(
            widget.name.isEmpty
                ? l10n.obGreetingNoName
                : l10n.obGreeting(widget.name),
            textAlign: TextAlign.center,
            style: UnwindType.display.copyWith(color: UnwindColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
