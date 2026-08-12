import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/tokens/motion.dart';
import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/repositories/bill_repository.dart';
import '../../domain/services/bill_calculator.dart';
import '../../ui/ui.dart';
import '../today/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// 영수증 종이 팔레트 — 앱에서 유일하게 밝은 표면이다.
/// 청구서는 공유되는 이미지라 **이미지 단독으로 성립해야** 하므로
/// 다크 팔레트를 따르지 않는다 (§6.5).
abstract final class _Paper {
  static const bg = Color(0xFFFFFDF6);
  static const ink = Color(0xFF241C10);
  static const inkSoft = Color(0xFF6B5B45);
  static const inkFaint = Color(0xFF9C8B72);
  static const rule = Color(0xFFDCD0BB);
  static const mark = Color(0xFFE09512); // 소등한 밤 표시 (앰버 계열)
}

/// §6.5 주간 청구서 — 영수증 형태. §9.4: 위에서 내려옴 600ms settle.
Future<void> showBillScreen(BuildContext context, WeeklyBill bill) {
  return Navigator.of(context, rootNavigator: true).push(_BillRoute(bill));
}

class _BillRoute extends PopupRoute<void> {
  final WeeklyBill bill;
  _BillRoute(this.bill);

  @override
  Color? get barrierColor => UnwindColors.scrim;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Close';

  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: UnwindMotion.billEnterMs);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: UnwindMotion.settle)),
      child: BillScreen(bill: bill),
    );
  }
}

class BillScreen extends ConsumerStatefulWidget {
  final WeeklyBill bill;
  const BillScreen({super.key, required this.bill});

  @override
  ConsumerState<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends ConsumerState<BillScreen> {
  final _receiptKey = GlobalKey();
  WeeklyBill? _previous;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(billRepositoryProvider);
    repo.markRead(widget.bill.weekStart); // 배지 해제
    repo.getLatestBefore(widget.bill.weekStart).then((p) {
      if (mounted) setState(() => _previous = p);
    });
  }

