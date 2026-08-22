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
import '../../domain/models/todd_state.dart';
import '../../domain/services/bill_money.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/ui.dart';
import '../../widgets/corner_glow.dart';
import '../../widgets/todd/todd_view.dart';
import '../settings/settings_controller.dart';
import '../today/providers.dart';
import '../today/today_screen.dart';

/// 유저 취침시각 → Todd 취침시간 (세계관: Todd는 3시간 먼저 잔다)
int toddBedtimeFrom(int userSleepHour) => (userSleepHour - 3 + 24) % 24;

/// 유저 기상시각 → Todd 기상시간 = 하루의 경계 (1시간 먼저 일어난다)
int toddWakeFrom(int userWakeHour) => (userWakeHour - 1 + 24) % 24;

/// §6.6 온보딩 (전면 개편 2026-08-15) — 컨셉 소개 → 소등 체험 → 청구서 →
/// 질문(매일 항목·취침/기상·이름) → 인사 → 위젯 안내. 계정 없음, 저장은
/// 이름 직후 한 번 (플래그는 Got it 때).
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
  static const _greetingPage = 9;

  final _pageCtrl = PageController();
  int _page = 0;

  // ── 답변 상태 (커밋은 마지막에 한 번) ──
  final List<String> _habits = [];
  int _userSleepHour = 23;
  int _userWakeHour = 7;
  final _nameCtrl = TextEditingController();

  /// 소등 체험 페이지가 보고하는 남은 빛 (1.0 = 전부 켜짐)
  double _lightsLight = 1.0;

  /// 첫 페이지에서 Todd를 깨웠는가 — 깨어나는 순간 어둠에 새벽빛이 스민다
  bool _helloAwake = false;

  // 인사 페이지 연출 — 페이지가 실제로 나타났을 때 플로우가 타이머를 건다.
  // (페이지 위젯 안에 두면 PageView가 미리 빌드하는 순간 발동할 수 있다)
  int _greetTick = 0;
  Timer? _greetJoy;
  Timer? _greetPermission;
  Timer? _greetDone;
  Future<bool>? _permissionRequest;

  int get _toddBedtime => toddBedtimeFrom(_userSleepHour);
  int get _toddWake => toddWakeFrom(_userWakeHour);

  /// 페이지별 방의 빛 — 플로우가 하나의 CornerGlow를 계속 몰아
  /// 페이지 전환 때 빛이 자연스럽게 이어진다.
  double get _glowTarget => switch (_page) {
    // 첫인사 — 조명 없는 밤 (발주자 요구 2026-08-22). Todd를 깨우면
    // 새벽처럼 은은한 빛이 함께 밝아 온다.
    0 => _helloAwake ? 0.25 : 0.0,
    1 => _lightsLight, // 눈부신 밤 + 소등 체험 — 끄는 만큼 어두워진다
    2 => 0.30,
    7 => 0.22,
    9 => 0.50,
    10 => 0.40,
    _ => 0.32,
  };

  @override
  void dispose() {
    _greetJoy?.cancel();
    _greetPermission?.cancel();
    _greetDone?.cancel();
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int p) {
    setState(() => _page = p);
    if (p == _greetingPage) {
      // 인사: 한 박자 뒤 까르르 → 0.5초 뒤 권한 → 위젯 안내로
      _greetJoy?.cancel();
      _greetPermission?.cancel();
      _greetDone?.cancel();
      _greetJoy = Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _greetTick++);
      });
      if (!widget.preview) {
        _greetPermission = Timer(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          _permissionRequest ??=
              ref.read(notificationServiceProvider).requestPermission();
        });
      }
      _greetDone = Timer(const Duration(milliseconds: 2100), () {
        if (mounted && _page == _greetingPage) _next();
      });
    }
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
      await ctrl.setBedtimeHour(_toddBedtime);
      await ctrl.setWakeHour(_toddWake);
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
      // 위젯 안내 페이지에서 올리기 전에 스냅샷이 디스크에 있어야 한다
      await flushWidgetSnapshot(ref);
    }
    if (mounted) _next(); // 인사 페이지로
  }

  /// 위젯 안내를 닫았다 — 진짜 오늘의 방으로.
  Future<void> _complete() async {
    if (widget.preview) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // 권한은 인사 화면 도착 0.5초 뒤에 이미 띄웠다. 다이얼로그가
    // 아직 떠 있으면 홈으로 넘어가기 전에 답을 기다린다 — 플래그를
    // 먼저 세우면 main.dart의 home이 바뀌어 인사가 잘린다.
    await _permissionRequest;
    if (!mounted) return;
    await ref
        .read(settingsControllerProvider.notifier)
        .setOnboardingCompleted();
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
    // 인사·위젯 안내에선 뒤로가기·진행 바를 걷는다 — 마무리는 조용하게
    final chromeVisible = _page < _greetingPage;

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
                    onPageChanged: _onPageChanged,
                    children: [
                      _WelcomePage(
                        onNext: _next,
                        onWoke: () => setState(() => _helloAwake = true),
                      ),
                      // 눈부신 밤 + 소등 체험 (병합 2026-08-15 2차) —
                      // 안내만 하는 페이지 없이 바로 스위치를 만져 본다
                      _LightsPage(
                        onNext: _next,
                        onLightChanged: (light) =>
                            setState(() => _lightsLight = light),
                      ),
                      _BillPage(onNext: _next),
                      _QuestionsIntroPage(onNext: _next),
                      _HabitsPage(
                        habits: _habits,
                        autofocus: _page == 4,
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
                            l10n.obSleepQResult(l10n.hourLabel(toddBedtimeFrom(h))),
                        onChanged: (h) => setState(() => _userSleepHour = h),
                        onNext: _next,
                      ),
                      _HourQuestionPage(
                        title: l10n.obWakeQTitle,
                        body: l10n.obWakeQBody,
                        hours: const [4, 5, 6, 7, 8, 9, 10, 11, 12],
                        value: _userWakeHour,
                        resultText: (h) =>
                            l10n.obWakeQResult(l10n.hourLabel(toddWakeFrom(h))),
                        onChanged: (h) => setState(() => _userWakeHour = h),
                        onNext: _next,
                      ),
                      _SchedulePage(
                        bedHour: _toddBedtime,
                        wakeHour: _toddWake,
                        onNext: _next,
                      ),
                      _NamePage(
                        controller: _nameCtrl,
                        autofocus: _page == 8,
                        onFinish: _finishQuestions,
                      ),
                      _GreetingPage(
                        name: _nameCtrl.text.trim(),
                        pokeTick: _greetTick,
                      ),
                      _WidgetPage(onDone: _complete),
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
class _ObPage extends StatefulWidget {
  final Widget? hero;
  final String title;
  final String? body;
  final Widget? content;
  final String cta;
  final bool ctaEnabled;
  final VoidCallback onCta;
  final Widget? secondary;

  /// 콘텐츠가 페이지 좌우 여백 없이 전체 폭을 쓴다 — 홈과 같은 폭의
  /// 할 일 타일처럼, 자기 여백을 가진 콘텐츠용 (개정 2026-08-15 2차).
  final bool fullBleedContent;

  /// hero → 제목 간격 (content가 있을 때만). 위젯 안내처럼 히어로가
  /// 크면 기본 s8은 붙어 보인다.
  final double heroGap;

  /// body → content 간격
  final double afterBodyGap;

  /// 제목·본문을 타이프라이터로 친다 (개편 2026-08-22 — 초반 페이지 전용,
  /// 청구서 페이지부터는 정적). 본문은 제목이 다 나온 뒤에 시작하고,
  /// 문장이 바뀌면 같은 자리에서 처음부터 다시 친다.
  final bool typewriter;

  /// 타이프라이터 제목이 한 글자 나올 때마다 (지금까지 보인 문자열).
  final ValueChanged<String>? onTitleAdvance;

  /// 타이프라이터 제목이 끝났을 때.
  final VoidCallback? onTitleTyped;

  const _ObPage({
    required this.title,
    required this.cta,
    required this.onCta,
    this.ctaEnabled = true,
    this.hero,
    this.body,
    this.content,
    this.secondary,
    this.fullBleedContent = false,
    this.heroGap = UnwindSpacing.s8,
    this.afterBodyGap = UnwindSpacing.s16,
    this.typewriter = false,
    this.onTitleAdvance,
    this.onTitleTyped,
  });

  @override
  State<_ObPage> createState() => _ObPageState();
}

class _ObPageState extends State<_ObPage> {
  static const _hPad = EdgeInsets.symmetric(horizontal: UnwindSpacing.s24);

  /// 제목 타이핑이 끝났는가 — 본문은 그 다음에 친다.
  bool _titleTyped = false;

  @override
  void didUpdateWidget(_ObPage old) {
    super.didUpdateWidget(old);
    if (widget.typewriter && widget.title != old.title) {
      _titleTyped = false; // 대사가 바뀌었다 — 본문도 제목을 다시 기다린다
    }
  }

  void _onTitleDone() {
    if (mounted && !_titleTyped) setState(() => _titleTyped = true);
    widget.onTitleTyped?.call();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = UnwindType.display.copyWith(
      color: UnwindColors.textPrimary,
      height: 1.22, // 기본 display 1.15에서 아주 살짝
    );
    final bodyStyle = UnwindType.body.copyWith(
      color: UnwindColors.textSecondary,
      height: 1.55, // 기본 body 1.45에서 아주 살짝
    );
    final titleText = Padding(
      padding: _hPad,
      child: widget.typewriter
          ? UnwindTypewriterText(
              widget.title,
              textAlign: TextAlign.center,
              style: titleStyle,
              onAdvance: widget.onTitleAdvance,
              onDone: _onTitleDone,
            )
          : Text(
              widget.title,
              textAlign: TextAlign.center,
              style: titleStyle,
            ),
    );
    final body = widget.body;
    final bodyText = body == null
        ? null
        : Padding(
            padding: _hPad,
            child: !widget.typewriter
                ? Text(body, textAlign: TextAlign.center, style: bodyStyle)
                : _titleTyped
                ? UnwindTypewriterText(
                    body,
                    textAlign: TextAlign.center,
                    style: bodyStyle,
                  )
                // 제목이 끝나기 전엔 투명하게 자리만 잡는다 — CTA가 안 밀리게
                : Opacity(
                    opacity: 0,
                    child: Text(
                      body,
                      textAlign: TextAlign.center,
                      style: bodyStyle,
                    ),
                  ),
          );

    final content = widget.content;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (content == null)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.hero != null) ...[
                    Center(child: widget.hero),
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
            // 진행 바에 제목이 붙지 않게 위를 비운다 (개정 2026-08-15 2차)
            const SizedBox(height: UnwindSpacing.s20),
            // 바깥 Column이 stretch라 hero를 그대로 두면 가로로 늘어나
            // CustomPaint가 화면 폭 기준으로 그려진다 — Center로 감싼다
            if (widget.hero != null) Center(child: widget.hero),
            SizedBox(height: widget.heroGap),
            titleText,
            if (bodyText != null) ...[
              const SizedBox(height: UnwindSpacing.s12),
              bodyText,
            ],
            SizedBox(height: widget.afterBodyGap),
            Expanded(
              child: widget.fullBleedContent
                  ? content
                  : Padding(padding: _hPad, child: content),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              UnwindSpacing.s24,
              0,
              UnwindSpacing.s24,
              UnwindSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.secondary != null) ...[
                  widget.secondary!,
                  const SizedBox(height: UnwindSpacing.s4),
                ],
                UnwindButton(
                  label: widget.cta,
                  onPressed: widget.ctaEnabled ? widget.onCta : null,
                ),
              ],
            ),
          ),
        ],
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

