import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../ui/ui.dart';
import '../dev/design_gallery_screen.dart';
import 'ghost_demo_screen.dart';
import 'settings_controller.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.7 설정 — 유틸리티 화면. 앱 전체와 같은 다크 팔레트를 쓴다
/// (개편 2026-08-12: 라이트 모드 폐기).
Future<void> showSettingsScreen(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(CupertinoPageRoute(builder: (_) => const SettingsScreen()));
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// pubspec version과 일치 유지
  static const appVersion = '0.1.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsControllerProvider).value ?? const UnwindSettings();
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final (reminderHour, reminderMinute) = settings.reminderHourMinute;

    return UnwindScreen(
      header: UnwindHeader(
        title: l10n.settingsTitle,
        leadingIcon: Icons.arrow_back_rounded,
        leadingLabel: l10n.close,
        onLeading: () => Navigator.of(context).pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: UnwindSpacing.s48),
        children: [
          UnwindSectionLabel(l10n.sectionNotifications),
          UnwindListRow.toggle(
            label: l10n.nightReminder,
            caption: l10n.nightReminderCaption,
            value: settings.nightReminderEnabled,
            onChanged: ctrl.setNightReminderEnabled,
          ),
          if (settings.nightReminderEnabled)
            UnwindListRow.value(
              label: l10n.reminderTime,
              value: settings.nightReminderTime,
              onTap: () => _pickTime(
                context,
                reminderHour,
                reminderMinute,
                (h, m) => ctrl.setNightReminderTime(
                  '${h.toString().padLeft(2, '0')}:'
                  '${m.toString().padLeft(2, '0')}',
                ),
              ),
            ),
          UnwindListRow.toggle(
            label: l10n.billNotification,
            caption: l10n.billNotificationCaption,
            value: settings.billNotificationEnabled,
            onChanged: ctrl.setBillNotificationEnabled,
          ),

          UnwindSectionLabel(l10n.sectionFeel),
          UnwindListRow.toggle(
            label: l10n.sound,
            value: settings.soundEnabled,
            onChanged: ctrl.setSoundEnabled,
          ),
          UnwindListRow.toggle(
            label: l10n.haptics,
            value: settings.hapticsEnabled,
            onChanged: ctrl.setHapticsEnabled,
          ),

          UnwindSectionLabel(l10n.sectionDay),
          UnwindListRow.value(
            label: l10n.dayStart,
            caption: l10n.dayStartCaption,
            value: l10n.hourLabel(settings.dayStartHour),
            onTap: () =>
                _pickHour(context, settings.dayStartHour, ctrl.setDayStartHour),
          ),

          UnwindSectionLabel(l10n.sectionLanguage),
          UnwindListRow.value(
            label: l10n.language,
            value: settings.languageCode == 'ko' ? '한국어' : 'English',
            onTap: () => _pickLanguage(context, settings.languageCode, ctrl),
          ),

          UnwindSectionLabel(l10n.sectionData),
          UnwindListRow.value(
            label: l10n.eraseData,
            caption: l10n.eraseDataCaption,
            value: '',
            destructive: true,
            onTap: () => _confirmReset(context, ctrl, l10n),
          ),
          // TODO(unwind): 배포 빌드에서 제거 — 개발용 완전 초기화
          UnwindListRow.value(
            label: l10n.fullResetDev,
            caption: l10n.fullResetDevCaption,
            value: '',
            destructive: true,
            onTap: () => _confirmFullReset(context, ctrl, l10n),
          ),
          // TODO(unwind): 배포 빌드에서 제거 — 캐릭터 검증 데모
          UnwindListRow.value(
            label: 'Ghost demo (dev)',
            value: '',
            onTap: () => showGhostDemoScreen(context),
          ),
          // TODO(unwind): 배포 빌드에서 제거 — 디자인 시스템 갤러리
          UnwindListRow.value(
            label: 'Design gallery (dev)',
            caption: 'lib/ui/ 컴포넌트 전수 검증',
            value: '',
            onTap: () => showDesignGalleryScreen(context),
          ),

          const SizedBox(height: UnwindSpacing.s24),
          Center(
            child: Text(
              'Unwind $appVersion',
              style: UnwindType.caption.copyWith(color: UnwindColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  void _pickTime(
    BuildContext context,
    int hour,
    int minute,
    void Function(int, int) onPicked,
  ) {
    var h = hour, m = minute;
    showUnwindSheet<void>(
      context,
      builder: (ctx) => UnwindSheet(
        title: AppLocalizations.of(ctx).reminderTime,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PickerBox(
              height: 190,
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
            const SizedBox(height: UnwindSpacing.s16),
            UnwindButton(
              label: AppLocalizations.of(ctx).save,
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
    BuildContext context,
    int current,
    void Function(int) onPicked,
  ) {
    var h = current;
    showUnwindSheet<void>(
      context,
      builder: (ctx) => UnwindSheet(
        title: AppLocalizations.of(ctx).dayStart,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PickerBox(
              height: 190,
              child: CupertinoPicker(
                itemExtent: 38,
                scrollController: FixedExtentScrollController(
                  initialItem: current,
                ),
                onSelectedItemChanged: (i) => h = i,
                children: [
                  for (var i = 0; i <= 11; i++)
                    Center(
                      child: Text(
                        AppLocalizations.of(ctx).hourLabel(i),
                        style: UnwindType.body.copyWith(
                          color: UnwindColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: UnwindSpacing.s16),
            UnwindButton(
              label: AppLocalizations.of(ctx).save,
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

  Future<void> _confirmReset(
    BuildContext context,
    SettingsController ctrl,
    AppLocalizations l10n,
  ) async {
    final ok = await showUnwindConfirm(
      context,
      title: l10n.eraseData,
      message: l10n.eraseDataDialogBody,
      confirmLabel: l10n.erase,
      cancelLabel: l10n.cancel,
    );
    if (ok) await ctrl.resetAllData();
  }

  /// TODO(unwind): 배포 빌드에서 제거 — 개발용 완전 초기화.
  /// 설정·온보딩 플래그까지 지우고 모든 화면을 닫아 첫 실행 상태(온보딩)로.
  Future<void> _confirmFullReset(
    BuildContext context,
    SettingsController ctrl,
    AppLocalizations l10n,
  ) async {
    final ok = await showUnwindConfirm(
      context,
      title: l10n.fullResetDev,
      message: l10n.fullResetDevCaption,
      confirmLabel: l10n.erase,
      cancelLabel: l10n.cancel,
    );
    if (!ok || !context.mounted) return;
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    await ctrl.fullResetForDev();
  }

  Future<void> _pickLanguage(
    BuildContext context,
    String current,
    SettingsController ctrl,
  ) async {
    final l10n = AppLocalizations.of(context);
    final code = await showUnwindActions<String>(
      context,
      title: l10n.language,
      cancelLabel: l10n.cancel,
      actions: [
        for (final (code, name) in const [('en', 'English'), ('ko', '한국어')])
          UnwindAction(label: code == current ? '$name  ✓' : name, value: code),
      ],
    );
    if (code != null) ctrl.setLanguageCode(code);
  }
}

/// Cupertino 피커를 다크 팔레트 안에 앉힌다.
class _PickerBox extends StatelessWidget {
  final double height;
  final Widget child;

  const _PickerBox({required this.height, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: UnwindColors.surfaceAlt,
      borderRadius: BorderRadius.circular(UnwindRadius.md),
      border: Border.all(color: UnwindColors.border, width: UnwindStroke.base),
    ),
    clipBehavior: Clip.antiAlias,
    child: CupertinoTheme(
      data: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: UnwindColors.accent,
      ),
      child: child,
    ),
  );
}
