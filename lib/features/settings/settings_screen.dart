import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/color_ramp.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import 'ghost_demo_screen.dart';
import 'settings_controller.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.7 설정 — 유틸리티 화면. 밝은 중립 테마 고정(조명 연출은 오늘 화면 독점).
Future<void> showSettingsScreen(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute(builder: (_) => const SettingsScreen()),
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// pubspec version과 일치 유지
  static const appVersion = '0.1.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = lerpRamp(0.0);
    final l10n = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsControllerProvider).value ?? const UnwindSettings();
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final (reminderHour, reminderMinute) = settings.reminderHourMinute;

    return UnwindTheme(
      colors: colors,
      child: DefaultTextStyle(
        style: UnwindType.body.copyWith(decoration: TextDecoration.none),
        child: ColoredBox(
          color: colors.bg,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(UnwindSpacing.s24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.settingsTitle,
                          style: UnwindType.title.copyWith(
                              color: colors.textPrimarySnap,
                              decoration: TextDecoration.none)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Text(l10n.close,
                            style: UnwindType.label.copyWith(
                                color: colors.textSecondary,
                                decoration: TextDecoration.none)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding:
                        const EdgeInsets.only(bottom: UnwindSpacing.s48),
                    children: [
                      _SectionLabel(l10n.sectionNotifications, colors),
                      _ToggleRow(
                        label: l10n.nightReminder,
                        caption: l10n.nightReminderCaption,
                        value: settings.nightReminderEnabled,
                        colors: colors,
                        onChanged: ctrl.setNightReminderEnabled,
                      ),
                      if (settings.nightReminderEnabled)
                        _PickerRow(
                          label: l10n.reminderTime,
                          valueLabel: settings.nightReminderTime,
                          colors: colors,
                          onTap: () => _pickTime(
                            context,
                            reminderHour,
                            reminderMinute,
                            (h, m) => ctrl.setNightReminderTime(
                                '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}'),
                          ),
                        ),
                      _ToggleRow(
                        label: l10n.billNotification,
                        caption: l10n.billNotificationCaption,
                        value: settings.billNotificationEnabled,
                        colors: colors,
                        onChanged: ctrl.setBillNotificationEnabled,
                      ),
                      _SectionLabel(l10n.sectionFeel, colors),
                      _ToggleRow(
                        label: l10n.sound,
                        value: settings.soundEnabled,
                        colors: colors,
                        onChanged: ctrl.setSoundEnabled,
                      ),
                      _ToggleRow(
                        label: l10n.haptics,
                        value: settings.hapticsEnabled,
                        colors: colors,
                        onChanged: ctrl.setHapticsEnabled,
                      ),
                      _SectionLabel(l10n.sectionDay, colors),
                      _PickerRow(
                        label: l10n.dayStart,
                        caption: l10n.dayStartCaption,
                        valueLabel: l10n.hourLabel(settings.dayStartHour),
                        colors: colors,
                        onTap: () => _pickHour(
                            context, settings.dayStartHour, ctrl.setDayStartHour),
                      ),
                      // 언어 (§ 기본 영어, 설정에서 전환)
                      _SectionLabel(l10n.sectionLanguage, colors),
                      _PickerRow(
                        label: l10n.language,
                        valueLabel: settings.languageCode == 'ko'
                            ? '한국어'
                            : 'English',
                        colors: colors,
                        onTap: () => _pickLanguage(
                            context, settings.languageCode, ctrl),
                      ),
                      _SectionLabel(l10n.sectionData, colors),
                      _PickerRow(
                        label: l10n.eraseData,
                        caption: l10n.eraseDataCaption,
                        valueLabel: '',
                        colors: colors,
                        destructive: true,
                        onTap: () => _confirmReset(context, ctrl, l10n),
                      ),
                      // TODO(unwind): 배포 빌드에서 제거 — 개발용 완전 초기화
                      _PickerRow(
                        label: l10n.fullResetDev,
                        caption: l10n.fullResetDevCaption,
                        valueLabel: '',
                        colors: colors,
                        destructive: true,
                        onTap: () => _confirmFullReset(context, ctrl, l10n),
                      ),
                      // TODO(unwind): 배포 빌드에서 제거 — Rive 검증 데모 (브리프 §6.4)
                      _PickerRow(
                        label: 'Ghost demo (dev)',
                        valueLabel: '',
                        colors: colors,
                        onTap: () => showGhostDemoScreen(context),
                      ),
                      const SizedBox(height: UnwindSpacing.s24),
                      Center(
                        child: Text('Unwind $appVersion',
                            style: UnwindType.caption.copyWith(
                                color: colors.textMuted,
                                decoration: TextDecoration.none)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pickTime(BuildContext context, int hour, int minute,
      void Function(int, int) onPicked) {
    var h = hour, m = minute;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 260,
        color: const Color(0xFFFFFFFF),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(2026, 1, 1, hour, minute),
                use24hFormat: true,
                onDateTimeChanged: (d) {
                  h = d.hour;
                  m = d.minute;
                },
              ),
            ),
            CupertinoButton(
              child: Text(AppLocalizations.of(context).save),
              onPressed: () {
                onPicked(h, m);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickHour(
      BuildContext context, int current, void Function(int) onPicked) {
    var h = current;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 260,
        color: const Color(0xFFFFFFFF),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: CupertinoPicker(
                itemExtent: 36,
                scrollController:
                    FixedExtentScrollController(initialItem: current),
                onSelectedItemChanged: (i) => h = i,
                children: [
                  for (var i = 0; i <= 11; i++)
                    Center(
                        child: Text(
                            AppLocalizations.of(context).hourLabel(i))),
                ],
              ),
            ),
            CupertinoButton(
              child: Text(AppLocalizations.of(context).save),
              onPressed: () {
                onPicked(h);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(
      BuildContext context, SettingsController ctrl, AppLocalizations l10n) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.eraseData),
        content: Text(l10n.eraseDataDialogBody),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ctrl.resetAllData();
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.erase),
          ),
        ],
      ),
    );
  }

  /// TODO(unwind): 배포 빌드에서 제거 — 개발용 완전 초기화.
  /// 설정·온보딩 플래그까지 지우고 모든 화면을 닫아 첫 실행 상태(온보딩)로.
  void _confirmFullReset(
      BuildContext context, SettingsController ctrl, AppLocalizations l10n) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.fullResetDev),
        content: Text(l10n.fullResetDevCaption),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context, rootNavigator: true)
                  .popUntil((r) => r.isFirst);
              await ctrl.fullResetForDev();
            },
            child: Text(l10n.erase),
          ),
        ],
      ),
    );
  }

  void _pickLanguage(
      BuildContext context, String current, SettingsController ctrl) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          for (final (code, name) in const [('en', 'English'), ('ko', '한국어')])
            CupertinoActionSheetAction(
              onPressed: () {
                ctrl.setLanguageCode(code);
                Navigator.of(ctx).pop();
              },
              child: Text(name +
                  (code == current ? '  ✓' : '')),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final UnwindColors colors;
  const _SectionLabel(this.text, this.colors);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            UnwindSpacing.s24, UnwindSpacing.s24, UnwindSpacing.s24, UnwindSpacing.s8),
        child: Text(text,
            style: UnwindType.caption.copyWith(
                color: colors.textMuted, decoration: TextDecoration.none)),
      );
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String? caption;
  final bool value;
  final UnwindColors colors;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    this.caption,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: UnwindSpacing.s24, vertical: UnwindSpacing.s8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: UnwindType.body.copyWith(
                        color: colors.textPrimarySnap,
                        decoration: TextDecoration.none)),
                if (caption != null)
                  Text(caption!,
                      style: UnwindType.caption.copyWith(
                          color: colors.textMuted,
                          decoration: TextDecoration.none)),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: colors.lamp, // 액센트는 lamp 하나뿐 (§8.1)
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final String label;
  final String? caption;
  final String valueLabel;
  final UnwindColors colors;
  final bool destructive;
  final VoidCallback onTap;

  const _PickerRow({
    required this.label,
    this.caption,
    required this.valueLabel,
    required this.colors,
    this.destructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: UnwindSpacing.s24, vertical: UnwindSpacing.s12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: UnwindType.body.copyWith(
                          color: destructive
                              ? const Color(0xFFB4483C)
                              : colors.textPrimarySnap,
                          decoration: TextDecoration.none)),
                  if (caption != null)
                    Text(caption!,
                        style: UnwindType.caption.copyWith(
                            color: colors.textMuted,
                            decoration: TextDecoration.none)),
                ],
              ),
            ),
            Text(valueLabel,
                style: UnwindType.label.copyWith(
                    color: colors.textSecondary,
                    decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }
}
