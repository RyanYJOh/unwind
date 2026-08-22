import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart'
    show Icons, MaterialLocalizations, TimeOfDay;
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
import '../today/todo_actions.dart';
import 'week_label.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.2 주간 뷰 — 이번 주(월~일)의 방들을 한눈에 보는 플래너.
/// 홈 상단의 `Week n` 알약으로 들어온다 (전면 재작성 2026-08-13).
///
/// **오늘의 방과의 경계**:
/// - 여기서는 **체크할 수 없다.** 등을 끄는 건 오늘의 방의 몫이다 —
///   그래야 "하루를 닫는다"는 행위가 한 곳에만 남는다. 등은 읽기 전용
///   인디케이터로만 보여준다.
/// - 추가·편집·삭제는 오늘의 방과 **완전히 같은 UX**를 쓴다
///   (`todo_actions.dart` 공용 헬퍼 + 같은 입력 시트).
/// - **조명 연출을 넣지 않는다.** CornerGlow·조도는 오늘의 방의 독점 권한이다
///   (§6.2). 이 화면의 빛 표현은 상단의 [_WeekProgressBar]다.
///
/// [mondayKey]로 **아무 주나** 열 수 있다 (개편 2026-08-13) — 하단 스트립을
/// 넘긴 주를 그대로 연다.
Future<void> showWeekScreen(BuildContext context, {required String mondayKey}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(CupertinoPageRoute(builder: (_) => WeekScreen(mondayKey: mondayKey)));
}

class WeekScreen extends ConsumerStatefulWidget {
  /// 보여줄 주의 월요일
  final String mondayKey;

  const WeekScreen({super.key, required this.mondayKey});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  /// 켜면 완료된 항목만 목록에서 숨긴다. 진행 바는 그대로다.
  bool _incompleteOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final todayKey = ref.watch(todayKeyProvider);
    final todos =
        ref.watch(weekTodosForProvider(widget.mondayKey)).value ??
        const <Todo>[];
    final monday = parseDayKey(widget.mondayKey);

    final byDate = <String, List<Todo>>{};
    for (final t in todos) {
      // 반복 tombstone(deferred)은 지워진 회차다 — 어디에도 세지 않는다
      if (t.status == TodoStatus.deferred) continue;
      byDate.putIfAbsent(t.date, () => []).add(t);
    }

    return UnwindScreen(
      header: UnwindHeader(
        // 칩과 같은 이름을 쓴다 — 어느 주를 보고 있는지 헷갈리지 않게
        title: weekLabel(
          context,
          mondayKey: widget.mondayKey,
          todayKey: todayKey,
        ),
        leadingIcon: Icons.arrow_back_rounded,
        leadingLabel: l10n.close,
        onLeading: () => Navigator.of(context).pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: UnwindSpacing.s48),
        children: [
          // 진행 바가 맨 위 — 이 주의 요약. 필터 토글은 구분선 **아래**,
          // 자기가 거르는 목록 쪽에 붙인다 (개정 2026-08-22: 토글이 바로
          // 위에 있으면 진행 바를 거르는 스위치처럼 읽힌다).
          _WeekProgressBar(todos: byDate.values.expand((e) => e).toList()),
          const UnwindDivider(indent: UnwindSpacing.s20),
          UnwindListRow.toggle(
            label: l10n.weekIncompleteOnly,
            value: _incompleteOnly,
            onChanged: (v) => setState(() => _incompleteOnly = v),
            padding: const EdgeInsets.fromLTRB(
              UnwindSpacing.s20,
              UnwindSpacing.s8,
              UnwindSpacing.s20,
              0,
            ),
          ),
          const SizedBox(height: UnwindSpacing.s8),
          for (var i = 0; i < 7; i++)
            _DaySection(
              date: addDays(monday, i),
              todayKey: todayKey,
              todos: _visibleTodos(
                byDate[dayKey(addDays(monday, i))] ?? const <Todo>[],
              ),
            ),
        ],
      ),
    );
  }

  List<Todo> _visibleTodos(List<Todo> todos) {
    if (!_incompleteOnly) return todos;
    return todos.where((t) => t.status != TodoStatus.done).toList();
  }
}

/// 이번 주 진행 — **끝낸 만큼 차오른다**.
///
/// §1의 "생산성 어휘 금지"는 2026-08-13에 완화됐다: 오늘의 방은 여전히
/// 은유로만 말하지만, 주간 뷰처럼 계획을 훑는 자리에서는 진행 표시를 쓴다.
class _WeekProgressBar extends StatelessWidget {
  final List<Todo> todos;

  const _WeekProgressBar({required this.todos});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = todos.length;
    final done = todos.where((t) => t.status == TodoStatus.done).length;
    // 계획이 없는 주는 빈 방 — 사과가 아니라 초대의 문구 (§8.5)
    final ratio = total == 0 ? 0.0 : done / total;

