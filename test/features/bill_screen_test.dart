import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/domain/services/bill_money.dart';
import 'package:unwind/features/bill/bill_screen.dart';
import 'package:unwind/features/today/providers.dart';
import 'package:unwind/l10n/generated/app_localizations.dart';

/// §6.5 청구서 화면 — 영수증 렌더링 + 문구 톤 스모크
void main() {
  testWidgets('영수증: 완수·총액·일별 요금·Todd 상태·읽음 처리', (tester) async {
    final db = UnwindDatabase.withExecutor(NativeDatabase.memory());

    final payload = jsonEncode({
      'completed': 12,
      'total': 18,
      'sleepScore': 0.71,
      'days': [
        for (var i = 0; i < 7; i++)
          {
            'date': '2026-07-${27 + i}',
            'kwh': i == 2 ? 0.42 : 0.0,
            'lightsOut': i != 2,
            'sleepMinutes': i != 2 ? 420 : 0,
            'leftover': i == 2 ? 1 : 0,
            'amount': i == 2 ? 64 : 0,
            'sleepScore': i != 2 ? 1 : 0,
          },
      ],
    });
    await db.billDao.insertBill(
      WeeklyBillsCompanion.insert(
        weekStart: '2026-07-27',
        kwh: 0.42,
        amount: 60,
        sleepMinutes: 2520,
        generatedAt: DateTime(2026, 8, 3, 9),
        isRead: false,
        payload: payload,
      ),
    );
    final bill = (await db.billDao.getBill('2026-07-27'))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BillScreen(bill: bill, currency: BillCurrency.usd),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('12 / 18'), findsOneWidget);
    expect(find.text(r'$3.36'), findsWidgets);
    expect(find.text('Todd tossed and turned a little'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    expect((await db.billDao.getBill('2026-07-27'))!.isRead, true);

    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  testWidgets('월요일이 아니면 같은 영수증에 안내', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBillMondayOnly(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Weekly Electric Bill'), findsOneWidget);
    expect(find.text('The bill opens on Mondays'), findsOneWidget);
    expect(
      find.text("Meanwhile, let's smash\nthis week's to-dos!"),
      findsOneWidget,
    );
    expect(find.text('Share'), findsNothing);
  });
}
