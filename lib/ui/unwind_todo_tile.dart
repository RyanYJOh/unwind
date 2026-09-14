import 'package:flutter/material.dart' show Icons;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import 'unwind_pressable.dart';
import 'unwind_switch.dart';

/// 할 일 하나 = 방의 등 하나 (§1 컨셉).
///
/// 개편 2026-08-12: 형광등 패널·발광 그라데이션을 버리고 **두툼한 타일 +
/// 벽 로커 스위치**로. 켜진 등은 앰버 테두리로만 구분한다 — 빛의 총량은
/// CornerGlow가 담당하고, 타일은 그 빛을 흉내내지 않는다.
///
/// - 타일 탭 = 편집, 롱프레스 = 홈에선 편집 모드 (주간 뷰는 삭제), 스위치 탭 = 토글
/// - 완료 항목은 삭선 + 가라앉은 면
/// - [readOnlySwitch]면 우측에 **아무것도 그리지 않는다**. 켜짐/꺼짐은
///   테두리 색으로만 구분한다 — 앰버 표시를 남겨 두면 "누르면 체크된다"로
///   오인된다 (개정 2026-08-13). 체크는 오직 오늘의 방에서만 한다 (§6.2).
/// - [editing] (2026-09-14) — 아이폰 홈 화면식 편집 모드. 스위치 자리에
///   [reorderHandle](없으면 "시간순 고정" 표시)이, 좌상단 모서리에 삭제
///   배지가 나온다. 편집 중 타일 탭은 아무 일도 하지 않는다 — 탭을 삼켜서
///   바깥의 "빈 곳 탭 = 편집 끝"으로 새지 않게 한다.
class UnwindTodoTile extends StatelessWidget {
  final String title;
  final String? timeLabel;

  /// 등이 켜져 있는가 (= 아직 남은 할 일)
  final bool isOn;

  /// 실제로 완료 처리됐는가 — 삭선의 근거.
  /// 일괄 소등 중 시각적으로만 꺼진 항목과 구분해야 하므로 [isOn]과 별개다.
  final bool isDone;

  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 롱프레스 햅틱 — 홈은 편집 모드로 들어 올리는 [UnwindHapticKind.lift],
  /// 주간 뷰는 삭제 확인으로 가는 기본 warning.
  final UnwindHapticKind longPressHaptic;

  /// 소등 도미노 중 잔광 (0~1)
  final double lit;

  final String switchSemanticsOn;
  final String switchSemanticsOff;

  /// 스위치를 조작할 수 없는 자리(주간 뷰). 우측이 비고, 상태는 테두리로만.
  final bool readOnlySwitch;

  /// 메모가 있으면 제목 끝에 작은 노트 아이콘을 단다 — 내용이 아니라
  /// 존재만 알린다 (홈 2026-08-23).
  final bool hasMemo;

  /// 반복 항목이면 제목 끝에 작은 반복 아이콘을 단다 — 메모 아이콘과 같은
  /// 문법 (2026-08-27). 규칙 내용이 아니라 반복이라는 사실만 알린다.
  final bool hasRepeat;

  /// 편집 모드 (2026-09-14) — 위 클래스 설명 참고.
  final bool editing;

  /// 삭제 배지를 눌렀을 때. 주면 배지 자리를 늘 잡아 두고, [editing]일 때만
  /// 튀어나온다 (켜고 끌 때 트리 모양이 바뀌지 않게).
  final VoidCallback? onRemove;
  final String? removeSemanticsLabel;

  /// 편집 모드 우측의 순서 손잡이 ([UnwindDragHandle]을 화면이 끌기 리스너로
  /// 감싸 넘긴다). 없으면 순서를 옮길 수 없는 항목 — 시간 지정 항목은
  /// 시간순으로 놓이므로 [fixedOrderSemanticsLabel]과 작은 시계만 보인다.
  final Widget? reorderHandle;
  final String? fixedOrderSemanticsLabel;

