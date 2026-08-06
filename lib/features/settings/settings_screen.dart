import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/color_ramp.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import 'settings_controller.dart';

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
                      Text('설정',
                          style: UnwindType.title.copyWith(
                              color: colors.textPrimarySnap,
                              decoration: TextDecoration.none)),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Text('닫기',
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
                      _SectionLabel('알림', colors),
                      _ToggleRow(
                        label: '밤 리마인더',
                        caption: 'Lumi가 아직 못 자고 있을 때 알려드려요',
                        value: settings.nightReminderEnabled,
                        colors: colors,
                        onChanged: ctrl.setNightReminderEnabled,
                      ),
                      if (settings.nightReminderEnabled)
                        _PickerRow(
                          label: '리마인더 시각',
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
                        label: '청구서 도착',
                        caption: '매주 월요일 아침에 지난주 청구서를 알려드려요',
                        value: settings.billNotificationEnabled,
                        colors: colors,
                        onChanged: ctrl.setBillNotificationEnabled,
                      ),
                      _SectionLabel('감각', colors),
                      _ToggleRow(
                        label: '사운드',
                        value: settings.soundEnabled,
                        colors: colors,
                        onChanged: ctrl.setSoundEnabled,
                      ),
                      _ToggleRow(
                        label: '햅틱',
                        value: settings.hapticsEnabled,
                        colors: colors,
                        onChanged: ctrl.setHapticsEnabled,
                      ),
                      _SectionLabel('하루', colors),
                      _PickerRow(
                        label: '하루 시작 시각',
                        caption: '이 시각 전까지는 어제의 방이에요',
                        valueLabel: '${settings.dayStartHour}시',
                        colors: colors,
                        onTap: () => _pickHour(
                            context, settings.dayStartHour, ctrl.setDayStartHour),
                      ),
                      _SectionLabel('데이터', colors),
                      _PickerRow(
                        label: '데이터 초기화',
                        caption: '모든 할 일과 기록을 지워요',
                        valueLabel: '',
                        colors: colors,
                        destructive: true,
                        onTap: () => _confirmReset(context, ctrl),
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
              child: const Text('저장'),
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
                  for (var i = 0; i <= 11; i++) Center(child: Text('$i시')),
                ],
              ),
            ),
            CupertinoButton(
              child: const Text('저장'),
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

  void _confirmReset(BuildContext context, SettingsController ctrl) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text('모든 할 일과 기록이 지워져요. 되돌릴 수 없어요.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ctrl.resetAllData();
              Navigator.of(ctx).pop();
            },
            child: const Text('지우기'),
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
