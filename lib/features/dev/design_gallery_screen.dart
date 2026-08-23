import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../ui/ui.dart';

/// TODO(unwind): 배포 빌드에서 제거 — 디자인 시스템 v2 갤러리.
///
/// `lib/ui/`의 모든 컴포넌트를 한 화면에서 눌러 보고 확인한다.
/// **새 컴포넌트를 추가하면 여기에도 추가할 것** — 그래야 회귀를 눈으로 잡는다.
Future<void> showDesignGalleryScreen(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(CupertinoPageRoute(builder: (_) => const DesignGalleryScreen()));
}

class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  final _field = TextEditingController();
  bool _toggle = true;
  bool _lamp = true;
  int _chip = 0;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UnwindScreen(
      header: UnwindHeader(
        title: 'Design gallery',
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: () => Navigator.of(context).pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          UnwindSpacing.s20,
          0,
          UnwindSpacing.s20,
          UnwindSpacing.s48,
        ),
        children: [
          const UnwindSectionLabel('Palette', padding: _labelPad),
          const _Swatches(),

          const UnwindSectionLabel('Type', padding: _labelPad),
          _type('display', UnwindType.display),
          _type('title', UnwindType.title),
          _type('headline', UnwindType.headline),
          _type('bodyStrong', UnwindType.bodyStrong),
          _type('body', UnwindType.body),
          _type('label', UnwindType.label),
          _type('caption', UnwindType.caption),

          const UnwindSectionLabel('Typewriter', padding: _labelPad),
          const _TypewriterPreview(),

          const UnwindSectionLabel('Calendar', padding: _labelPad),
          UnwindCard(
            child: UnwindCalendar(
              selected: DateTime(2026, 8, 25),
              today: DateTime(2026, 8, 22),
              min: DateTime(2026, 8, 22),
              max: DateTime(2027, 8, 22),
              weekdayLabels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
              monthLabel: (y, m) => '$m / $y',
              onPick: (_) {},
            ),
          ),

          const UnwindSectionLabel('Buttons', padding: _labelPad),
          UnwindButton(label: '오늘 마무리하기', onPressed: () {}),
          const SizedBox(height: UnwindSpacing.s12),
          UnwindButton.secondary(label: '나중에', onPressed: () {}),
          const SizedBox(height: UnwindSpacing.s12),
          UnwindButton.danger(label: '삭제', onPressed: () {}),
          const SizedBox(height: UnwindSpacing.s12),
          const UnwindButton(label: '비활성 (제목 없음)', onPressed: null),
          const SizedBox(height: UnwindSpacing.s12),
          Row(
            children: [
              UnwindButton(
                label: 'small',
                small: true,
                expand: false,
                icon: Icons.add_rounded,
                onPressed: () {},
              ),
              const SizedBox(width: UnwindSpacing.s12),
              UnwindButton.ghost(label: 'ghost', onPressed: () {}),
            ],
          ),

          const UnwindSectionLabel('Icon buttons', padding: _labelPad),
          Row(
            children: [
              UnwindIconButton(icon: Icons.settings_outlined, onPressed: () {}),
              const SizedBox(width: UnwindSpacing.s12),
              UnwindIconButton(
                icon: Icons.calendar_today_rounded,
                iconSize: 20,
                style: UnwindIconButtonStyle.filled,
                onPressed: () {},
              ),
              const SizedBox(width: UnwindSpacing.s12),
              UnwindIconButton(
                icon: Icons.add_rounded,
                iconSize: 30,
                size: 60,
                style: UnwindIconButtonStyle.accent,
                onPressed: () {},
              ),
            ],
          ),

          const UnwindSectionLabel('Pills', padding: _labelPad),
          Row(
            children: [
              UnwindPill(label: 'Week 33', onTap: () {}),
              const SizedBox(width: UnwindSpacing.s12),
              // 이동용 알약은 작은 › 를 단다 (재도입 2026-08-15)
              UnwindPill(label: 'This week', chevron: true, onTap: () {}),
              const SizedBox(width: UnwindSpacing.s12),
              UnwindPill(
                label: 'Bill',
                tone: UnwindPillTone.accent,
                onTap: () {},
              ),
            ],
          ),

          const UnwindSectionLabel('Badge dot', padding: _labelPad),
          Row(
            children: [
              UnwindBadgeDot(
                child: Image.asset(
                  'assets/images/bill.png',
                  width: UnwindSpacing.s40,
                  height: UnwindSpacing.s40,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: UnwindSpacing.s24),
              const UnwindBadgeDot(
                child: SizedBox(
                  width: UnwindSpacing.s40,
                  height: UnwindSpacing.s40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: UnwindColors.surfaceAlt,
                      borderRadius: BorderRadius.all(
                        Radius.circular(UnwindRadius.sm),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const UnwindSectionLabel('Todo tile', padding: _labelPad),
          Column(
            children: [
              UnwindTodoTile(
                title: '아침 스트레칭',
                timeLabel: '오전 9:00',
                isOn: _lamp,
                hasMemo: true,
                switchSemanticsOn: 'On',
                switchSemanticsOff: 'Off',
                onToggle: () => setState(() => _lamp = !_lamp),
                onTap: () {},
              ),
              UnwindTodoTile(
                title: '설거지 하기',
                isOn: false,
                isDone: true,
                switchSemanticsOn: 'On',
                switchSemanticsOff: 'Off',
                onToggle: () {},
                onTap: () {},
              ),
              // 읽기 전용 (주간 뷰) — 우측이 비고 테두리로만 구분
              UnwindTodoTile(
                title: '주간 뷰: 테두리로만 구분',
                isOn: true,
                readOnlySwitch: true,
                switchSemanticsOn: 'On',
                switchSemanticsOff: 'Off',
                onTap: () {},
              ),
            ],
          ),

          const UnwindSectionLabel('Field / Chips', padding: _labelPad),
          UnwindTextField(controller: _field, hint: '무엇을 끝내볼까요?'),
          const SizedBox(height: UnwindSpacing.s12),
          Wrap(
            spacing: UnwindSpacing.s8,
            runSpacing: UnwindSpacing.s8,
            children: [
              for (final (i, label) in const [
                (0, '반복 없음'),
                (1, '매일'),
                (2, '평일'),
                (3, '매주 수요일'),
              ])
                UnwindChip(
                  label: label,
                  icon: Icons.repeat_rounded,
                  selected: _chip == i,
                  onTap: () => setState(() => _chip = i),
                ),
            ],
          ),

          const UnwindSectionLabel('List rows', padding: _labelPad),
          UnwindCard(
            padding: const EdgeInsets.symmetric(vertical: UnwindSpacing.s8),
            child: Column(
              children: [
                UnwindListRow.toggle(
                  label: '햅틱',
                  caption: '손끝의 반응',
                  value: _toggle,
                  onChanged: (v) => setState(() => _toggle = v),
                ),
                UnwindListRow.value(
                  label: '하루 시작',
                  caption: '이 시각 전은 어제의 방',
                  value: '06시',
                  onTap: () {},
                ),
                UnwindListRow.value(
                  label: '모든 기록 지우기',
                  value: '',
                  destructive: true,
                  onTap: () {},
                ),
              ],
            ),
          ),

          const UnwindSectionLabel('Overlays', padding: _labelPad),
          UnwindButton.secondary(
            label: '토스트 띄우기',
            onPressed: () => showUnwindToast(
              context,
              title: '설거지 하기',
              body: '방에 등을 하나 더 놓았어요',
            ),
          ),
          const SizedBox(height: UnwindSpacing.s12),
          UnwindButton.secondary(
            label: '확인 시트 열기',
            onPressed: () => showUnwindConfirm(
              context,
              title: '이 할 일을 지울까요?',
              message: '지운 등은 되돌릴 수 없어요.',
              confirmLabel: '지우기',
              cancelLabel: '닫기',
            ),
          ),
          const SizedBox(height: UnwindSpacing.s12),
          UnwindButton.secondary(
            label: '액션 시트 열기',
            onPressed: () => showUnwindActions<int>(
              context,
              title: '반복되는 할 일',
              cancelLabel: '닫기',
              actions: const [
                UnwindAction(label: '이 항목만 삭제', value: 0, destructive: true),
                UnwindAction(label: '이후 전체 삭제', value: 1, destructive: true),
              ],
            ),
          ),

          const UnwindSectionLabel('Coach mark', padding: _labelPad),
          const _CoachMarkPreview(),
        ],
      ),
    );
  }

  static const _labelPad = EdgeInsets.fromLTRB(
    0,
    UnwindSpacing.s32,
    0,
    UnwindSpacing.s12,
  );

  Widget _type(String name, TextStyle style) => Padding(
    padding: const EdgeInsets.only(bottom: UnwindSpacing.s8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            name,
            style: UnwindType.caption.copyWith(color: UnwindColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            '오늘을 잘 닫아요 Aa',
            style: style.copyWith(color: UnwindColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}

/// 타이프라이터 미리보기 — 탭하면 처음부터 다시 친다.
/// 점(`.`)에서 길게 쉬는 졸린 리듬을 확인하는 자리.
class _TypewriterPreview extends StatefulWidget {
  const _TypewriterPreview();

  @override
  State<_TypewriterPreview> createState() => _TypewriterPreviewState();
}

class _TypewriterPreviewState extends State<_TypewriterPreview> {
  int _replay = 0;

  @override
  Widget build(BuildContext context) {
    return UnwindPressable(
      onTap: () => setState(() => _replay++),
      depth: 0,
      haptic: UnwindHapticKind.tap,
      isButton: false,
      semanticLabel: 'Typewriter replay',
      child: UnwindCard(
        child: UnwindTypewriterText(
          "Hi, I'm To..d..",
          key: ValueKey(_replay),
          style: UnwindType.title.copyWith(color: UnwindColors.textPrimary),
        ),
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches();

  // accent 계열은 조명 색을 따라가는 게터라 const 목록에 둘 수 없다
  static List<(String, Color)> get _entries => [
    ('ink', UnwindColors.ink),
    ('surface', UnwindColors.surface),
    ('surfaceAlt', UnwindColors.surfaceAlt),
    ('surfaceHigh', UnwindColors.surfaceHigh),
    ('border', UnwindColors.border),
    ('borderStrong', UnwindColors.borderStrong),
    ('accent', UnwindColors.accent),
    ('accentDeep', UnwindColors.accentDeep),
    ('danger', UnwindColors.danger),
    ('dangerDeep', UnwindColors.dangerDeep),
    ('textPrimary', UnwindColors.textPrimary),
    ('textSecondary', UnwindColors.textSecondary),
    ('textMuted', UnwindColors.textMuted),
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: UnwindSpacing.s8,
    runSpacing: UnwindSpacing.s8,
    children: [
      for (final (name, color) in _entries)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(UnwindRadius.sm),
                border: Border.all(
                  color: UnwindColors.border,
                  width: UnwindStroke.hair,
                ),
              ),
            ),
            const SizedBox(height: UnwindSpacing.s4),
            SizedBox(
              width: 76,
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: UnwindType.caption.copyWith(
                  fontSize: 10,
                  color: UnwindColors.textMuted,
                ),
              ),
            ),
          ],
        ),
    ],
  );
}

/// 코치마크는 전역 좌표의 구멍을 뚫으므로, 갤러리에선 가짜 손잡이를 재서 얹는다.
class _CoachMarkPreview extends StatefulWidget {
  const _CoachMarkPreview();

  @override
  State<_CoachMarkPreview> createState() => _CoachMarkPreviewState();
}

class _CoachMarkPreviewState extends State<_CoachMarkPreview> {
  final _handle = GlobalKey();
  Offset? _hole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = _handle.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    setState(() => _hole = box.localToGlobal(box.size.center(Offset.zero)));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(UnwindRadius.md),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            const ColoredBox(color: UnwindColors.ink, child: SizedBox.expand()),
            Positioned(
              right: UnwindSpacing.s24,
              top: UnwindSpacing.s40,
              child: DecoratedBox(
                key: _handle,
                decoration: BoxDecoration(
                  color: UnwindColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: UnwindSpacing.s20,
                  height: UnwindSpacing.s20,
                ),
              ),
            ),
            if (_hole != null)
              Positioned.fill(
                child: UnwindCoachMark(
                  holeCenter: _hole!,
                  holeRadius: UnwindSpacing.s24,
                  message: 'Pull the handle all the way down.',
                  onDismiss: () {},
                ),
              ),
          ],
        ),
      ),
    );
  }
}