  const UnwindTodoTile({
    super.key,
    required this.title,
    required this.isOn,
    required this.switchSemanticsOn,
    required this.switchSemanticsOff,
    this.timeLabel,
    this.isDone = false,
    this.onToggle,
    this.onTap,
    this.onLongPress,
    this.longPressHaptic = UnwindHapticKind.warning,
    this.lit = 1.0,
    this.readOnlySwitch = false,
    this.hasMemo = false,
    this.hasRepeat = false,
    this.editing = false,
    this.onRemove,
    this.removeSemanticsLabel,
    this.reorderHandle,
    this.fixedOrderSemanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(UnwindRadius.md);
    const dur = Duration(milliseconds: 200);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final Widget trailing;
    final String trailingKey;
    if (editing) {
      trailing =
          reorderHandle ?? _FixedOrderMark(label: fixedOrderSemanticsLabel);
      trailingKey = reorderHandle != null ? 'handle' : 'fixed';
    } else {
      trailing = UnwindLampSwitch(
        isOn: isOn,
        lit: lit,
        onTap: onToggle,
        semanticsOn: switchSemanticsOn,
        semanticsOff: switchSemanticsOff,
      );
      trailingKey = 'switch';
    }

    final tile = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UnwindSpacing.s20,
        vertical: UnwindSpacing.s4,
      ),
      child: GestureDetector(
        // 편집 중엔 탭을 삼킨다 (아이폰 홈 화면처럼 아무 일도 없다)
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: editing ? () {} : null,
        child: UnwindPressable(
          onTap: editing ? null : onTap,
          onLongPress: editing ? null : onLongPress,
          longPressHaptic: longPressHaptic,
          depth: UnwindDepth.base,
          borderRadius: br,
          // 스위치가 없으면 상태를 읽어 줄 것이 테두리뿐이라 라벨에 싣는다
          semanticLabel: [
            ?timeLabel,
            title,
            if (readOnlySwitch || editing)
              isOn ? switchSemanticsOn : switchSemanticsOff,
          ].join(' '),
          isButton: !editing && onTap != null,
          child: AnimatedContainer(
            duration: dur,
            curve: Curves.easeOut,
            constraints: const BoxConstraints(
              minHeight: UnwindTouch.tileHeight,
            ),
            padding: const EdgeInsets.only(
              left: UnwindSpacing.s16,
              right: UnwindSpacing.s8,
              top: UnwindSpacing.s8,
              bottom: UnwindSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: isOn ? UnwindColors.surface : UnwindColors.ink,
              borderRadius: br,
              border: Border.all(
                color: isOn ? UnwindColors.accentEdge : UnwindColors.border,
                width: UnwindStroke.base,
              ),
            ),
            child: Row(
              children: [
                Expanded(child: _TitleBlock(tile: this)),
                if (editing || !readOnlySwitch) ...[
                  const SizedBox(width: UnwindSpacing.s8),
                  // 스위치 ↔ 손잡이는 제자리에서 바뀐다
                  AnimatedSwitcher(
                    duration: reduce ? Duration.zero : dur,
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(trailingKey),
                      child: trailing,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (onRemove == null) return tile;

    // 삭제 배지 — 타일 좌상단 모서리에 걸친다. 터치 영역(44)은 항목 경계
    // 안에 두어야 눌린다 (경계 밖은 히트 테스트가 닿지 않는다).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(
          left: 2,
          top: 0,
          width: UnwindTouch.minTarget,
          height: UnwindTouch.minTarget,
          child: IgnorePointer(
            ignoring: !editing,
            child: ExcludeSemantics(
              excluding: !editing,
              child: AnimatedScale(
                scale: editing ? 1 : 0,
                duration: reduce ? Duration.zero : dur,
                curve: editing ? Curves.easeOutBack : Curves.easeIn,
                child: _RemoveBadge(
                  onTap: onRemove!,
                  label: removeSemanticsLabel,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final UnwindTodoTile tile;

  const _TitleBlock({required this.tile});

  @override
  Widget build(BuildContext context) {
    final isOn = tile.isOn;
    final isDone = tile.isDone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tile.timeLabel != null) ...[
          Text(
            tile.timeLabel!,
            style: UnwindType.caption.copyWith(
              color: isOn ? UnwindColors.accent : UnwindColors.textMuted,
            ),
          ),
          const SizedBox(height: UnwindSpacing.s2),
        ],
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: tile.title,
                style: UnwindType.bodyStrong.copyWith(
                  color: isDone
                      ? UnwindColors.textMuted
                      : isOn
                      ? UnwindColors.textPrimary
                      : UnwindColors.textSecondary,
                  decoration: isDone
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: UnwindColors.textMuted,
                  decorationThickness: 2,
                ),
              ),
              if (tile.hasMemo) _titleIcon(Icons.sticky_note_2_rounded),
              if (tile.hasRepeat) _titleIcon(Icons.repeat_rounded),
            ],
          ),
        ),
      ],
    );
  }

  InlineSpan _titleIcon(IconData icon) => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(left: UnwindSpacing.s4),
      child: Icon(icon, size: 12, color: UnwindColors.textMuted),
    ),
  );
}

/// 좌상단 삭제 배지 — 아이폰 홈 화면의 그 동그라미. 코랄이 아니라 중립색이다:
/// 모든 타일에 코랄 점이 박히면 방이 경고판처럼 보인다. 파괴적 색은 누른 뒤의
/// 확인 시트가 쓴다.
class _RemoveBadge extends StatelessWidget {
  final VoidCallback onTap;
  final String? label;

  const _RemoveBadge({required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return UnwindPressable(
      onTap: onTap,
      depth: 0,
      pressScale: 0.85,
      semanticLabel: label,
      child: SizedBox.expand(
        child: Align(
          alignment: Alignment.topCenter,
          child: Transform.translate(
            // 원의 중심이 타일 모서리 안쪽 4pt에 오도록 살짝 끌어올린다
            offset: const Offset(0, -4),
            child: Container(
              width: UnwindSpacing.s24,
              height: UnwindSpacing.s24,
              decoration: BoxDecoration(
                color: UnwindColors.surfaceHigh,
                shape: BoxShape.circle,
                border: Border.all(
                  color: UnwindColors.borderStrong,
                  width: UnwindStroke.base,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: UnwindColors.solid,
                    offset: Offset(0, 2),
                    blurRadius: 0, // §11
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: UnwindColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 편집 모드에서 순서를 옮길 수 없는 항목의 표시 — 시간 지정 항목은
/// 시간순으로 놓이므로 손잡이 대신 작은 시계를 둔다 (없으면 "왜 이것만
/// 손잡이가 없지?"가 된다).
class _FixedOrderMark extends StatelessWidget {
  final String? label;

  const _FixedOrderMark({this.label});

  @override
  Widget build(BuildContext context) {
    // 제 노드를 가져야 타일 라벨에 묻히지 않는다
    return Semantics(
      container: true,
      label: label,
      child: const SizedBox(
        width: UnwindTouch.minTarget,
        height: UnwindTouch.minTarget,
        child: Center(
          child: Icon(
            Icons.schedule_rounded,
            size: 18,
            color: UnwindColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// 편집 모드의 순서 손잡이 (2026-09-14). 끄는 동작 자체는 화면이 감싼
/// ReorderableDragStartListener가 맡는다 — 여기는 모양과 접근성만.
/// 스크린 리더 사용자는 끌 수 없으니 위·아래로 옮기기 동작을 준다 (§12).
class UnwindDragHandle extends StatelessWidget {
  final String semanticLabel;
  final String moveUpLabel;
  final String moveDownLabel;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const UnwindDragHandle({
    super.key,
    required this.semanticLabel,
    required this.moveUpLabel,
    required this.moveDownLabel,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    // 제 노드를 가져야 위·아래 동작이 타일 노드에 묻히지 않는다
    return Semantics(
      container: true,
      label: semanticLabel,
      customSemanticsActions: {
        CustomSemanticsAction(label: moveUpLabel): ?onMoveUp,
        CustomSemanticsAction(label: moveDownLabel): ?onMoveDown,
      },
      child: const SizedBox(
        width: UnwindTouch.minTarget,
        height: UnwindTouch.minTarget,
        child: Center(
          child: Icon(
            Icons.drag_handle_rounded,
            size: UnwindSpacing.s24,
            color: UnwindColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
