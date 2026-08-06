import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/unwind_theme.dart';
import '../../core/tokens/color_ramp.dart';
import '../../core/tokens/motion.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/repositories/bill_repository.dart';
import '../../domain/services/bill_calculator.dart';
import '../today/providers.dart';

/// §6.5 주간 청구서 — 영수증 형태. §9.4: 위에서 내려옴 600ms settle.
Future<void> showBillScreen(BuildContext context, WeeklyBill bill) {
  return Navigator.of(context, rootNavigator: true).push(_BillRoute(bill));
}

class _BillRoute extends PopupRoute<void> {
  final WeeklyBill bill;
  _BillRoute(this.bill);

  @override
  Color? get barrierColor => const Color(0x66000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => '닫기';

  @override
  Duration get transitionDuration =>
      const Duration(milliseconds: UnwindMotion.billEnterMs);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return SlideTransition(
      position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: UnwindMotion.settle)),
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
    final boundary = _receiptKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(
          Uint8List.view(bytes.buffer),
          mimeType: 'image/png',
          name: 'unwind-bill-${widget.bill.weekStart}.png',
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    // 청구서는 밝은 종이 — 중립 고정 (조명 연출은 오늘 화면의 독점 권한)
    final colors = lerpRamp(0.0);
    final bill = widget.bill;
    final days = decodeBillPayload(bill.payload);
    final monday = parseDayKey(bill.weekStart);
    final sunday = addDays(monday, 6);

    return UnwindTheme(
      colors: colors,
      child: DefaultTextStyle(
        style: UnwindType.body.copyWith(decoration: TextDecoration.none),
        child: SafeArea(
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
                          '${monday.month}월 ${monday.day}일 – ${sunday.month}월 ${sunday.day}일',
                      colors: colors,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(UnwindSpacing.s16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _BottomButton(label: '공유', onTap: _share, colors: colors),
                    const SizedBox(width: UnwindSpacing.s24),
                    _BottomButton(
                        label: '닫기',
                        onTap: () => Navigator.of(context).pop(),
                        colors: colors),
                  ],
                ),
              ),
            ],
          ),
        ),
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
  final UnwindColors colors;

  const _Receipt({
    required this.bill,
    required this.days,
    required this.previous,
    required this.periodLabel,
    required this.colors,
  });

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  TextStyle get _mono =>
      UnwindType.mono.copyWith(color: colors.textPrimarySnap);

  @override
  Widget build(BuildContext context) {
    final avgSleep = (bill.sleepMinutes / 7).round();
    final nights = days.where((d) => d.lightsOut).length;
    final diff = previous != null ? bill.amount - previous!.amount : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8), // 영수증 종이
        borderRadius: BorderRadius.circular(UnwindRadius.md),
        boxShadow: [
          BoxShadow(
              color: colors.shadow, blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(UnwindSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Unwind 전기요금 청구서',
                textAlign: TextAlign.center,
                style: UnwindType.label.copyWith(
                    color: colors.textSecondary,
                    decoration: TextDecoration.none)),
            const SizedBox(height: UnwindSpacing.s4),
            Text(periodLabel,
                textAlign: TextAlign.center,
                style: UnwindType.caption.copyWith(
                    color: colors.textMuted,
                    decoration: TextDecoration.none)),
            const SizedBox(height: UnwindSpacing.s16),
            _dashedDivider(),
            const SizedBox(height: UnwindSpacing.s16),
            // 주간 총액 — 모노스페이스 (§6.5)
            Text('${_formatWon(bill.amount)}원',
                textAlign: TextAlign.center,
                style: _mono.copyWith(
                    fontSize: 34, fontWeight: FontWeight.w600)),
            const SizedBox(height: UnwindSpacing.s4),
            Text('총 ${bill.kwh.toStringAsFixed(2)} kWh · 기본료 $kBaseFee원 포함',
                textAlign: TextAlign.center,
                style: UnwindType.caption.copyWith(
                    color: colors.textMuted,
                    decoration: TextDecoration.none)),
            const SizedBox(height: UnwindSpacing.s16),
            _dashedDivider(),
            const SizedBox(height: UnwindSpacing.s12),
            // 일별 명세
            for (var i = 0; i < days.length; i++)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: UnwindSpacing.s4),
                child: Row(
                  children: [
                    Text(_weekdayLabels[i],
                        style: UnwindType.caption.copyWith(
                            color: colors.textSecondary,
                            decoration: TextDecoration.none)),
                    const SizedBox(width: UnwindSpacing.s12),
                    // 소등한 밤 표시 — 점 하나 (숫자·등급 금지)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: days[i].lightsOut
                            ? colors.lamp
                            : colors.border,
                      ),
                    ),
                    const Spacer(),
                    Text('${days[i].kwh.toStringAsFixed(2)} kWh',
                        style: _mono.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            const SizedBox(height: UnwindSpacing.s12),
            _dashedDivider(),
            const SizedBox(height: UnwindSpacing.s16),
            // Lumi 수면 요약 — 서술형만 (§6.5)
            Text('Lumi는 ${sleepGrade(avgSleep)}',
                style: UnwindType.bodyStrong.copyWith(
                    color: colors.textPrimarySnap,
                    decoration: TextDecoration.none)),
            const SizedBox(height: UnwindSpacing.s4),
            Text(
                nights > 0
                    ? '이번 주엔 $nights일 밤 불을 껐어요'
                    : '이번 주의 밤은 모두 불이 켜져 있었어요',
                style: UnwindType.label.copyWith(
                    color: colors.textSecondary,
                    decoration: TextDecoration.none)),
            if (diff != null) ...[
              const SizedBox(height: UnwindSpacing.s8),
              Text(
                  diff == 0
                      ? '지난주와 같은 요금이에요'
                      : diff < 0
                          ? '지난주보다 ${_formatWon(-diff)}원 적어요'
                          : '지난주보다 ${_formatWon(diff)}원 많아요',
                  style: UnwindType.caption.copyWith(
                      color: colors.textMuted,
                      decoration: TextDecoration.none)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dashedDivider() => LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints.maxWidth / 8).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < count; i++)
                Container(width: 4, height: 1, color: colors.border),
            ],
          );
        },
      );

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

class _BottomButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final UnwindColors colors;

  const _BottomButton(
      {required this.label, required this.onTap, required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: UnwindSpacing.s16, vertical: UnwindSpacing.s8),
        child: Text(label,
            style: UnwindType.bodyStrong.copyWith(
                color: label == '공유'
                    ? colors.lamp
                    : colors.textSecondary,
                decoration: TextDecoration.none)),
      ),
    );
  }
}
