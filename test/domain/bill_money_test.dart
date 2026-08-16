import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/domain/services/bill_money.dart';

void main() {
  group('BillCurrency.forCountry', () {
    test('한국은 원, 그 외는 현지 통화', () {
      expect(BillCurrency.forCountry('KR'), BillCurrency.krw);
      expect(BillCurrency.forCountry('US'), BillCurrency.usd);
      expect(BillCurrency.forCountry('DE'), BillCurrency.eur);
      expect(BillCurrency.forCountry('JP'), BillCurrency.jpy);
      expect(BillCurrency.forCountry('ZZ'), BillCurrency.usd);
    });

    test('앱 언어 ko + 나라 없음 → KRW', () {
      expect(
        BillCurrency.forLocales(
          app: const Locale('ko'),
          device: const Locale('ko'),
        ),
        BillCurrency.krw,
      );
    });

    test('앱 언어 en + 기기 DE → EUR', () {
      expect(
        BillCurrency.forLocales(
          app: const Locale('en'),
          device: const Locale('de', 'DE'),
        ),
        BillCurrency.eur,
      );
    });
  });

  group('charge · format', () {
    test('KRW: 0.42 kWh → 60원 / ₩60', () {
      expect(BillCurrency.krw.charge(0.42), 60);
      expect(BillCurrency.krw.format(60, languageCode: 'ko'), '60원');
      expect(BillCurrency.krw.format(60, languageCode: 'en'), '₩60');
    });

    test('USD: 0.42 kWh → \$0.07', () {
      expect(BillCurrency.usd.charge(0.42), closeTo(0.07, 1e-9));
      expect(BillCurrency.usd.format(0.07), r'$0.07');
    });

    test('0 kWh는 0', () {
      expect(BillCurrency.usd.charge(0), 0);
      expect(BillCurrency.usd.format(0), r'$0.00');
      expect(BillCurrency.krw.format(0, languageCode: 'en'), '₩0');
    });
  });
}
