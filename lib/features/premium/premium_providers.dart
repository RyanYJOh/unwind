import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import 'purchases_service.dart';

/// 수익화 원칙 (발주자 컨펌 2026-08-22, prd-amendments):
/// **의식(하루 닫기)은 무료로 완전하게, 관계·표현은 유료로.**
/// 무료 티어의 유일한 사용량 게이트가 반복 규칙 한도다 — 가벼운 유저는
/// 평생 안 부딪히고, 습관을 여럿 돌리는 파워 유저만 만나는 벽이라
/// "다그치지 않는다"(§1)와 충돌이 가장 적다.
const kFreeRecurrenceLimit = 3;

/// Todd Plus 여부 — 설정 키(premiumEnabled)를 읽는다. 이 값은 RevenueCat
/// 엔타이틀먼트 `todd_pro`의 캐시이고, [premiumMirrorProvider]가 맞춘다.
/// 게이트들은 전부 이 값만 보므로 결제 방식이 바뀌어도 화면 코드는 그대로다.
final premiumProvider = Provider<bool>(
  (ref) =>
      ref.watch(settingsControllerProvider).value?.premiumEnabled ?? false,
);

/// RevenueCat 창구 — 테스트는 가짜로 override한다.
final purchasesServiceProvider = Provider<PurchasesService>(
  (ref) => PurchasesService.shared,
);

/// `todd_pro` 활성 여부 (RevenueCat CustomerInfo 흐름). 결제가 꺼진
/// 환경에선 값이 오지 않는다.
final proEntitlementProvider = StreamProvider<bool>(
  (ref) => ref.watch(purchasesServiceProvider).proEntitlement,
);

/// 엔타이틀먼트 → 로컬 캐시(premiumEnabled) 미러 (2026-09-15).
/// UnwindApp 루트가 watch한다. RevenueCat이 답을 줬고 캐시와 다를 때만
/// 쓴다 — 오프라인·테스트처럼 답이 없으면 캐시를 그대로 둔다. 만료·환불도
/// 여기서 꺼진다 (저장된 조명 색·위젯 배경은 남는다, §8.7).
final premiumMirrorProvider = Provider<void>((ref) {
  final active = ref.watch(proEntitlementProvider).value;
  final stored = ref.watch(
    settingsControllerProvider.select((s) => s.value?.premiumEnabled),
  );
  if (active == null || stored == null || active == stored) return;
  final ctrl = ref.read(settingsControllerProvider.notifier);
  // 빌드 중에 다른 프로바이더를 바꾸지 않는다
  Future.microtask(() => ctrl.setPremiumEnabled(active));
});
