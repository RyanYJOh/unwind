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

    // 조명 색(팔레트 세대)이 바뀌면 화면을 통째로 다시 인플레이트한다
    // (선택형 2026-08-22). 색은 정적 게터라 자동 전파가 없고, const
    // 서브트리는 rebuild를 잘라먹는다 — 키 교체가 유일하게 확실한 전면
    // 갱신이다. 스크롤을 지켜야 하는 리스트는 PageStorageKey를 단다
    // (설정 화면 — PageStorage 정체성은 이 키 교체의 영향을 받지 않는다).
    return ValueListenableBuilder<int>(
      valueListenable: UnwindColors.paletteEpoch,
      builder: (context, epoch, body) => KeyedSubtree(
        key: ValueKey('palette-$epoch'),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: DefaultTextStyle(
            style: UnwindType.body.copyWith(color: UnwindColors.textPrimary),
            child: ColoredBox(color: background, child: body!),
          ),
        ),
      ),
      child: body,
    );
  }
}

/// 화면 상단 바 — 제목 + 좌/우 액션. 듀오링고식으로 제목이 굵다.
class UnwindHeader extends StatelessWidget {
  final String title;

  /// 좌측 끝에 놓을 임의 위젯. 주면 [leadingIcon]보다 우선한다
  /// (홈은 여기에 청구서 버튼을 둔다).
  final Widget? leading;
  final IconData? leadingIcon;
  final VoidCallback? onLeading;
  final String? leadingLabel;

  /// 제목 **바로 옆**에 붙는 것 (주간 뷰 알약처럼 제목에 딸린 보조 액션).
  /// 우측 끝의 [trailing]과 달리 제목의 일부처럼 읽힌다.
  final Widget? titleTrailing;
  final Widget? trailing;

  const UnwindHeader({
    super.key,
    required this.title,
    this.leading,
    this.leadingIcon,
    this.onLeading,
    this.leadingLabel,
    this.titleTrailing,
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
          if (leading != null)
            leading!
          else if (leadingIcon != null)
            UnwindIconButton(
              icon: leadingIcon!,
              onPressed: onLeading,
              semanticLabel: leadingLabel,
            )
          else
            const SizedBox(width: UnwindSpacing.s8),
          const SizedBox(width: UnwindSpacing.s4),
          Flexible(
            child: Text(
              title,
              style: UnwindType.title.copyWith(color: UnwindColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (titleTrailing != null) ...[
            const SizedBox(width: UnwindSpacing.s8),
            titleTrailing!,
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
