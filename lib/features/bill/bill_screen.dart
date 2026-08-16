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
import '../../domain/models/todd_state.dart';
import '../../domain/services/bill_calculator.dart';
import '../../domain/services/bill_money.dart';
import '../../ui/ui.dart';
import '../../widgets/todd/todd_view.dart';
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
  static const mark = Color(0xFFE09512); // 소등한 밤 · 완벽한 잠 (앰버)
  static const card = Color(0xFFF6EDD8); // Todd 상태 카드
  static const cardEdge = Color(0xFFE8D4A8);
  static const closed = Color(0xFF2F9E5A); // 그날 요금 0
  static const leftover = Color(0xFFE24B3A); // 불을 남긴 밤
}

/// 월요일 외 요일 — 같은 영수증 화면에 안내만 넣는다.
Future<void> showBillMondayOnly(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(_BillRoute());
}

/// §6.5 주간 청구서 — 영수증 형태. §9.4: 위에서 내려옴 600ms settle.
Future<void> showBillScreen(BuildContext context, WeeklyBill bill) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(_BillRoute(bill: bill));
}

class _BillRoute extends PopupRoute<void> {
  final WeeklyBill? bill;
  _BillRoute({this.bill});

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
      child: bill == null ? const _LockedBillScreen() : BillScreen(bill: bill!),
    );
  }
}

class BillScreen extends ConsumerStatefulWidget {
  final WeeklyBill bill;

  /// 테스트용. 없으면 기기 지역 통화.
  final BillCurrency? currency;

  const BillScreen({super.key, required this.bill, this.currency});

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
    final contents = decodeBillPayload(bill.payload);
    final monday = parseDayKey(bill.weekStart);
    final sunday = addDays(monday, 6);
    final months = l10n.monthsShort.split(',');

