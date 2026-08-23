import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics.dart';
import '../../data/db/database.dart';
import '../../data/repositories/todo_repository.dart';
import '../../ui/ui.dart';
import '../compose/compose_sheet.dart';
import 'providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// 할 일 하나에 대한 편집·삭제 흐름 — **오늘의 방과 주간 뷰가 함께 쓴다**.
///
/// 화면마다 따로 구현하면 반드시 갈라진다(실제로 스와이프 삭제가 반복 범위를
/// 묻지 않던 버그가 그렇게 생겼다). 규칙은 여기 한 곳에만 둔다:
///
/// - 반복 항목이면 **어느 경로로 지우든** 단일/이후 전체를 먼저 묻는다
/// - 지운 뒤에는 되돌리기가 달린 상단 토스트를 띄운다
/// - 사용자가 취소하면 `false` — 스와이프는 이 값으로 항목을 제자리에 돌린다
Future<bool> deleteTodoWithUndo(
  BuildContext context,
  WidgetRef ref,
  Todo todo, {

  /// 단건 삭제 전에 확인을 받을지. 롱프레스는 true(실수 방지),
  /// 스와이프는 false(제스처 자체가 이미 의도적이다).
  required bool confirmSingle,
}) async {
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
    if (deleteFuture == null || !context.mounted) return false;
    final undo = deleteFuture
        ? await repo.removeRecurringFrom(todo)
        : await repo.remove(todo);
    ToddAnalytics.track(
      'Click delete-to-do',
      {
        'title': todo.title,
        'target_date': ToddAnalytics.isoDate(todo.date),
      },
    );
    if (context.mounted) _showDeletedToast(context, todo, undo);
    return true;
  }

  if (confirmSingle) {
    final ok = await showUnwindConfirm(
      context,
      title: todo.title,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.close,
    );
    if (!ok || !context.mounted) return false;
  }
  final undo = await repo.remove(todo);
  ToddAnalytics.track(
    'Click delete-to-do',
    {
      'title': todo.title,
      'target_date': ToddAnalytics.isoDate(todo.date),
    },
  );
  if (context.mounted) _showDeletedToast(context, todo, undo);
  return true;
}

void _showDeletedToast(BuildContext context, Todo todo, TodoUndo undo) {
  final l10n = AppLocalizations.of(context);
  showUnwindToast(
    context,
    title: todo.title,
    body: l10n.toastTaskDeleted,
    actionLabel: l10n.undo,
    onAction: () => undo(),
  );
}

/// 편집 — 두 화면 모두 같은 입력 시트를 연다.
void editTodo(BuildContext context, Todo todo) =>
    showComposeSheet(context, existing: todo);