// ── 1. 첫인사 — 잠꾸러기 토드 깨우기 (전면 개편 2026-08-22) ──

/// 첫 만남의 각본: 어두운 밤, Todd가 반갑게 "Hi, I'm To..d.." 인사하다
/// **말끝을 흐리며 잠들어 버린다**. 토스트가 "톡톡 깨워 보라"고 알려 주고,
/// 유저가 세 번 두드리면 — 두 번은 실눈만 겨우 떴다 도로 잠들고 — 마침내
/// 기지개를 켜며 깨어나 "Oh hey! I'm Todd" 하고 다시 인사한다.
/// Todd가 잠이 많다는 세계관을 첫 화면에서 **손으로 배우는** 페이지.
class _WelcomePage extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  /// Todd가 깨어났다 — 플로우가 새벽빛(CornerGlow)을 올린다.
  final VoidCallback onWoke;

  const _WelcomePage({required this.onNext, required this.onWoke});

  @override
  ConsumerState<_WelcomePage> createState() => _WelcomePageState();
}

/// greet(인사 타이핑) → dozing(말끝이 흐려지며 꾸벅꾸벅) → asleep(잠듦) →
/// stir(톡 — 실눈 두리번) ⇄ asleep → awake(세 번째 톡 — 기상)
enum _HelloPhase { greet, dozing, asleep, stir, awake }

