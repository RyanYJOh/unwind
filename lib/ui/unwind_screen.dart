import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter/widgets.dart';

import '../core/tokens/palette.dart';
import '../core/tokens/spacing.dart';
import '../core/tokens/typography.dart';
import 'unwind_icon_button.dart';

/// 화면 껍데기 — 항상 다크 바닥 + 밝은 상태바 아이콘 + 기본 텍스트 스타일.
///
/// 앱은 라이트 모드를 갖지 않는다. 이 위젯을 쓰면 배경·상태바·기본 글자색이
/// 자동으로 맞춰지므로 화면마다 다시 지정할 필요가 없다.
class UnwindScreen extends StatelessWidget {
  final Widget child;

  /// 상단 헤더 (없으면 생략)
  final Widget? header;

  /// SafeArea를 적용할지. 홈처럼 배경 연출이 전체를 덮어야 하면 false.
  final bool safeArea;
  final Color background;

  const UnwindScreen({
    super.key,
    required this.child,
    this.header,
    this.safeArea = true,
    this.background = UnwindColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = header == null
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header!,
              Expanded(child: child),
            ],
          );

    if (safeArea) body = SafeArea(child: body);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DefaultTextStyle(
        style: UnwindType.body.copyWith(color: UnwindColors.textPrimary),
        child: ColoredBox(color: background, child: body),
      ),
    );
  }
}

/// 화면 상단 바 — 제목 + 좌/우 액션. 듀오링고식으로 제목이 굵다.
class UnwindHeader extends StatelessWidget {
  final String title;
  final IconData? leadingIcon;
  final VoidCallback? onLeading;
  final String? leadingLabel;
  final Widget? trailing;

  const UnwindHeader({
    super.key,
    required this.title,
    this.leadingIcon,
    this.onLeading,
    this.leadingLabel,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UnwindSpacing.s12,
        UnwindSpacing.s8,
        UnwindSpacing.s16,
        UnwindSpacing.s8,
      ),
      child: Row(
        children: [
          if (leadingIcon != null)
            UnwindIconButton(
              icon: leadingIcon!,
              onPressed: onLeading,
              semanticLabel: leadingLabel,
            )
          else
            const SizedBox(width: UnwindSpacing.s8),
          const SizedBox(width: UnwindSpacing.s4),
          Expanded(
            child: Text(
              title,
              style: UnwindType.title.copyWith(color: UnwindColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
