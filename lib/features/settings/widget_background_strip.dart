import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../domain/models/widget_background.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/ui.dart';
import '../premium/paywall_screen.dart';
import 'settings_controller.dart';
import 'widget_background_preview.dart';

/// 위젯 배경 스트립 (3차 개정 2026-08-28, 발주자 지시) — 별도 갤러리
/// 화면을 폐기하고 **설정 화면 안에서 가로 스크롤로 바로** 미리 본다.
/// 카드 = 실제 위젯 구성(배경 + 글로우 + 잠든 Todd).
///
/// 탭 = 선택(§8.7 게이트 ③: 깊은 밤 외 Plus, 잠긴 카드는 페이월) +
/// **위젯 설치 안내 바텀시트** — 배경을 골라 봤자 홈 화면에 위젯이
/// 없으면 아무것도 안 보인다. 안내는 온보딩 위젯 단계(§6.6 12페이지)의
/// 3단계 문구를 그대로 쓴다.
class WidgetBackgroundStrip extends ConsumerWidget {
  const WidgetBackgroundStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsControllerProvider).value ?? const UnwindSettings();
    final selected = WidgetBackground.fromName(settings.widgetBackground);
    final premium = settings.premiumEnabled;

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: UnwindSpacing.s20),
        itemCount: WidgetBackground.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: UnwindSpacing.s12),
        itemBuilder: (context, i) {
          final bg = WidgetBackground.values[i];
          final locked = !premium && bg != WidgetBackground.deepNight;
          return _StripCell(
            bg: bg,
            label: widgetBackgroundLabel(l10n, bg),
            selected: bg == selected,
            locked: locked,
            onTap: () {
              if (locked) {
                showPaywall(context, from: 'widgetBackground');
                return;
              }
              ref
                  .read(settingsControllerProvider.notifier)
                  .setWidgetBackground(bg.name);
              showWidgetInstallSheet(context, bg);
            },
          );
        },
      ),
    );
  }
}

class _StripCell extends StatelessWidget {
  final WidgetBackground bg;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _StripCell({
    required this.bg,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return UnwindPressable(
      onTap: onTap,
      haptic: UnwindHapticKind.selection,
      borderRadius: BorderRadius.circular(UnwindRadius.md),
      semanticLabel: label,
      isToggled: selected,
      depth: 0,
      pressScale: 0.96,
      child: Column(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: DecoratedBox(
              // 선택 = 앰버 테두리 (켜진 등의 문법, §7 타일과 동일)
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(UnwindRadius.md),
                border: Border.all(
                  width: UnwindStroke.base,
                  color: selected ? UnwindColors.accent : UnwindColors.border,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(UnwindStroke.base),
                    child: WidgetBackgroundPreviewCard(
                      bg: bg,
                      accent: UnwindColors.accent,
                      borderRadius: UnwindRadius.md - UnwindStroke.base,
                      toddSize: 46,
                    ),
                  ),
                  if (locked)
                    Positioned(
                      top: UnwindSpacing.s8,
                      right: UnwindSpacing.s8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          // 밝은 배경 위에서도 읽히게 불투명 채움 (§5.1)
                          color: UnwindColors.surfaceHigh,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 11,
                          color: UnwindColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: UnwindSpacing.s8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: UnwindType.caption.copyWith(
              color: selected
                  ? UnwindColors.accent
                  : UnwindColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 위젯 설치 안내 시트 — 배경을 고른 직후, 홈 화면에 실제로 올리는 법을
/// 알려준다. 문구는 온보딩 위젯 안내 단계(obWidget*)를 그대로 재사용.
Future<void> showWidgetInstallSheet(BuildContext context, WidgetBackground bg) {
  return showUnwindSheet(
    context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return UnwindSheet(
        title: widgetBackgroundLabel(l10n, bg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: UnwindSpacing.s8),
            Center(
              child: SizedBox(
                width: 158,
                height: 158,
                child: WidgetBackgroundPreviewCard(
                  bg: bg,
                  accent: UnwindColors.accent,
                  borderRadius: UnwindRadius.xl,
                  toddSize: 72,
                ),
              ),
            ),
            const SizedBox(height: UnwindSpacing.s16),
            Text(
              l10n.obWidgetBody,
              textAlign: TextAlign.center,
              style: UnwindType.body.copyWith(
                color: UnwindColors.textSecondary,
              ),
            ),
            const SizedBox(height: UnwindSpacing.s16),
            _InstallStep(n: 1, text: l10n.obWidgetStep1),
            const SizedBox(height: UnwindSpacing.s8),
            _InstallStep(n: 2, text: l10n.obWidgetStep2),
            const SizedBox(height: UnwindSpacing.s8),
            _InstallStep(n: 3, text: l10n.obWidgetStep3),
            const SizedBox(height: UnwindSpacing.s20),
            UnwindButton(
              label: l10n.obWidgetCta,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    },
  );
}

class _InstallStep extends StatelessWidget {
  final int n;
  final String text;

  const _InstallStep({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: UnwindColors.accent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$n',
                style: UnwindType.caption.copyWith(
                  color: UnwindColors.onAccent,
                  fontVariations: const [FontVariation('wght', 800)],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: UnwindSpacing.s12),
        Expanded(
          child: Text(
            text,
            style: UnwindType.body.copyWith(color: UnwindColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
