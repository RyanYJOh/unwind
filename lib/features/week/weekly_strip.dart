import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/color_ramp.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../today/providers.dart';
import 'week_screen.dart';

/// §6.2 주간 스트립 — 골목에서 이웃집 창을 보는 은유.
/// 각 날은 작은 창문. 조도만으로 표현한다(퍼센트·개수·체크 금지).
/// 스트립을 아래로 당기면 주간 뷰가 펼쳐진다 — 스트립은 주간 뷰의 접힌 상태.
class WeeklyStrip extends ConsumerStatefulWidget {
  /// 오늘 창에 반영할 실시간 t (화면의 표시값과 동기)
  final double currentT;

  const WeeklyStrip({super.key, required this.currentT});

  @override
  ConsumerState<WeeklyStrip> createState() => _WeeklyStripState();
}

class _WeeklyStripState extends ConsumerState<WeeklyStrip> {
  double _dragAccum = 0;

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  void _openWeek() {
    _dragAccum = 0;
    showWeekScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = UnwindTheme.of(context);
    final windows = ref.watch(weekWindowsProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openWeek,
      onVerticalDragUpdate: (d) {
        _dragAccum += d.delta.dy;
        if (_dragAccum > 28) _openWeek(); // 아래로 당기면 전개 (§6.2)
      },
      onVerticalDragEnd: (_) => _dragAccum = 0,
      child: Semantics(
        label: '이번 주',
        button: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: UnwindSpacing.s24, vertical: UnwindSpacing.s8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final w in windows)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _weekdayLabels[
                          parseWeekday(w.dateKey) - 1],
                      style: UnwindType.caption.copyWith(
                          color: w.isToday
                              ? colors.textSecondary
                              : colors.textMuted,
                          decoration: TextDecoration.none),
                    ),
                    const SizedBox(height: UnwindSpacing.s4),
                    _Window(
                      info: w,
                      currentT: widget.currentT,
                      colors: colors,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

int parseWeekday(String dateKey) {
  final p = dateKey.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])).weekday;
}

/// 창문 하나. 밝기 = 방에 남아 있는 불빛(1 - t).
/// 불을 다 끄고 잠든 날(finalT=1.0)의 창은 캄캄하다 — 그게 좋은 밤이다.
class _Window extends StatelessWidget {
  final WindowInfo info;
  final double currentT;
  final UnwindColors colors;

  const _Window({
    required this.info,
    required this.currentT,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    const darkWindow = Color(0xFF241F30); // 캄캄한 창
    late final Color fill;

    if (info.isToday) {
      final light = (1 - currentT).clamp(0.0, 1.0);
      fill = Color.lerp(darkWindow, colors.lamp, light)!;
    } else if (info.isPast) {
      final ft = info.finalT;
      // 기록 없는 지난 날은 캄캄한 창 (빈 방이었다)
      final light = ft == null ? 0.0 : (1 - ft).clamp(0.0, 1.0);
      fill = Color.lerp(darkWindow, colors.lamp, light)!;
    } else {
      fill = darkWindow; // 다가올 날 — 아직 불이 켜지지 않은 옆방 (§2)
    }

    return Container(
      width: 26,
      height: 34,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(UnwindRadius.sm),
        // 오늘: 테두리로 현재 위치 표시 (§6.2)
        border: info.isToday
            ? Border.all(color: colors.textSecondary, width: 1.5)
            : Border.all(
                color: colors.border.withValues(alpha: 0.6), width: 0.5),
      ),
      // 다가올 날의 예열 — 아주 희미하게 (§6.2)
      child: info.hasPreheat
          ? Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.lamp.withValues(alpha: 0.28),
                ),
              ),
            )
          : null,
    );
  }
}
