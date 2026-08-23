import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics.dart';
import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../ui/ui.dart';
import '../today/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// §6.2 하단 주간 스트립 — 골목에서 이웃집 창을 보는 은유.
/// 각 날은 작은 창문 + 그날 밤 Todd의 눈.
///   - **앰버로 밝은 창은 오늘 하나뿐** (개정 2026-08-22) — 남은 빛 실시간
///   - 지난 날은 결과와 무관하게 캄캄한 창 + 감긴 눈. 불(미완)을 남긴
///     밤이면 눈 밑 **다크서클**, 다 끄고 잔 밤이면 스마일
///   - 아직 오지 않은 날 = 빈 창 (얼굴 없음)
///
/// 개편 2026-08-13: 일 단위 30일 스크롤 → **주 단위 페이징**.
/// 한 페이지가 월~일 한 주이고, 가로로 넘기면 주가 바뀐다. 넘긴 주는
/// [stripWeekOffsetProvider]에 실려 좌상단 칩 라벨이 따라간다.
/// 셀 위 라벨은 날짜가 아니라 요일(Mon·Tue…)이다.
class WeeklyStrip extends ConsumerStatefulWidget {
  /// 오늘 창에 반영할 실시간 t (화면의 표시값과 동기)
  final double currentT;

  const WeeklyStrip({super.key, required this.currentT});

  @override
  ConsumerState<WeeklyStrip> createState() => _WeeklyStripState();
}

class _WeeklyStripState extends ConsumerState<WeeklyStrip> {
  /// 이번 주가 놓이는 페이지 번호 (앞쪽은 과거, 뒤쪽은 미래)
  static const _thisWeekPage = kStripWeeksBack;

