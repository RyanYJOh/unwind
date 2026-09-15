import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// RevenueCat 결제 (2026-09-15) — Todd Plus의 **진실은 RevenueCat 엔타이틀먼트
/// `todd_pro`** 다. 화면은 이 서비스만 부르고 SDK 타입을 모른다
/// (페이월은 [PlanOffer]·[PurchaseOutcome]만 본다 — 테스트는 이 클래스를
/// 상속한 가짜로 갈아 끼운다).
///
/// 로컬 설정 `premiumEnabled`는 이제 엔타이틀먼트의 **캐시**다:
/// premium_providers의 미러가 CustomerInfo가 올 때마다 맞춰 쓴다. 오프라인
/// 콜드 스타트·위젯 스냅샷·게이트들은 그 캐시를 그대로 읽는다.
const kProEntitlement = 'todd_pro';

/// ⚠️ Test Store 키 — 디버그·프로필 빌드 전용. RevenueCat 문서: Test Store
/// 키로 구성된 앱을 스토어에 제출하지 말 것. 릴리즈 빌드는
/// `--dart-define=REVENUECAT_API_KEY=appl_…`로 App Store 키를 주입해야 하고,
/// 없으면 결제를 켜지 않는다 (페이월은 "불러오지 못했어" 상태 — 테스트 키가
/// 실수로 심사에 실려 가는 것보다 낫다).
const _testStoreApiKey = 'test_pQhMXnGAyfdWHpUeTzTqwVGcVIN';
const _releaseApiKey = String.fromEnvironment('REVENUECAT_API_KEY');

String? get _apiKey {
  if (_releaseApiKey.isNotEmpty) return _releaseApiKey;
  return kReleaseMode ? null : _testStoreApiKey;
}

/// 페이월의 세 요금제. RevenueCat 상품 id와 1:1 (monthly / yearly / lifetime).
enum ToddPlan {
  monthly('monthly'),
  yearly('yearly'),
  lifetime('lifetime');

  const ToddPlan(this.productId);
  final String productId;
}

/// 요금제 하나의 표시 정보 — 가격은 스토어가 준 현지화 문자열 그대로.
class PlanOffer {
  final ToddPlan plan;
  final String priceString;

  /// 연간의 "한 달에 약 …" 캡션용 (구독 상품만)
  final String? pricePerMonthString;

  /// 실제 구매에 쓰는 RevenueCat 패키지 (가짜 서비스에선 null)
  final Package? package;

  const PlanOffer({
    required this.plan,
    required this.priceString,
    this.pricePerMonthString,
    this.package,
  });
}

/// 구매·복원의 결과 — 화면이 SDK 에러 코드를 몰라도 되게 여기서 접는다.
sealed class PurchaseOutcome {
  const PurchaseOutcome();
}

/// 엔타이틀먼트가 켜졌다 (구매 또는 복원 성공)
class PurchaseSucceeded extends PurchaseOutcome {
  const PurchaseSucceeded();
}

/// 유저가 스스로 닫았다 — 아무 말도 하지 않는다 (§1 다그치지 않는다)
class PurchaseCancelled extends PurchaseOutcome {
  const PurchaseCancelled();
}

/// 결제 승인 대기 (자녀 보호 "구입 요청" 등) — 승인되면 리스너가 켜 준다
class PurchasePending extends PurchaseOutcome {
  const PurchasePending();
}

/// 복원했지만 되살릴 구매가 없다
class NothingToRestore extends PurchaseOutcome {
  const NothingToRestore();
}

class PurchaseFailed extends PurchaseOutcome {
  final String message;
  const PurchaseFailed(this.message);
}

class PurchasesService {
  PurchasesService();

  /// 앱 전체가 공유하는 인스턴스 — main()이 ProviderScope 전에 configure를
  /// 걸고, purchasesServiceProvider가 같은 것을 돌려준다.
  static final shared = PurchasesService();

  Future<bool>? _configuring;
  final _entitlement = StreamController<bool>.broadcast();
  bool? _lastActive;

  /// `todd_pro` 활성 여부의 흐름. 구성 직후 캐시된 CustomerInfo로 한 번,
  /// 이후 구매·복원·갱신·만료·다른 기기 구매가 반영될 때마다 흐른다.
  /// 결제가 꺼진 환경(테스트·키 없는 릴리즈)에선 아무것도 흐르지 않는다 —
  /// 그래서 로컬 캐시를 덮어쓰지 않는다.
  Stream<bool> get proEntitlement async* {
    if (_lastActive != null) yield _lastActive!;
    yield* _entitlement.stream;
  }

  /// 앱 시작 때 한 번 (main에서 fire-and-forget). 멱등 — 모든 메서드가
  /// 먼저 이걸 기다리므로 호출 순서를 신경 쓸 필요가 없다.
  Future<bool> configure() => _configuring ??= _configure();