  /// §6.5 공유: RepaintBoundary → PNG → share_plus.
  /// 이미지 단독으로 성립해야 한다 — 앱의 주요 유통 자산.
  Future<void> _share() async {
    final boundary =
        _receiptKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.view(bytes.buffer),
            mimeType: 'image/png',
            name: 'unwind-bill-${widget.bill.weekStart}.png',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bill = widget.bill;
    final days = decodeBillPayload(bill.payload);
    final monday = parseDayKey(bill.weekStart);
    final sunday = addDays(monday, 6);
    final months = l10n.monthsShort.split(',');

    return UnwindScreen(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(UnwindSpacing.s24),
              child: RepaintBoundary(
                key: _receiptKey,
                child: _Receipt(
                  bill: bill,
                  days: days,
                  previous: _previous,
                  periodLabel:
                      '${l10n.monthDay(months[monday.month - 1], monday.month, monday.day)}'
                      ' – '
                      '${l10n.monthDay(months[sunday.month - 1], sunday.month, sunday.day)}',
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              UnwindSpacing.s20,
              0,
              UnwindSpacing.s20,
              UnwindSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UnwindButton(label: l10n.share, onPressed: _share),
                const SizedBox(height: UnwindSpacing.s8),
                UnwindButton.ghost(
                  label: l10n.close,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 영수증 본체 — 문구 톤 (§6.5): 사실만 진술, 탓하지 않는다.
class _Receipt extends StatelessWidget {
  final WeeklyBill bill;
  final List<DayBill> days;
  final WeeklyBill? previous;
  final String periodLabel;

  const _Receipt({
    required this.bill,
    required this.days,
    required this.previous,
    required this.periodLabel,
  });

  TextStyle get _mono => UnwindType.mono.copyWith(color: _Paper.ink);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final weekdayLabels = l10n.weekdaysShort.split(',');
    final avgSleep = (bill.sleepMinutes / 7).round();
    final nights = days.where((d) => d.lightsOut).length;
    final diff = previous != null ? bill.amount - previous!.amount : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _Paper.bg,
        borderRadius: BorderRadius.circular(UnwindRadius.md),
        boxShadow: const [
          // §11 — 블러 없는 압출면
          BoxShadow(
            color: UnwindColors.solid,
            offset: Offset(0, UnwindDepth.base),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(UnwindSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.billTitle,
              textAlign: TextAlign.center,
              style: UnwindType.label.copyWith(color: _Paper.inkSoft),
            ),
            const SizedBox(height: UnwindSpacing.s4),
            Text(
              periodLabel,
              textAlign: TextAlign.center,
              style: UnwindType.caption.copyWith(color: _Paper.inkFaint),
            ),
            const SizedBox(height: UnwindSpacing.s16),
            const _DashedDivider(),
            const SizedBox(height: UnwindSpacing.s16),
            // 주간 총액 — 모노스페이스 (§6.5)
            Text(
              l10n.wonAmount(_formatWon(bill.amount)),
              textAlign: TextAlign.center,
              style: _mono.copyWith(fontSize: 34, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: UnwindSpacing.s4),
            Text(
              l10n.billTotalCaption(
                bill.kwh.toStringAsFixed(2),
                l10n.wonAmount('$kBaseFee'),
              ),
              textAlign: TextAlign.center,
              style: UnwindType.caption.copyWith(color: _Paper.inkFaint),
            ),
            const SizedBox(height: UnwindSpacing.s16),
            const _DashedDivider(),
            const SizedBox(height: UnwindSpacing.s12),
            // 일별 명세
            for (var i = 0; i < days.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: UnwindSpacing.s4),
                child: Row(
                  children: [
                    Text(
                      weekdayLabels[i],
                      style: UnwindType.caption.copyWith(color: _Paper.inkSoft),
                    ),
                    const SizedBox(width: UnwindSpacing.s12),
                    // 소등한 밤 표시 — 점 하나 (숫자·등급 금지)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: days[i].lightsOut ? _Paper.mark : _Paper.rule,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${days[i].kwh.toStringAsFixed(2)} kWh',
                      style: _mono.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: UnwindSpacing.s12),
            const _DashedDivider(),
            const SizedBox(height: UnwindSpacing.s16),
            // Lumi 수면 요약 — 서술형만 (§6.5)
            Text(
              _sleepText(l10n, sleepGrade(avgSleep)),
              style: UnwindType.bodyStrong.copyWith(color: _Paper.ink),
            ),
            const SizedBox(height: UnwindSpacing.s4),
            Text(
              nights > 0 ? l10n.nightsOut(nights) : l10n.allNightsLit,
              style: UnwindType.label.copyWith(color: _Paper.inkSoft),
            ),
            if (diff != null) ...[
              const SizedBox(height: UnwindSpacing.s8),
              Text(
                diff == 0
                    ? l10n.diffSame
                    : diff < 0
                    ? l10n.diffLess(l10n.wonAmount(_formatWon(-diff)))
                    : l10n.diffMore(l10n.wonAmount(_formatWon(diff))),
                style: UnwindType.caption.copyWith(color: _Paper.inkFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _sleepText(AppLocalizations l10n, SleepGrade grade) => switch (grade) {
    SleepGrade.deep => l10n.sleepDeep,
    SleepGrade.well => l10n.sleepWell,
    SleepGrade.tossed => l10n.sleepTossed,
    SleepGrade.barely => l10n.sleepBarely,
    SleepGrade.none => l10n.sleepNone,
  };

  String _formatWon(int won) {
    final s = won.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = (constraints.maxWidth / 8).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < count; i++)
            const SizedBox(
              width: 4,
              height: 1,
              child: ColoredBox(color: _Paper.rule),
            ),
        ],
      );
    },
  );
}
