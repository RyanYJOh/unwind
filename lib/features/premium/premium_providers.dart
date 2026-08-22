import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';

/// 수익화 원칙 (발주자 컨펌 2026-08-22, prd-amendments):
/// **의식(하루 닫기)은 무료로 완전하게, 관계·표현은 유료로.**
/// 무료 티어의 유일한 사용량 게이트가 반복 규칙 한도다 — 가벼운 유저는
/// 평생 안 부딪히고, 습관을 여럿 돌리는 파워 유저만 만나는 벽이라
/// "다그치지 않는다"(§1)와 충돌이 가장 적다.
const kFreeRecurrenceLimit = 3;

/// Todd Plus 여부 — 지금은 설정 키(premiumEnabled) 하나다.
/// TODO(unwind): StoreKit 결제 연동 시 이 프로바이더 뒤에 영수증 검증을
/// 붙인다. 게이트들은 전부 이 값만 보므로 화면 코드는 바뀌지 않는다.
final premiumProvider = Provider<bool>(
  (ref) =>
      ref.watch(settingsControllerProvider).value?.premiumEnabled ?? false,
);