  late final PageController _controller = PageController(
    initialPage: _thisWeekPage,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final todayKey = ref.watch(todayKeyProvider);
    final byDate = ref.watch(stripDaysByKeyProvider);
    final viewedKey = ref.watch(viewedDayKeyProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: UnwindColors.surface,
        borderRadius: BorderRadius.circular(UnwindRadius.md),
        border: Border.all(
          color: UnwindColors.border,
          width: UnwindStroke.base,
        ),
      ),
      child: SizedBox(
        height: 72,
        child: Semantics(
          label: l10n.thisWeekLabel,
          child: PageView.builder(
            controller: _controller,
            itemCount: kStripWeeksBack + kStripWeeksAhead + 1,
            onPageChanged: (page) => ref
                .read(stripWeekOffsetProvider.notifier)
                .set(page - _thisWeekPage),
            itemBuilder: (context, page) {
              final windows = weekWindows(
                mondayKey: stripMondayKey(todayKey, page - _thisWeekPage),
                todayKey: todayKey,
                byDate: byDate,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UnwindSpacing.s8,
                  vertical: UnwindSpacing.s8,
                ),
                child: Row(
                  children: [
                    for (final w in windows)
                      Expanded(
                        child: _DayCell(
                          info: w,
                          currentT: widget.currentT,
                          selected: w.dateKey == viewedKey,
                          onTap: () {
                            final target = w.isToday ? todayKey : w.dateKey;
                            ToddAnalytics.track('Click change-date', {
                              'target_date': ToddAnalytics.isoDate(target),
                            });
                            // 오늘을 고르면 null — 롤오버 시 자동으로 따라간다
                            ref
                                .read(selectedDateProvider.notifier)
                                .select(w.isToday ? null : w.dateKey);
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
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

/// dateKey(yyyy-MM-dd)의 일(day)
int parseDayOfMonth(String dateKey) => int.parse(dateKey.split('-')[2]);

class _DayCell extends StatelessWidget {
  final WindowInfo info;
  final double currentT;
  final bool selected;
  final VoidCallback onTap;

  const _DayCell({
    required this.info,
    required this.currentT,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 라벨은 날짜가 아니라 요일 (개편 2026-08-13) — 한 주가 한 화면이라
    // 며칠인지보다 무슨 요일인지가 먼저 읽힌다.
    final weekday = l10n.weekdaysShort.split(
      ',',
    )[parseWeekday(info.dateKey) - 1];

    return UnwindPressable(
      onTap: onTap,
      depth: 0,
      pressScale: 0.9,
      haptic: UnwindHapticKind.selection,
      semanticLabel: info.dateKey,
      isToggled: selected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekday,
            style: UnwindType.caption.copyWith(
              fontSize: 10,
              color: info.isToday
                  ? UnwindColors.accent
                  : UnwindColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          _Window(info: info, currentT: currentT, selected: selected),
        ],
      ),
    );
  }
}

/// 창문 하나. 밝기 = 방에 남아 있는 불빛(1 - t).
/// 안에는 그날 밤 Todd의 눈 — 밝으면 못 자 졸린 눈, 캄캄하면 감긴 눈.
class _Window extends StatelessWidget {
  final WindowInfo info;
  final double currentT;
  final bool selected;

  const _Window({
    required this.info,
    required this.currentT,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    // 그날 방에 실제로 남아 있던 빛 — 표정(만족/다크서클)의 근거
    final double rawLeft;
    if (info.isToday) {
      rawLeft = (1 - currentT).clamp(0.0, 1.0);
    } else {
      final ft = info.finalT;
      rawLeft = ft == null ? 0.0 : (1 - ft).clamp(0.0, 1.0);
    }

    // 창의 표시 밝기 (개정 2026-08-22): **앰버 창은 오늘 하나뿐이다.**
    // 지난 날 창은 결과와 무관하게 캄캄하다 — 그날 남긴 불의 흔적은
    // 빛이 아니라 Todd의 다크서클로 남는다.
    final light = info.isToday ? rawLeft : 0.0;

    // 만족스럽게 잠든 날 = 기록이 있고 불을 다 끄고 잔 날 (오늘 포함)
    final satisfied = rawLeft < 0.06 && (info.isToday || info.finalT != null);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: UnwindColors.window(light),
        borderRadius: BorderRadius.circular(UnwindRadius.xs),
        border: Border.all(
          color: selected ? UnwindColors.accent : UnwindColors.border,
          width: selected ? UnwindStroke.base : UnwindStroke.hair,
        ),
      ),
      // 아직 오지 않은 밤에는 얼굴이 없다 — 감은 눈은 "잘 잤다"는 뜻이라
      // 미래 날에 그리면 거짓말이 된다.
      child: info.isFuture
          ? null
          : CustomPaint(
              painter: _WindowFacePainter(
                light: light,
                satisfied: satisfied,
                // 불을 남긴 밤의 흔적 — 오늘 밤은 아직 결과가 없다
                darkCircles: !info.isToday && info.restless,
              ),
            ),
    );
  }
}

/// 창 안의 눈 — 그날 밤의 Todd.
/// light 1.0(대낮같이 밝음) = 무겁게 졸린 실눈 / 0.0(소등) = 감긴 곡선.
/// [satisfied]면 잔잔한 미소도 — "다 끄고 만족스럽게 잤다".
/// [darkCircles]면 감은 눈 밑에 진한 다크서클 — "불을 남긴 채 뒤척인 밤"
/// (개정 2026-08-22: 지난 날의 결과는 창의 밝기가 아니라 이 흔적으로 읽는다).
class _WindowFacePainter extends CustomPainter {
  final double light;
  final bool satisfied;
  final bool darkCircles;

  const _WindowFacePainter({
    required this.light,
    this.satisfied = false,
    this.darkCircles = false,
  });

  /// 밝은 창(조명 색) 위의 눈 — 어두운 잉크
  static Color get _ink => UnwindColors.onAccent;

  /// 캄캄한 창 위의 감긴 눈
  static const _sleepInk = UnwindColors.textMuted;

  /// 다크서클 — Todd 본체(ghost_painter_view)와 같은 음영 주머니 색
  /// (리얼 개정 2026-08-22)
  static const _dcFill = Color(0xFF8B7396);
  static const _dcEdge = Color(0xFF6E5480);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.44;
    final dx = size.width * 0.20; // 눈 간격

    if (light < 0.06) {
      // 만족스럽게 잠든 눈 — 아래로 볼록한 곡선
      final p = Paint()
        ..color = _sleepInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (final dir in [-1, 1]) {
        final ec = Offset(cx + dir * dx, cy);
        // 다크서클을 눈보다 먼저 — 채운 음영 주머니 (본체와 같은 문법,
        // 리얼 개정 2026-08-22 2차: 빗금 없이 음영만. 34px 창에서도 읽히게)
        if (darkCircles) {
          const w = 3.8;
          final topY = ec.dy + 2.4;
          final dipY = ec.dy + 6.4;
          final bag = Path()
            ..moveTo(ec.dx - w, topY)
            ..quadraticBezierTo(ec.dx, dipY, ec.dx + w, topY)
            ..quadraticBezierTo(ec.dx, topY + 0.8, ec.dx - w, topY)
            ..close();
          canvas.drawPath(
            bag,
            Paint()..color = _dcFill.withValues(alpha: 0.6),
          );
          final edge = Path()
            ..moveTo(ec.dx - w, topY)
            ..quadraticBezierTo(ec.dx, dipY, ec.dx + w, topY);
          canvas.drawPath(
            edge,
            Paint()
              ..color = _dcEdge
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..strokeCap = StrokeCap.round,
          );
        }
        final path = Path()
          ..moveTo(ec.dx - 3.2, ec.dy)
          ..quadraticBezierTo(ec.dx, ec.dy + 2.6, ec.dx + 3.2, ec.dy);
        canvas.drawPath(path, p);
      }
      // 살짝 스마일 — 전부 체크하고 잠든 날의 만족
      if (satisfied) {
        final my = size.height * 0.68;
        final smile = Path()
          ..moveTo(cx - 3.4, my)
          ..quadraticBezierTo(cx, my + 2.8, cx + 3.4, my);
        canvas.drawPath(smile, p);
      }
      return;
    }

    // 못 자고 졸린 눈 — 빛이 밝을수록 눈꺼풀이 무겁다 (크게 졸림)
    final drowse = (0.35 + 0.55 * light).clamp(0.0, 0.9);
    final eyeH = 6.4 * (1 - drowse * 0.8); // 실눈으로
    final paint = Paint()..color = _ink;
    for (final dir in [-1, 1]) {
      final ec = Offset(cx + dir * dx, cy);
      canvas.drawOval(
        Rect.fromCenter(center: ec, width: 4.6, height: eyeH),
        paint,
      );
      // 처진 눈꺼풀 선 — 눈 위를 덮는 느낌
      canvas.drawLine(
        Offset(ec.dx - 2.8, ec.dy - eyeH / 2 - 0.6),
        Offset(ec.dx + 2.8, ec.dy - eyeH / 2 - 0.6),
        Paint()
          ..color = _ink.withValues(alpha: 0.45)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_WindowFacePainter old) =>
      old.light != light ||
      old.satisfied != satisfied ||
      old.darkCircles != darkCircles;
}