  Future<bool> _configure() async {
    final key = _apiKey;
    if (key == null) {
      debugPrint('[purchases] 릴리즈 빌드에 REVENUECAT_API_KEY 없음 — 결제 꺼짐');
      return false;
    }
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
      await Purchases.configure(PurchasesConfiguration(key));
      // SDK는 구매·갱신·만료·다른 기기 복원 등 모든 변화를 여기로 흘린다
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
      return true;
    } on MissingPluginException {
      return false; // flutter test — 네이티브 플러그인이 없다
    } catch (e) {
      debugPrint('[purchases] configure 실패: $e');
      return false;
    }
  }

  void _onCustomerInfo(CustomerInfo info) {
    final active = isProActive(info);
    if (active == _lastActive) return;
    _lastActive = active;
    _entitlement.add(active);
  }

  static bool isProActive(CustomerInfo info) =>
      info.entitlements.active.containsKey(kProEntitlement);

  /// 최신 CustomerInfo — SDK 캐시가 있으면 즉시, 오래됐으면 네트워크.
  /// 결제가 꺼져 있거나 실패하면 null.
  Future<CustomerInfo?> customerInfo() async {
    if (!await configure()) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      _onCustomerInfo(info);
      return info;
    } catch (e) {
      debugPrint('[purchases] getCustomerInfo 실패: $e');
      return null;
    }
  }

  /// 현재(current) Offering의 세 요금제. 실패·미구성이면 null —
  /// 페이월은 가짜 가격을 보여주지 않고 다시 시도를 띄운다.
  Future<Map<ToddPlan, PlanOffer>?> loadPlans() async {
    if (!await configure()) return null;
    try {
      final offering = (await Purchases.getOfferings()).current;
      if (offering == null) return null;
      Package? find(ToddPlan plan, Package? byType) =>
          byType ??
          offering.availablePackages
              .where((p) => p.storeProduct.identifier == plan.productId)
              .firstOrNull;
      final plans = <ToddPlan, PlanOffer>{};
      for (final (plan, byType) in [
        (ToddPlan.monthly, offering.monthly),
        (ToddPlan.yearly, offering.annual),
        (ToddPlan.lifetime, offering.lifetime),
      ]) {
        final pkg = find(plan, byType);
        if (pkg == null) continue;
        plans[plan] = PlanOffer(
          plan: plan,
          priceString: pkg.storeProduct.priceString,
          pricePerMonthString: pkg.storeProduct.pricePerMonthString,
          package: pkg,
        );
      }
      return plans.isEmpty ? null : plans;
    } catch (e) {
      debugPrint('[purchases] getOfferings 실패: $e');
      return null;
    }
  }

  Future<PurchaseOutcome> purchase(PlanOffer offer) async {
    final pkg = offer.package;
    if (pkg == null || !await configure()) {
      return const PurchaseFailed('Store unavailable');
    }
    try {
      final result = await Purchases.purchase(PurchaseParams.package(pkg));
      _onCustomerInfo(result.customerInfo);
      return isProActive(result.customerInfo)
          ? const PurchaseSucceeded()
          // 결제는 됐는데 엔타이틀먼트가 안 붙었다 — 대시보드에서 상품이
          // todd_pro에 연결돼 있는지 확인할 것
          : const PurchaseFailed('Entitlement not granted');
    } on PlatformException catch (e) {
      return _fromError(e);
    }
  }

  Future<PurchaseOutcome> restore() async {
    if (!await configure()) return const PurchaseFailed('Store unavailable');
    try {
      final info = await Purchases.restorePurchases();
      _onCustomerInfo(info);
      return isProActive(info)
          ? const PurchaseSucceeded()
          : const NothingToRestore();
    } on PlatformException catch (e) {
      return _fromError(e);
    }
  }

  /// RevenueCat Customer Center — 구독 관리·환불 요청·복원을 한 화면에서.
  /// 반환값: 띄웠으면 true.
  Future<bool> presentCustomerCenter() async {
    if (!await configure()) return false;
    try {
      await RevenueCatUI.presentCustomerCenter();
      // 해지·환불·복원이 있었을 수 있다 — 닫힌 뒤 한 번 동기화
      await customerInfo();
      return true;
    } catch (e) {
      debugPrint('[purchases] Customer Center 실패: $e');
      return false;
    }
  }

  PurchaseOutcome _fromError(PlatformException e) {
    return switch (PurchasesErrorHelper.getErrorCode(e)) {
      PurchasesErrorCode.purchaseCancelledError => const PurchaseCancelled(),
      PurchasesErrorCode.paymentPendingError => const PurchasePending(),
      _ => PurchaseFailed(e.message ?? e.code),
    };
  }
}
