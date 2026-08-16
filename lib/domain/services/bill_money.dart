import 'package:flutter/widgets.dart';

/// 청구서 표시 통화 — 기기 지역을 따른다. 단가는 대략치(재미 요소).
/// kWh는 그대로 두고, 보여줄 때만 여기서 곱한다.
class BillCurrency {
  final String code;
  final String symbol;
  final double pricePerKwh;
  final int decimals;

  /// 있으면 이 단위로 반올림 (KRW 10원).
  final int? roundTo;

  const BillCurrency({
    required this.code,
    required this.symbol,
    required this.pricePerKwh,
    required this.decimals,
    this.roundTo,
  });

  static const krw = BillCurrency(
    code: 'KRW',
    symbol: '₩',
    pricePerKwh: 152,
    decimals: 0,
    roundTo: 10,
  );
  static const usd = BillCurrency(
    code: 'USD',
    symbol: r'$',
    pricePerKwh: 0.16,
    decimals: 2,
  );
  static const eur = BillCurrency(
    code: 'EUR',
    symbol: '€',
    pricePerKwh: 0.28,
    decimals: 2,
  );
  static const gbp = BillCurrency(
    code: 'GBP',
    symbol: '£',
    pricePerKwh: 0.24,
    decimals: 2,
  );
  static const jpy = BillCurrency(
    code: 'JPY',
    symbol: '¥',
    pricePerKwh: 30,
    decimals: 0,
  );
  static const cny = BillCurrency(
    code: 'CNY',
    symbol: 'CN¥',
    pricePerKwh: 0.60,
    decimals: 2,
  );
  static const aud = BillCurrency(
    code: 'AUD',
    symbol: r'A$',
    pricePerKwh: 0.30,
    decimals: 2,
  );
  static const cad = BillCurrency(
    code: 'CAD',
    symbol: r'CA$',
    pricePerKwh: 0.15,
    decimals: 2,
  );
  static const inr = BillCurrency(
    code: 'INR',
    symbol: '₹',
    pricePerKwh: 8,
    decimals: 0,
  );
  static const twd = BillCurrency(
    code: 'TWD',
    symbol: r'NT$',
    pricePerKwh: 3.5,
    decimals: 1,
  );
  static const hkd = BillCurrency(
    code: 'HKD',
    symbol: r'HK$',
    pricePerKwh: 1.3,
    decimals: 2,
  );
  static const sgd = BillCurrency(
    code: 'SGD',
    symbol: r'S$',
    pricePerKwh: 0.28,
    decimals: 2,
  );

  static const _eurozone = {
    'AT',
    'BE',
    'CY',
    'DE',
    'EE',
    'ES',
    'FI',
    'FR',
    'GR',
    'HR',
    'IE',
    'IT',
    'LT',
    'LU',
    'LV',
    'MT',
    'NL',
    'PT',
    'SI',
    'SK',
  };

  /// 앱 언어에는 나라가 없고(`Locale('en')`), 통화는 기기 지역을 본다.
  static BillCurrency resolve(BuildContext context) {
    final app = Localizations.localeOf(context);
    final device = View.of(context).platformDispatcher.locale;
    return forLocales(app: app, device: device);
  }

  static BillCurrency forLocales({
    required Locale app,
    required Locale device,
  }) {
    final country =
        device.countryCode ??
        app.countryCode ??
        (app.languageCode == 'ko' ? 'KR' : 'US');
    return forCountry(country);
  }

  static BillCurrency forCountry(String country) {
    final c = country.toUpperCase();
    if (c == 'KR') return krw;
    if (c == 'JP') return jpy;
    if (c == 'GB') return gbp;
    if (c == 'CN') return cny;
    if (c == 'AU') return aud;
    if (c == 'CA') return cad;
    if (c == 'IN') return inr;
    if (c == 'TW') return twd;
    if (c == 'HK') return hkd;
    if (c == 'SG') return sgd;
    if (_eurozone.contains(c)) return eur;
    if (c == 'US') return usd;
    return usd;
  }

  double charge(double kwh) {
    final raw = kwh * pricePerKwh;
    if (roundTo != null) {
      return ((raw / roundTo!).round() * roundTo!).toDouble();
    }
    var f = 1;
    for (var i = 0; i < decimals; i++) {
      f *= 10;
    }
    return (raw * f).round() / f;
  }

  String format(double amount, {String languageCode = 'en'}) {
    if (code == 'KRW') {
      final n = _group(amount.round());
      return languageCode == 'ko' ? '$n원' : '$symbol$n';
    }
    if (decimals == 0) {
      return '$symbol${_group(amount.round())}';
    }
    final fixed = amount.abs().toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final grouped = _group(int.parse(parts[0]));
    final signed = amount < 0 ? '-' : '';
    return '$signed$symbol$grouped.${parts[1]}';
  }

  static String _group(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return n < 0 ? '-$buf' : buf.toString();
  }
}
