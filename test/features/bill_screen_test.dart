import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/features/bill/bill_screen.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/l10n/generated/app_localizations.dart';

/// §6.5 청구서 화면 — 영수증 렌더링 + 문구 톤 스모크
void main() {
  testWidgets('영수증: 총액·일별 명세·수면 서술·읽음 처리', (tester) async {
    final db = UnwindDatabase.withExecutor(NativeDatabase.memory());

    final payload = jsonEncode([
      for (var i = 0; i < 7; i++)
        {
          'date': '2026-07-2${7 + i > 9 ? 7 : 7 + i}',
          'kwh': 0.42,
          'lightsOut': i < 4, // 4일 밤 불을 껐다
          'sleepMinutes': i < 4 ? 450 : 0,
        }
    ]);
    await db.billDao.insertBill(WeeklyBillsCompanion.insert(
      weekStart: '2026-07-27',
      kwh: 2.94,
      amount: 1180,
      sleepMinutes: 1800,
      generatedAt: DateTime(2026, 8, 3, 9),
      isRead: false,
      payload: payload,
    ));
    final bill = (await db.billDao.getBill('2026-07-27'))!;

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BillScreen(bill: bill),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // 주간 총액 (모노스페이스) + 일별 명세 + 서술형 문구
    expect(find.text('₩1,180'), findsOneWidget);
    expect(find.text('You turned the lights out on 4 nights this week'),
        findsOneWidget);
    // 수면 평균 1800/7 ≈ 257분(4.3h) → '조금 뒤척였어요'
    expect(find.text('Lumi tossed and turned a little'), findsOneWidget);
    // 퍼센트·점수·등급 문자열이 없어야 한다 (§1.3)
    expect(find.textContaining('%'), findsNothing);

    // 열람 → 읽음 처리 (§6.5 배지 해제)
    await tester.pump(const Duration(milliseconds: 100));
    expect((await db.billDao.getBill('2026-07-27'))!.isRead, true);

    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
