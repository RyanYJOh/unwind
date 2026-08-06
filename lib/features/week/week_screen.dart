import 'package:flutter/cupertino.dart'
    show CupertinoActionSheet, CupertinoActionSheetAction, showCupertinoModalPopup;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/color_ramp.dart';
import '../../core/tokens/motion.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';
import '../compose/compose_sheet.dart';
import '../settings/settings_screen.dart';
import '../today/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.2 주간 뷰 — 책상 위 플래너.
/// **조명 연출을 절대 넣지 않는다.** 밝은 중립 테마 고정(S0).
/// 조도는 오늘 화면의 독점 권한이다.
Future<void> showWeekScreen(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(_WeekRoute());
}

/// 위에서 펼쳐지는 전환 (§9.4: 380ms, settle)
class _WeekRoute extends PopupRoute<void> {
  @override
  Color? get barrierColor => const Color(0x44000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => '닫기';

  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: UnwindMotion.weekExpandMs);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return SlideTransition(
      position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: UnwindMotion.settle)),
      child: const WeekScreen(),
    );
  }
}

class WeekScreen extends ConsumerWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 밝은 중립 테마 고정 — 조도 연동 금지 (§6.2)
    final colors = lerpRamp(0.0);
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

    return UnwindTheme(
      colors: colors,
      child: DefaultTextStyle(
        style: UnwindType.body.copyWith(decoration: TextDecoration.none),
        child: ColoredBox(
          color: colors.bg,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 헤더 — 위로 밀어 접기
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  onVerticalDragUpdate: (d) {
                    if (d.delta.dy < -6) Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(UnwindSpacing.s24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.thisWeek,
                            style: UnwindType.title.copyWith(
                                color: colors.textPrimarySnap,
                                decoration: TextDecoration.none)),
                        Row(children: [
                          GestureDetector(
                            onTap: () => showSettingsScreen(context),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  right: UnwindSpacing.s16),
                              child: Text(l10n.settingsTitle,
                                  style: UnwindType.label.copyWith(
                                      color: colors.textSecondary,
                                      decoration: TextDecoration.none)),
                            ),
                          ),
                          Text(l10n.collapse,
                              style: UnwindType.label.copyWith(
                                  color: colors.textSecondary,
                                  decoration: TextDecoration.none)),
                        ]),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.only(bottom: UnwindSpacing.s48),
                    itemCount: 7,
                    itemBuilder: (context, i) {
                      final day = addDays(monday, i);
                      final key = dayKey(day);
                      final isPastDay =
                          day.isBefore(parseDayKey(todayKey));
                      return _DaySection(
                        dateKey: key,
                        title:
                            '${l10n.monthDay(monthNames[day.month - 1], day.month, day.day)} (${weekdayLabels[day.weekday - 1]})',
                        isToday: key == todayKey,
                        isPast: isPastDay,
                        todos: byDate[key] ?? const [],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
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

  void _showMenu(BuildContext context, WidgetRef ref, Todo todo) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = UnwindTheme.of(context);
    final repo = ref.watch(todoRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: UnwindSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: UnwindSpacing.s24, vertical: UnwindSpacing.s8),
            child: Row(
              children: [
                Text(title,
                    style: UnwindType.label.copyWith(
                        color: isToday
                            ? colors.textPrimarySnap
                            : colors.textSecondary,
                        decoration: TextDecoration.none)),
                if (isToday) ...[
                  const SizedBox(width: UnwindSpacing.s8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: colors.lamp),
                  ),
                ],
                const Spacer(),
                if (!isPast)
                  GestureDetector(
                    onTap: () =>
                        showComposeSheet(context, initialDate: dateKey),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(UnwindSpacing.s4),
                      child: Text(AppLocalizations.of(context).add,
                          style: UnwindType.label.copyWith(
                              color: colors.textMuted,
                              decoration: TextDecoration.none)),
                    ),
                  ),
              ],
            ),
          ),
          if (todos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: UnwindSpacing.s24),
              child: Text('—',
                  style: UnwindType.caption.copyWith(
                      color: colors.textMuted,
                      decoration: TextDecoration.none)),
            )
          else
            for (final todo in todos)
              _PlannerRow(
                todo: todo,
                onToggle: isPast
                    ? null
                    : () => repo.setDone(
                        todo, todo.status != TodoStatus.done),
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
    final colors = UnwindTheme.of(context);
    final done = todo.status == TodoStatus.done;

    return GestureDetector(
      onTap: onToggle,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: UnwindTouch.minTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: UnwindSpacing.s24, vertical: UnwindSpacing.s4),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? colors.textMuted : null,
                  border: Border.all(
                      color: done ? colors.textMuted : colors.border,
                      width: 1.5),
                ),
              ),
              const SizedBox(width: UnwindSpacing.s12),
              Expanded(
                child: Text(
                  todo.title,
                  style: UnwindType.body.copyWith(
                      color: done
                          ? colors.textMuted
                          : colors.textPrimarySnap,
                      decoration: TextDecoration.none),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