    return UnwindScreen(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                UnwindSpacing.s16,
                UnwindSpacing.s12,
                UnwindSpacing.s16,
                UnwindSpacing.s8,
              ),
              child: RepaintBoundary(
                key: _receiptKey,
                child: _Receipt(
                  bill: bill,
                  contents: contents,
                  previous: _previous,
                  money: widget.currency ?? BillCurrency.resolve(context),
                  languageCode: Localizations.localeOf(context).languageCode,
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

/// 월요일 외 — 같은 영수증 껍데기에 안내만.
class _LockedBillScreen extends StatelessWidget {
  const _LockedBillScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return UnwindScreen(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(UnwindSpacing.s24),
              child: _ReceiptPaper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.billTitle,
                      textAlign: TextAlign.center,
                      style: UnwindType.label.copyWith(color: _Paper.inkSoft),
                    ),
                    const SizedBox(height: UnwindSpacing.s16),
                    const _DashedDivider(),
                    const SizedBox(height: UnwindSpacing.s32),
                    Text(
                      l10n.billMondayOnly,
                      textAlign: TextAlign.center,
                      style: UnwindType.headline.copyWith(color: _Paper.ink),
                    ),
                    const SizedBox(height: UnwindSpacing.s8),
                    Text(
                      l10n.billMondayOnlyBody,
                      textAlign: TextAlign.center,
                      style: UnwindType.body.copyWith(color: _Paper.inkSoft),
                    ),
                    const SizedBox(height: UnwindSpacing.s32),
                    const _DashedDivider(),
                  ],
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
            child: UnwindButton.ghost(
              label: l10n.close,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 밝은 종이 영수증 껍데기 — 실청구서와 월요일 안내가 공유한다.
class _ReceiptPaper extends StatelessWidget {
  final Widget child;
  const _ReceiptPaper({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _Paper.bg,
        borderRadius: BorderRadius.circular(UnwindRadius.md),
        boxShadow: const [
          BoxShadow(
            color: UnwindColors.solid,
            offset: Offset(0, UnwindDepth.base),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(UnwindSpacing.s20),
        child: child,
      ),
    );
  }
}

/// 영수증 본체 — 문구 톤 (§6.5): 사실만 진술, 탓하지 않는다.
class _Receipt extends StatelessWidget {
  final WeeklyBill bill;
  final BillContents contents;
  final WeeklyBill? previous;
  final BillCurrency money;
  final String languageCode;
  final String periodLabel;

  const _Receipt({
    required this.bill,
    required this.contents,
    required this.previous,
    required this.money,
    required this.languageCode,
    required this.periodLabel,
  });

  TextStyle get _mono => UnwindType.mono.copyWith(color: _Paper.ink);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final weekdayLabels = l10n.weekdaysShort.split(',');
    final days = contents.days;
    final grade = sleepGrade(contents.sleepScore);
    final total = money.charge(bill.kwh);
    final prev = previous == null ? null : money.charge(previous!.kwh);
    final diff = prev == null ? null : total - prev;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return _ReceiptPaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.billTitle,
            textAlign: TextAlign.center,
            style: UnwindType.label.copyWith(color: _Paper.inkSoft),
          ),
          const SizedBox(height: UnwindSpacing.s2),
          Text(
            periodLabel,
            textAlign: TextAlign.center,
            style: UnwindType.caption.copyWith(color: _Paper.inkFaint),
          ),
          const SizedBox(height: UnwindSpacing.s12),
          // 1. Todd 상태 — 카드로 강조
          DecoratedBox(
            decoration: BoxDecoration(
              color: _Paper.card,
              borderRadius: BorderRadius.circular(UnwindRadius.sm),
              border: Border.all(
                color: _Paper.cardEdge,
                width: UnwindStroke.base,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                UnwindSpacing.s12,
                UnwindSpacing.s8,
                UnwindSpacing.s16,
                UnwindSpacing.s8,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: ToddView(
                      size: 72,
                      reduceMotion: reduce,
                      state: _toddStateFor(grade),
                    ),
                  ),
                  const SizedBox(width: UnwindSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sleepText(l10n, grade),
                          style: UnwindType.bodyStrong.copyWith(
                            color: _sleepColor(grade),
                          ),
                        ),
                        if (diff != null) ...[
                          const SizedBox(height: UnwindSpacing.s4),
                          Text(
                            diff == 0
                                ? l10n.diffSame
                                : diff < 0
                                ? l10n.diffLess(
                                    money.format(
                                      -diff,
                                      languageCode: languageCode,
                                    ),
                                  )
                                : l10n.diffMore(
                                    money.format(
                                      diff,
                                      languageCode: languageCode,
                                    ),
                                  ),
                            style: UnwindType.caption.copyWith(
                              color: _Paper.inkFaint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: UnwindSpacing.s12),
          // 2. 완수 — 세 구역 중 가장 낮음
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.billTasksClosed(contents.completed, contents.total),
                style: _mono.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _Paper.inkFaint,
                ),
              ),
              const SizedBox(width: UnwindSpacing.s8),
              Text(
                l10n.billTasksCaption,
                style: UnwindType.caption.copyWith(color: _Paper.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: UnwindSpacing.s12),
          const _DashedDivider(),
          const SizedBox(height: UnwindSpacing.s12),
          // 3. 전기요금 — 메인
          Text(
            money.format(total, languageCode: languageCode),
            textAlign: TextAlign.center,
            style: _mono.copyWith(fontSize: 34, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: UnwindSpacing.s2),
          Text(
            l10n.billTotalCaption(bill.kwh.toStringAsFixed(2)),
            textAlign: TextAlign.center,
            style: UnwindType.caption.copyWith(color: _Paper.inkFaint),
          ),
          const SizedBox(height: UnwindSpacing.s8),
          for (var i = 0; i < days.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: UnwindSpacing.s2),
              child: Row(
                children: [
                  Text(
                    weekdayLabels[i],
                    style: UnwindType.caption.copyWith(color: _Paper.inkSoft),
                  ),
                  const SizedBox(width: UnwindSpacing.s12),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                        color: days[i].lightsOut
                            ? _Paper.closed
                            : _Paper.leftover,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    money.format(
                      money.charge(days[i].kwh),
                      languageCode: languageCode,
                    ),
                    style: _mono.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  ToddState _toddStateFor(SleepGrade grade) => switch (grade) {
    SleepGrade.deep || SleepGrade.well => const ToddState(
      brightness: 1,
      isAsleep: true,
      mode: ToddMode.asleep,
    ),
    SleepGrade.tossed => const ToddState(
      brightness: 0.55,
      mode: ToddMode.nightAwake,
      dazzle: 0.28,
    ),
    SleepGrade.barely => const ToddState(
      brightness: 0.28,
      mode: ToddMode.nightAwake,
      dazzle: 0.58,
    ),
    SleepGrade.none => const ToddState(
      brightness: 0,
      mode: ToddMode.nightAwake,
      dazzle: 0.92,
    ),
  };

  Color _sleepColor(SleepGrade grade) => switch (grade) {
    SleepGrade.deep => _Paper.mark,
    SleepGrade.well => _Paper.ink,
    SleepGrade.tossed => _Paper.inkSoft,
    SleepGrade.barely => _Paper.inkFaint,
    SleepGrade.none => UnwindColors.danger,
  };

  String _sleepText(AppLocalizations l10n, SleepGrade grade) => switch (grade) {
    SleepGrade.deep => l10n.sleepDeep,
    SleepGrade.well => l10n.sleepWell,
    SleepGrade.tossed => l10n.sleepTossed,
    SleepGrade.barely => l10n.sleepBarely,
    SleepGrade.none => l10n.sleepNone,
  };
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
