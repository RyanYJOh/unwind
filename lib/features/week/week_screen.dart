import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';
import '../../ui/ui.dart';
import '../compose/compose_sheet.dart';
import '../today/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.2 주간 뷰 — 책상 위 플래너.
/// **조명 연출을 절대 넣지 않는다.** 조도는 오늘 화면의 독점 권한이다.
/// 개정 2026-08-07: 라우트가 아닌 토글 오버레이 — 상태는 설정에 영속된다.
/// (현재 진입점 없음 — 하단 스트립이 날짜 선택을 담당한다.)
class WeekScreen extends ConsumerWidget {
  /// 접기 — 토글 해제 (개정: Navigator.pop 아님)
  final VoidCallback? onCollapse;

  const WeekScreen({super.key, this.onCollapse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final weekdayLabels = l10n.weekdaysShort.split(',');
    final monthNames = l10n.monthsShort.split(',');
    final todayKey = ref.watch(todayKeyProvider);
    final todos = ref.watch(weekTodosProvider).value ?? const <Todo>[];
    final monday = parseDayKey(weekMondayKey(todayKey));

    final byDate = <String, List<Todo>>{};
    for (final t in todos) {
      byDate.putIfAbsent(t.date, () => []).add(t);
    }

    return UnwindScreen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더 — 위로 밀어 접기
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) {
              if (d.delta.dy < -6) onCollapse?.call();
            },
            child: UnwindHeader(
              title: l10n.thisWeek,
              trailing: UnwindButton.ghost(
                label: l10n.collapse,
                onPressed: onCollapse,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: UnwindSpacing.s48),
              itemCount: 7,
              itemBuilder: (context, i) {
                final day = addDays(monday, i);
                final key = dayKey(day);
                final isPastDay = day.isBefore(parseDayKey(todayKey));
                return _DaySection(
                  dateKey: key,
                  title:
                      '${l10n.monthDay(monthNames[day.month - 1], day.month, day.day)}'
                      ' (${weekdayLabels[day.weekday - 1]})',
                  isToday: key == todayKey,
                  isPast: isPastDay,
                  todos: byDate[key] ?? const [],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySection extends ConsumerWidget {
  final String dateKey;
  final String title;
  final bool isToday;
  final bool isPast;
  final List<Todo> todos;

  const _DaySection({
    required this.dateKey,
    required this.title,
    required this.isToday,
    required this.isPast,
    required this.todos,
  });

  Future<void> _showMenu(BuildContext context, WidgetRef ref, Todo todo) async {
    final l10n = AppLocalizations.of(context);
    final action = await showUnwindActions<String>(
      context,
      title: todo.title,
      cancelLabel: l10n.close,
      actions: [
        UnwindAction(label: l10n.edit, value: 'edit'),
        UnwindAction(label: l10n.delete, value: 'delete', destructive: true),
      ],
    );
    if (action == null || !context.mounted) return;
    if (action == 'edit') {
      showComposeSheet(context, existing: todo);
    } else {
      await ref.read(todoRepositoryProvider).remove(todo);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(todoRepositoryProvider);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: UnwindSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: UnwindSpacing.s24,
              vertical: UnwindSpacing.s8,
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: UnwindType.label.copyWith(
                    color: isToday
                        ? UnwindColors.textPrimary
                        : UnwindColors.textSecondary,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: UnwindSpacing.s8),
                  const SizedBox(
                    width: 6,
                    height: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: UnwindColors.accent,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (!isPast)
                  UnwindButton.ghost(
                    label: l10n.add,
                    onPressed: () =>
                        showComposeSheet(context, initialDate: dateKey),
                  ),
              ],
            ),
          ),
          if (todos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UnwindSpacing.s24,
              ),
              child: Text(
                '—',
                style: UnwindType.caption.copyWith(
                  color: UnwindColors.textMuted,
                ),
              ),
            )
          else
            for (final todo in todos)
              _PlannerRow(
                todo: todo,
                onToggle: isPast
                    ? null
                    : () => repo.setDone(todo, todo.status != TodoStatus.done),
                onLongPress: () => _showMenu(context, ref, todo),
              ),
        ],
      ),
    );
  }
}

/// 플래너 행 — 조명 연출 없음 (등·발광·조도 금지, §6.2). 담백한 체크만.
class _PlannerRow extends StatelessWidget {
  final Todo todo;
  final VoidCallback? onToggle;
  final VoidCallback onLongPress;

  const _PlannerRow({
    required this.todo,
    required this.onToggle,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final done = todo.status == TodoStatus.done;

    return UnwindPressable(
      onTap: onToggle,
      onLongPress: onLongPress,
      depth: 0,
      pressScale: 0.985,
      haptic: done ? UnwindHapticKind.toggleOff : UnwindHapticKind.toggleOn,
      semanticLabel: todo.title,
      isToggled: done,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: UnwindTouch.minTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UnwindSpacing.s24,
            vertical: UnwindSpacing.s4,
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? UnwindColors.accent : null,
                  border: Border.all(
                    color: done
                        ? UnwindColors.accent
                        : UnwindColors.borderStrong,
                    width: UnwindStroke.base,
                  ),
                ),
              ),
              const SizedBox(width: UnwindSpacing.s12),
              Expanded(
                child: Text(
                  todo.title,
                  style: UnwindType.body.copyWith(
                    color: done
                        ? UnwindColors.textMuted
                        : UnwindColors.textPrimary,
                    decoration: done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: UnwindColors.textMuted,
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
