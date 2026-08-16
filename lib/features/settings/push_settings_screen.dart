import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/spacing.dart';
import '../../ui/ui.dart';
import '../../l10n/generated/app_localizations.dart';
import 'settings_controller.dart';

Future<void> showPushSettingsScreen(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(CupertinoPageRoute(builder: (_) => const PushSettingsScreen()));
}

/// 네 가지 로컬 알림 on/off (§10).
class PushSettingsScreen extends ConsumerWidget {
  const PushSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsControllerProvider).value ?? const UnwindSettings();
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return UnwindScreen(
      header: UnwindHeader(
        title: l10n.pushSettingsTitle,
        leadingIcon: Icons.arrow_back_rounded,
        leadingLabel: l10n.close,
        onLeading: () => Navigator.of(context).pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: UnwindSpacing.s48),
        children: [
          UnwindListRow.toggle(
            label: l10n.morningGreeting,
            caption: l10n.morningGreetingCaption,
            value: settings.morningGreetingEnabled,
            onChanged: ctrl.setMorningGreetingEnabled,
          ),
          UnwindListRow.toggle(
            label: l10n.nightReminder,
            caption: l10n.nightReminderCaption,
            value: settings.nightReminderEnabled,
            onChanged: ctrl.setNightReminderEnabled,
          ),
          UnwindListRow.toggle(
            label: l10n.todoReminder,
            caption: l10n.todoReminderCaption,
            value: settings.todoReminderEnabled,
            onChanged: ctrl.setTodoReminderEnabled,
          ),
          UnwindListRow.toggle(
            label: l10n.billNotification,
            caption: l10n.billNotificationCaption,
            value: settings.billNotificationEnabled,
            onChanged: ctrl.setBillNotificationEnabled,
          ),
        ],
      ),
    );
  }
}
