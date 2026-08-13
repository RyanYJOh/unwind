import 'package:flutter/widgets.dart';

import '../../core/utils/dates.dart';
import '../today/providers.dart' show weekMondayKey;
import '../../l10n/generated/app_localizations.dart';

/// 주를 사람 말로 부르는 이름 — "이번 주" / "지난주" / "8월 4일 ~ 8월 10일".
///
/// **하단 스트립의 칩과 주간 뷰의 제목이 같은 함수를 쓴다** (개편 2026-08-13).
/// 칩엔 "지난주"라 써 놓고 페이지 제목은 "Week 32"면 어느 주를 보고 있는지
/// 헷갈린다 — 이름은 한 곳에서만 만든다.
String weekLabel(
  BuildContext context, {
  required String mondayKey,
  required String todayKey,
}) {
  final l10n = AppLocalizations.of(context);
  final thisMonday = parseDayKey(weekMondayKey(todayKey));
  final monday = parseDayKey(mondayKey);
  final offset = monday.difference(thisMonday).inDays ~/ 7;

  switch (offset) {
    case 0:
      return l10n.thisWeek;
    case -1:
      return l10n.lastWeek;
    case 1:
      return l10n.nextWeek;
  }

  final months = l10n.monthsShort.split(',');
  String short(DateTime d) =>
      l10n.monthDay(months[d.month - 1], d.month, d.day);
  return l10n.weekRange(short(monday), short(addDays(monday, 6)));
}