class _WelcomePageState extends ConsumerState<_WelcomePage> {
  /// 실눈 두리번(렌더러 peek 2.2초)과 동기 — 두 번째 톡은 못 이기고
  /// 조금 더 꾸벅거리다 잠든다.
  static const _stirBackMs = 2450;
  static const _stirLingerMs = 3200;

  _HelloPhase _phase = _HelloPhase.greet;
  int _pokes = 0;
  ToddEvent? _event;
  int _tick = 0;
  Timer? _sleepTimer;
  Timer? _toastTimer;
  Timer? _stirTimer;

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _toastTimer?.cancel();
    _stirTimer?.cancel();
    super.dispose();
  }

  /// 제목의 첫 `.`이 찍히는 순간 — 인사가 끝나기도 전에 눈이 감기기 시작한다.
  void _onTitleAdvance(String shown) {
    if (_phase == _HelloPhase.greet && shown.endsWith('.')) {
      setState(() => _phase = _HelloPhase.dozing);
    }
  }

  /// 말끝이 다 흐려졌다 — 한 박자 뒤 완전히 잠들고, 토스트로 깨우는 법을 알린다.
  void _onTitleTyped() {
    if (_phase != _HelloPhase.greet && _phase != _HelloPhase.dozing) return;
    _sleepTimer = Timer(const Duration(milliseconds: 550), () {
      if (!mounted || _phase == _HelloPhase.awake) return;
      setState(() {
        _phase = _HelloPhase.asleep;
        _event = null;
      });
      _scheduleToast(const Duration(milliseconds: 900));
    });
  }

  void _scheduleToast(Duration after) {
    _toastTimer?.cancel();
    _toastTimer = Timer(after, () {
      if (!mounted || _pokes > 0 || _phase != _HelloPhase.asleep) return;
      final l10n = AppLocalizations.of(context);
      showUnwindToast(
        context,
        title: l10n.obWakeToastTitle,
        body: l10n.obWakeToastBody,
        visibleFor: const Duration(milliseconds: 4500),
      );
      // 그래도 안 깨우고 있으면 한 번 더 알려 준다
      _scheduleToast(const Duration(seconds: 9));
    });
  }

  void _pokeTodd() {
    switch (_phase) {
      case _HelloPhase.greet || _HelloPhase.dozing || _HelloPhase.awake:
        // 깨어 있을 땐 평소처럼 — 낮엔 간지럼, 꾸벅일 땐 실눈
        setState(() {
          _event = ToddEvent.poke;
          _tick++;
        });
      case _HelloPhase.asleep:
        _pokes++;
        if (_pokes >= 3) {
          _wake();
        } else {
          // 실눈만 겨우 떠 두리번거리다 도로 잠든다 (어댑터가 poke를
          // 깨어나는 이벤트로 전달 — wakeUpHappy가 아니라)
          setState(() {
            _phase = _HelloPhase.stir;
            _event = ToddEvent.poke;
            _tick++;
          });
          _stirTimer?.cancel();
          _stirTimer = Timer(
            Duration(milliseconds: _pokes == 1 ? _stirBackMs : _stirLingerMs),
            () {
              if (!mounted || _phase != _HelloPhase.stir) return;
              setState(() {
                _phase = _HelloPhase.asleep;
                _event = null;
              });
            },
          );
        }
      case _HelloPhase.stir:
        break; // 이미 뒤척이는 중 — 연타는 삼킨다 (톡, 하나에 반응 하나)
    }
  }

  /// 세 번째 톡 — 기지개를 켜며 일어난다. 제목이 같은 자리에서 다시 타이핑된다.
  void _wake() {
    _toastTimer?.cancel();
    _stirTimer?.cancel();
    ref.read(hapticsProvider).success();
    setState(() {
      _phase = _HelloPhase.awake;
      _event = null; // 명시 이벤트 없음 → 어댑터가 wakeUpHappy(기지개·미소)
    });
    widget.onWoke();
  }

  ToddState get _toddState => switch (_phase) {
    _HelloPhase.greet => ToddState(
      brightness: 0.1,
      mode: ToddMode.day,
      event: _event,
      eventTick: _tick,
    ),
    // 어두운 방의 밤 — dazzle 0이라 꾸벅꾸벅 존다 (콧물 방울까지)
    _HelloPhase.dozing || _HelloPhase.stir => ToddState(
      brightness: 0.95,
      mode: ToddMode.nightAwake,
      dazzle: 0.05,
      event: _event,
      eventTick: _tick,
    ),
    _HelloPhase.asleep => const ToddState(
      brightness: 1.0,
      isAsleep: true,
      mode: ToddMode.asleep,
    ),
    _HelloPhase.awake => ToddState(
      brightness: 0.1,
      mode: ToddMode.day,
      event: _event,
      eventTick: _tick,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final awake = _phase == _HelloPhase.awake;
    return _ObPage(
      hero: UnwindPressable(
        onTap: _pokeTodd,
        depth: 0,
        pressScale: 1.0, // 반응은 캐릭터가 한다
        haptic: UnwindHapticKind.tap,
        isButton: false,
        semanticLabel: awake ? l10n.toddPokeLabel : l10n.obWakeAction,
        child: ToddView(
          state: _toddState,
          reduceMotion: MediaQuery.disableAnimationsOf(context),
          size: 210,
        ),
      ),
      typewriter: true,
      onTitleAdvance: _onTitleAdvance,
      onTitleTyped: _onTitleTyped,
      title: awake ? l10n.obHelloAwake : l10n.obHelloSleepy,
      body: awake ? l10n.obHelloAwakeBody : null,
      cta: l10n.obNext,
      // Todd를 깨워야만 다음으로 — 첫 인터랙션을 건너뛸 수 없다
      ctaEnabled: awake,
      onCta: widget.onNext,
    );
  }
}