    final String caption;
    if (total == 0) {
      caption = l10n.weekEmpty;
    } else if (done == total) {
      caption = l10n.weekAllDone;
    } else {
      caption = l10n.weekProgressLabel;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UnwindSpacing.s20,
        UnwindSpacing.s8,
        UnwindSpacing.s20,
        UnwindSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: caption,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(UnwindRadius.pill),
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: UnwindColors.surfaceAlt,
                  border: Border.all(
                    color: UnwindColors.border,
                    width: UnwindStroke.hair,
                  ),
                  borderRadius: BorderRadius.circular(UnwindRadius.pill),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    widthFactor: ratio,
                    heightFactor: 1,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: UnwindColors.accent),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: UnwindSpacing.s8),
          Text(
            caption,
            style: UnwindType.caption.copyWith(
              color: total > 0 && done == total
                  ? UnwindColors.accent
                  : UnwindColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// 하루 — 요일 머리 + 그날의 등들 + 우측 끝 추가 버튼.
class _DaySection extends ConsumerWidget {
  final DateTime date;
  final String todayKey;
  final List<Todo> todos;

  const _DaySection({
    required this.date,
    required this.todayKey,
    required this.todos,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = dayKey(date);
    final isToday = key == todayKey;
    final weekday = l10n.weekdaysShort.split(',')[date.weekday - 1];
    final monthName = l10n.monthsShort.split(',')[date.month - 1];

    // 빈 요일은 바짝 붙여 한 주가 한 화면에 들어오게 한다
    return Padding(
      padding: EdgeInsets.only(
        bottom: todos.isEmpty ? UnwindSpacing.s2 : UnwindSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              UnwindSpacing.s20,
              0,
              UnwindSpacing.s12,
              0,
            ),
            child: Row(
              children: [
                Text(
                  weekday,
                  style: UnwindType.bodyStrong.copyWith(
                    color: isToday
                        ? UnwindColors.accent
                        : UnwindColors.textPrimary,
                  ),
                ),
                const SizedBox(width: UnwindSpacing.s8),
                Text(
                  l10n.monthDay(monthName, date.month, date.day),
                  style: UnwindType.caption.copyWith(
                    color: UnwindColors.textMuted,
                  ),
                ),
                // 날짜 바로 옆에 붙는다 — "이 날짜로 들어간다"는 뜻이라
                // 우측 끝 `+`와 나란히 두면 무엇이 무엇인지 헷갈린다
                // (개정 2026-08-13).
                UnwindIconButton(
                  icon: Icons.chevron_right_rounded,
                  iconSize: 20,
                  size: 32,
                  style: UnwindIconButtonStyle.plain,
                  semanticLabel: l10n.openDay(weekday),
                  onPressed: () {
                    ref
                        .read(selectedDateProvider.notifier)
                        .select(isToday ? null : key);
                    Navigator.of(context).pop();
                  },
                ),
                const Spacer(),
                UnwindIconButton(
                  icon: Icons.add_rounded,
                  iconSize: 22,
                  style: UnwindIconButtonStyle.plain,
                  semanticLabel: l10n.addToDay(weekday),
                  color: UnwindColors.accent,
                  onPressed: () => showComposeSheet(context, initialDate: key),
                ),
              ],
            ),
          ),
          if (todos.isEmpty)
            // 등이 없는 날 — 빈 자리를 조용한 선 하나로만 표시한다
            const Padding(
              padding: EdgeInsets.fromLTRB(
                UnwindSpacing.s20,
                0,
                UnwindSpacing.s20,
                UnwindSpacing.s8,
              ),
              child: SizedBox(
                height: UnwindStroke.base,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: UnwindColors.border),
                ),
              ),
            )
          else
            for (final todo in todos) _WeekTodoRow(todo: todo),
        ],
      ),
    );
  }
}

/// 주간 뷰의 한 줄. 오늘의 방과 같은 타일을 쓰되 **스위치는 읽기 전용**이다.
class _WeekTodoRow extends ConsumerWidget {
  final Todo todo;

  const _WeekTodoRow({required this.todo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isOn = todo.status == TodoStatus.pending;

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      // 오늘의 방과 같은 규칙 — 반복이면 범위를 묻고, 취소하면 되돌아온다
      confirmDismiss: (_) =>
          deleteTodoWithUndo(context, ref, todo, confirmSingle: false),
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
        // 체크는 오늘의 방에서만 — 여기선 등의 상태만 읽는다
        readOnlySwitch: true,
        switchSemanticsOn: l10n.lampOn,
        switchSemanticsOff: l10n.lampOff,
        onTap: () => editTodo(context, todo),
        onLongPress: () =>
            deleteTodoWithUndo(context, ref, todo, confirmSingle: true),
      ),
    );
  }
}
