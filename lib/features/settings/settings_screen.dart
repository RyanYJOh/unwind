import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../ui/ui.dart';
import '../dev/design_gallery_screen.dart';
import '../onboarding/onboarding_flow.dart';
import '../today/providers.dart';
import 'ghost_demo_screen.dart';
import 'push_settings_screen.dart';
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

    return UnwindScreen(
      header: UnwindHeader(
        title: l10n.settingsTitle,
        leadingIcon: Icons.arrow_back_rounded,
        leadingLabel: l10n.close,
        onLeading: () => Navigator.of(context).pop(),
      ),
      child: ListView(
        // 조명 색을 바꾸면 UnwindScreen이 화면을 새로 인플레이트한다 —
        // PageStorageKey가 스크롤 위치를 지킨다 (선택형 2026-08-22)
        key: const PageStorageKey('settings-list'),
        padding: const EdgeInsets.only(bottom: UnwindSpacing.s48),
        children: [
          // Todd의 하루 (세계관 2026-08-15) — 기상·취침시간이 하루의 축이다
          UnwindSectionLabel(l10n.sectionDay),
          UnwindListRow.value(
            label: l10n.wakeTime,
            caption: l10n.wakeTimeCaption,
            value: l10n.hourLabel(settings.wakeHour),
            onTap: () => _pickHour(
              context,
              title: l10n.wakeTime,
              // 온보딩의 계산값(유저 기상 -1h)이 어디에 떨어져도 담기게
              // 넉넉히 (개정 2026-08-15)
              hours: [for (var h = 1; h <= 12; h++) h],
              current: settings.wakeHour,
              onPicked: ctrl.setWakeHour,
            ),
          ),
          UnwindListRow.value(
            label: l10n.bedtime,
            caption: l10n.bedtimeCaption,
            value: l10n.hourLabel(settings.bedtimeHour),
            onTap: () => _pickHour(
              context,
              title: l10n.bedtime,
              // 저녁 16시 ~ 새벽 2시 (자정 넘김 허용, 온보딩 계산값 포함)
              hours: [for (var h = 16; h <= 23; h++) h, 0, 1, 2],
              current: settings.bedtimeHour,
              onPicked: ctrl.setBedtimeHour,
            ),
          ),

          UnwindSectionLabel(l10n.sectionNotifications),
          UnwindListRow(
            label: l10n.pushSettings,
            caption: l10n.pushSettingsCaption,
            onTap: () => showPushSettingsScreen(context),
            trailing: Text(
              '›',
              style: UnwindType.title.copyWith(color: UnwindColors.textMuted),
            ),
          ),

          UnwindSectionLabel(l10n.sectionFeel),
          UnwindListRow.toggle(
            label: l10n.haptics,
            value: settings.hapticsEnabled,
            onChanged: ctrl.setHapticsEnabled,
          ),

          // 방 조명의 색 (선택형 2026-08-22, 발주자 지시) — 고르는 즉시
          // 앱 전체 팔레트가 따라간다 (CTA·FAB·글로우·창문·위젯까지)
          UnwindSectionLabel(l10n.sectionLight),
          _LightColorRow(
            selected: UnwindLightColor.fromName(settings.lightColor),
            onPicked: (c) => ctrl.setLightColor(c.name),
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
          // TODO(unwind): 배포 빌드에서 제거 — 온보딩 미리보기 (저장 없음)
          UnwindListRow.value(
            label: 'Onboarding (dev)',
            caption: '저장 없이 플로우만 체험',
            value: '',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              CupertinoPageRoute(
                builder: (_) => const OnboardingFlow(preview: true),
              ),
            ),
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
          // TODO(unwind): 배포 빌드에서 제거 — 홈 위젯 App Group 진단.
          // 위젯이 "Good morning"에 고정되면 여기서 원인이 바로 보인다:
          // containerOk=false면 엔타이틀먼트·프로비저닝, fileExists=false면
          // 앱이 못 쓴 것, 있는데도 위젯이 옛것이면 타임라인 리로드 문제다.
          UnwindListRow.value(
            label: 'Widget diagnostics (dev)',
            caption: 'App Group 스냅샷 상태 확인',
            value: '',
            onTap: () => _showWidgetDiagnostics(context, ref),
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

  /// 홈 위젯 스냅샷이 App Group에 실제로 닿는지 그 자리에서 확인한다.
  /// 먼저 오늘 스냅샷을 강제로 한 번 쓰고, 네이티브가 본 상태를 그대로 읽는다.
  Future<void> _showWidgetDiagnostics(BuildContext context, WidgetRef ref) async {
    await flushWidgetSnapshot(ref);
    final service = ref.read(widgetSnapshotServiceProvider);
    final d = await service.diagnose();
    if (!context.mounted) return;
    final lines = <String>[
      'write: ${service.lastResult}',
      'containerOk: ${d['containerOk']}',
      'suiteOk: ${d['suiteOk']}',
      'fileExists: ${d['fileExists']}',
      'protection: ${d['fileProtection']}',
      'defaultsDayKey: ${d['defaultsDayKey']}',
      'body: ${d['fileBody']}',
      if (d['error'] != null) 'error: ${d['error']}',
    ];
    if (!context.mounted) return;
    await showUnwindConfirm(
      context,
      title: 'Widget diagnostics',
      message: lines.join('\n'),
      confirmLabel: 'Close',
      cancelLabel: 'Dismiss',
      destructive: false,
    );
  }

  /// 시 단위 피커 (세계관 2026-08-15: 기상·취침시간은 정시 단위) —
  /// [hours]에 나열된 시각만 고를 수 있다 (취침은 자정 넘김 허용).
  void _pickHour(
    BuildContext context, {
    required String title,
    required List<int> hours,
    required int current,
    required void Function(int) onPicked,
  }) {
    final initial = hours.indexOf(current).clamp(0, hours.length - 1);
    var h = hours[initial];
    showUnwindSheet<void>(
      context,
      builder: (ctx) => UnwindSheet(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PickerBox(
              height: 190,
              child: CupertinoPicker(
                itemExtent: 38,
                scrollController: FixedExtentScrollController(
                  initialItem: initial,
                ),
                onSelectedItemChanged: (i) => h = hours[i],
                children: [
                  for (final hour in hours)
                    Center(
                      child: Text(
                        AppLocalizations.of(ctx).hourLabel(hour),
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
      data: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: UnwindColors.accent,
      ),
      child: child,
    ),
  );
}

/// 방 조명의 색 스와치 (선택형 2026-08-22) — 7색 중 하나를 고른다.
/// 선택된 스와치는 밝은 링 + 체크. 실제 팔레트 적용은 UnwindApp이
/// 설정을 watch하며 UnwindColors.setLightColor로 흘린다.
class _LightColorRow extends StatelessWidget {
  final UnwindLightColor selected;
  final ValueChanged<UnwindLightColor> onPicked;

  const _LightColorRow({required this.selected, required this.onPicked});

  String _label(AppLocalizations l10n, UnwindLightColor c) => switch (c) {
    UnwindLightColor.amber => l10n.lightAmber,
    UnwindLightColor.sunset => l10n.lightSunset,
    UnwindLightColor.rose => l10n.lightRose,
    UnwindLightColor.lavender => l10n.lightLavender,
    UnwindLightColor.sky => l10n.lightSky,
    UnwindLightColor.mint => l10n.lightMint,
    UnwindLightColor.moon => l10n.lightMoon,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: UnwindSpacing.s16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final c in UnwindLightColor.values)
            UnwindPressable(
              onTap: () => onPicked(c),
              depth: 0,
              pressScale: 0.88,
              haptic: UnwindHapticKind.selection,
              semanticLabel: _label(l10n, c),
              isToggled: c == selected,
              // §12 터치 타깃 44pt — 스와치는 그 안의 원
              child: SizedBox(
                width: UnwindTouch.minTarget,
                height: UnwindTouch.minTarget,
                child: Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // 미선택도 투명 링을 그려 선택 시 크기가 안 흔들린다
                      border: Border.all(
                        color: c == selected
                            ? UnwindColors.textPrimary
                            : const Color(0x00000000),
                        width: UnwindStroke.base,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c.seed,
                          shape: BoxShape.circle,
                        ),
                        child: c == selected
                            ? Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: c.ink,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