// ── 2. 눈부신 밤 + 소등 체험 (병합 2026-08-15 2차) ──────────

class _LightsPage extends StatefulWidget {
  final VoidCallback onNext;
  final ValueChanged<double> onLightChanged;

  const _LightsPage({required this.onNext, required this.onLightChanged});

  @override
  State<_LightsPage> createState() => _LightsPageState();
}

class _LightsPageState extends State<_LightsPage> {
  final _done = [false, false, false];
  ToddEvent? _toddEvent;
  int _toddTick = 0;

  bool get _allDone => _done.every((d) => d);

  void _toggle(int i) {
    final turningOff = !_done[i];
    setState(() {
      _done[i] = !_done[i];
      if (turningOff) {
        _toddEvent = ToddEvent.react;
        _toddTick++;
      }
    });
    final remaining = _done.where((d) => !d).length;
    widget.onLightChanged(remaining / _done.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titles = [l10n.obDummy1, l10n.obDummy2, l10n.obDummy3];
    final checked = _done.where((d) => d).length;

    return _ObPage(
      hero: ToddView(
        state: _allDone
            ? const ToddState(
                brightness: 1.0,
                isAsleep: true,
                mode: ToddMode.asleep,
              )
            : ToddState(
                brightness: checked / 3,
                mode: ToddMode.nightAwake,
                dazzle: (3 - checked) / 3, // 찡그림 + 하품
                event: _toddEvent,
                eventTick: _toddTick,
              ),
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        size: 200,
      ),
      // 초반 페이지는 대사가 살아 있게 타이핑한다 (청구서부터는 정적)
      typewriter: true,
      title: _allDone ? l10n.obLightsDone : l10n.obNightTitle,
      body: _allDone ? l10n.obLightsDoneBody : l10n.obNightBody,
      // 타일은 홈과 같은 폭 — 자기 여백(s20)을 갖고 있어 풀블리드로 얹는다
      fullBleedContent: true,
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

class _BillPageState extends State<_BillPage> with TickerProviderStateMixin {
  late final AnimationController _unroll = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: UnwindMotion.billWigglePeriodMs),
  );
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWiggle();
  }

  @override
  void dispose() {
    _wiggle.dispose();
    _unroll.dispose();
    super.dispose();
  }

  void _syncWiggle() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce || _opened) {
      if (_wiggle.isAnimating) _wiggle.stop();
      _wiggle.value = 0;
    } else if (!_wiggle.isAnimating) {
      _wiggle.repeat();
    }
  }

  void _open() {
    if (_opened) return;
    setState(() => _opened = true);
    _syncWiggle();
    _unroll.forward();
  }

  /// 주기의 앞부분만 흔들리고 나머지는 멈춘다 — 계속 떨리면 초조해 보인다.
  double get _wiggleAngle {
    const window = 0.28;
    final t = _wiggle.value;
    if (t >= window) return 0;
    final local = t / window;
    final decay = 1 - Curves.easeOut.transform(local);
    return math.sin(local * math.pi * 6) *
        UnwindMotion.billWiggleAmp *
        decay;
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
              AnimatedBuilder(
                animation: _wiggle,
                builder: (context, child) =>
                    Transform.rotate(angle: _wiggleAngle, child: child),
                child: UnwindPressable(
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
              ),
              // 영수증이 청구서 아래에서 주르륵 인쇄되어 내려온다
              SizeTransition(
                sizeFactor: CurvedAnimation(
                  parent: _unroll,
                  curve: Curves.easeOutCubic,
                ),
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: UnwindSpacing.s8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _MiniReceipt(),
                      const SizedBox(height: UnwindSpacing.s12),
                      Text(
                        l10n.obBillOnMe,
                        textAlign: TextAlign.center,
                        style: UnwindType.caption.copyWith(
                          color: UnwindColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
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
    final money = BillCurrency.resolve(context);
    final sample = money.format(
      money.charge(0.42),
      languageCode: Localizations.localeOf(context).languageCode,
    );
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
              sample,
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
      hero: ToddView(
        state: const ToddState(brightness: 0.2, mode: ToddMode.day),
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        size: 210,
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
  final bool autofocus;
  final VoidCallback onChanged;
  final VoidCallback onNext;

  const _HabitsPage({
    required this.habits,
    required this.onChanged,
    required this.onNext,
    this.autofocus = false,
  });

  @override
  State<_HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<_HabitsPage> {
  final _fieldCtrl = TextEditingController();
  final _fieldFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // 입력이 시작되면 바로 "다음"이 열린다 (개정 2026-08-15 2차) —
    // `+`는 저장 버튼이 아니라 **여러 개 적을 때** 줄을 추가하는 버튼이다.
    _fieldCtrl.addListener(_onField);
    _focusIfActive();
  }

  @override
  void didUpdateWidget(_HabitsPage old) {
    super.didUpdateWidget(old);
    if (widget.autofocus && !old.autofocus) _focusIfActive();
  }

  void _focusIfActive() {
    if (!widget.autofocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fieldFocus.requestFocus();
    });
  }

  void _onField() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fieldCtrl.removeListener(_onField);
    _fieldCtrl.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  bool get _fieldHasText => _fieldCtrl.text.trim().isNotEmpty;

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

  /// "다음" — 쓰다 만 입력도 함께 저장하고 넘어간다
  void _submit() {
    if (_fieldHasText) _add();
    widget.onNext();
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
                  autofocus: widget.autofocus,
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
      secondary: widget.habits.isEmpty && !_fieldHasText
          ? UnwindButton.ghost(label: l10n.obHabitsNone, onPressed: widget.onNext)
          : null,
      cta: l10n.obNext,
      ctaEnabled: widget.habits.isNotEmpty || _fieldHasText,
      onCta: _submit,
    );
  }
}

// ── 7·8. 질문 2·3: 시간 ────────────────────────────────────

class _HourQuestionPage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                // 살짝 키운 피커 (개정 2026-08-15 2차)
                height: 224,
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
                    itemExtent: 46,
                    scrollController: FixedExtentScrollController(
                      initialItem: initial,
                    ),
                    onSelectedItemChanged: (i) {
                      // 굴러갈 때마다 작은 촉감 (개정 2026-08-15 2차)
                      ref.read(hapticsProvider).selection();
                      onChanged(hours[i]);
                    },
                    children: [
                      for (final h in hours)
                        Center(
                          child: Text(
                            l10n.hourLabel(h),
                            style: UnwindType.headline.copyWith(
                              color: UnwindColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: UnwindSpacing.s16),
              // 답을 고르는 즉시 Todd의 시간이 어떻게 정해지는지 보여준다
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

// ── 9. Todd의 하루 (원형 타임테이블) ────────────────────────

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
/// 깨어 있는 시간은 앰버 호로 돌고, 한가운데에서 Todd가 잔다.
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
      child: ToddView(
        state: const ToddState(
          brightness: 1.0,
          isAsleep: true,
          mode: ToddMode.asleep,
        ),
        reduceMotion: reduce,
        size: 110,
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
  final bool autofocus;
  final VoidCallback onFinish;

  const _NamePage({
    required this.controller,
    required this.onFinish,
    this.autofocus = false,
  });

  @override
  State<_NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<_NamePage> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    _focusIfActive();
  }

  @override
  void didUpdateWidget(_NamePage old) {
    super.didUpdateWidget(old);
    if (widget.autofocus && !old.autofocus) _focusIfActive();
  }

  void _focusIfActive() {
    if (!widget.autofocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasName = widget.controller.text.trim().isNotEmpty;
    return _ObPage(
      hero: ToddView(
        state: const ToddState(brightness: 0.2, mode: ToddMode.day),
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        size: 200,
      ),
      title: l10n.obNameTitle,
      content: Align(
        alignment: Alignment.topCenter,
        child: UnwindTextField(
          controller: widget.controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          hint: l10n.obNameHint,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) {
            if (widget.controller.text.trim().isNotEmpty) widget.onFinish();
          },
        ),
      ),
      // 건너뛰기 없음 (개정 2026-08-15 2차) — Todd가 부를 이름은 꼭 받는다
      cta: l10n.obBegin,
      ctaEnabled: hasName,
      onCta: widget.onFinish,
    );
  }
}

// ── 11. 인사 ────────────────────────────────────────────────

/// 연출 타이밍은 플로우가 페이지 도착 시점에 몰아준다 (_onPageChanged).
class _GreetingPage extends StatelessWidget {
  final String name;
  final int pokeTick;

  const _GreetingPage({required this.name, required this.pokeTick});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(UnwindSpacing.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToddView(
            state: ToddState(
              brightness: 0.1,
              mode: ToddMode.day,
              event: pokeTick > 0 ? ToddEvent.poke : null,
              eventTick: pokeTick,
            ),
            reduceMotion: MediaQuery.disableAnimationsOf(context),
            size: 210,
          ),
          const SizedBox(height: UnwindSpacing.s24),
          Text(
            name.isEmpty ? l10n.obGreetingNoName : l10n.obGreeting(name),
            textAlign: TextAlign.center,
            style: UnwindType.display.copyWith(
              color: UnwindColors.textPrimary,
              height: 1.22,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 12. 위젯 안내 ───────────────────────────────────────────

class _WidgetPage extends StatefulWidget {
  final VoidCallback onDone;

  const _WidgetPage({required this.onDone});

  @override
  State<_WidgetPage> createState() => _WidgetPageState();
}

class _WidgetPageState extends State<_WidgetPage> with _DelayedCta {
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
    return _ObPage(
      title: l10n.obWidgetTitle,
      body: l10n.obWidgetBody,
      heroGap: UnwindSpacing.s24,
      afterBodyGap: UnwindSpacing.s24,
      hero: _HomeScreenPreview(
        pillLeft: l10n.obWidgetPillLeft,
        caption: l10n.appName,
      ),
      content: SingleChildScrollView(
        child: UnwindCard(
          child: Column(
            children: [
              _InstallStep(n: 1, text: l10n.obWidgetStep1),
              const SizedBox(height: UnwindSpacing.s12),
              _InstallStep(n: 2, text: l10n.obWidgetStep2),
              const SizedBox(height: UnwindSpacing.s12),
              _InstallStep(n: 3, text: l10n.obWidgetStep3),
            ],
          ),
        ),
      ),
      cta: l10n.obWidgetCta,
      ctaEnabled: ctaReady,
      onCta: widget.onDone,
    );
  }
}

/// 홈 화면 한 조각 — 위젯이 아이콘들 사이에 앉아 있는 모습.
class _HomeScreenPreview extends StatelessWidget {
  final String pillLeft;
  final String caption;

  const _HomeScreenPreview({required this.pillLeft, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      padding: const EdgeInsets.all(UnwindSpacing.s12),
      decoration: BoxDecoration(
        color: UnwindColors.surface,
        borderRadius: BorderRadius.circular(UnwindRadius.lg),
        border: Border.all(
          color: UnwindColors.border,
          width: UnwindStroke.base,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniToddWidget(pillLeft: pillLeft),
          const SizedBox(width: UnwindSpacing.s12),
          Expanded(
            child: Column(
              children: [
                const _FakeIconsRow(),
                const SizedBox(height: UnwindSpacing.s8),
                const _FakeIconsRow(),
                const SizedBox(height: UnwindSpacing.s12),
                Text(
                  caption,
                  style: UnwindType.caption.copyWith(
                    color: UnwindColors.textMuted,
                    fontVariations: const [FontVariation('wght', 700)],
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

class _FakeIconsRow extends StatelessWidget {
  const _FakeIconsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _FakeAppIcon(),
        const SizedBox(width: UnwindSpacing.s8),
        const _FakeAppIcon(),
      ],
    );
  }
}

class _FakeAppIcon extends StatelessWidget {
  const _FakeAppIcon();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: UnwindColors.surfaceHigh,
            borderRadius: BorderRadius.circular(UnwindRadius.sm),
          ),
        ),
      ),
    );
  }
}

/// 실제 홈 위젯을 축소한 프리뷰 (커피 + 앰버 알약).
class _MiniToddWidget extends StatelessWidget {
  final String pillLeft;

  const _MiniToddWidget({required this.pillLeft});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UnwindRadius.md),
        child: Stack(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [UnwindColors.ink, UnwindColors.inkDeep],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Positioned(
              right: -28,
              top: -36,
              child: IgnorePointer(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          UnwindColors.accent.withValues(alpha: 0.62),
                          UnwindColors.accent.withValues(alpha: 0.20),
                          UnwindColors.accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UnwindSpacing.s8,
                UnwindSpacing.s4,
                UnwindSpacing.s8,
                UnwindSpacing.s8,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ToddView(
                        state: const ToddState(
                          brightness: 0.25,
                          mode: ToddMode.day,
                          activity: ToddDayActivity.coffee,
                        ),
                        reduceMotion: MediaQuery.disableAnimationsOf(context),
                        size: 72,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: UnwindColors.accentDeep,
                      borderRadius: BorderRadius.circular(UnwindRadius.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: UnwindDepth.small),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: UnwindColors.accent,
                          borderRadius: BorderRadius.circular(UnwindRadius.pill),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: UnwindSpacing.s12,
                            vertical: UnwindSpacing.s4,
                          ),
                          child: Text(
                            '3 $pillLeft',
                            style: UnwindType.caption.copyWith(
                              color: UnwindColors.onAccent,
                              fontVariations: const [FontVariation('wght', 800)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallStep extends StatelessWidget {
  final int n;
  final String text;

  const _InstallStep({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: UnwindColors.accent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$n',
                style: UnwindType.caption.copyWith(
                  color: UnwindColors.onAccent,
                  fontVariations: const [FontVariation('wght', 800)],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: UnwindSpacing.s12),
        Expanded(
          child: Text(
            text,
            style: UnwindType.body.copyWith(
              color: UnwindColors.textPrimary,
              fontVariations: const [FontVariation('wght', 600)],
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
