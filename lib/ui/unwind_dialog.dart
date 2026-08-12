import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import 'unwind_button.dart';
import 'unwind_sheet.dart';

/// 액션 시트의 항목 하나.
class UnwindAction<T> {
  final String label;
  final T value;
  final bool destructive;

  const UnwindAction({
    required this.label,
    required this.value,
    this.destructive = false,
  });
}

/// 되돌릴 수 없는 조작 앞의 확인. Cupertino 다이얼로그 대신 우리 시트로
/// 띄운다 — 앱 전체가 같은 물성을 갖도록.
Future<bool> showUnwindConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
}) async {
  final result = await showUnwindSheet<bool>(
    context,
    builder: (ctx) => UnwindSheet(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) ...[
            Text(
              message,
              style: UnwindType.body.copyWith(
                color: UnwindColors.textSecondary,
              ),
            ),
            const SizedBox(height: UnwindSpacing.s20),
          ],
          destructive
              ? UnwindButton.danger(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(ctx).pop(true),
                )
              : UnwindButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
          const SizedBox(height: UnwindSpacing.s8),
          UnwindButton.ghost(
            label: cancelLabel,
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// 여러 갈래 중 하나를 고르게 한다 (삭제 범위 선택, 언어 선택 등).
/// 취소하면 null.
Future<T?> showUnwindActions<T>(
  BuildContext context, {
  String? title,
  required List<UnwindAction<T>> actions,
  required String cancelLabel,
}) {
  return showUnwindSheet<T>(
    context,
    builder: (ctx) => UnwindSheet(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in actions) ...[
            a.destructive
                ? UnwindButton.danger(
                    label: a.label,
                    onPressed: () => Navigator.of(ctx).pop(a.value),
                  )
                : UnwindButton.secondary(
                    label: a.label,
                    onPressed: () => Navigator.of(ctx).pop(a.value),
                  ),
            const SizedBox(height: UnwindSpacing.s8),
          ],
          UnwindButton.ghost(
            label: cancelLabel,
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
}
