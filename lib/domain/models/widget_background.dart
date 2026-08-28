/// iOS 홈 위젯 배경 (선택형 2026-08-28, 발주자 지시 — 8안 전부 채택).
///
/// 렌더는 두 곳이 미러링한다 — 위젯 본체는 `ios/ToddWidget/ToddWidget.swift`
/// 의 `SceneBackground`, 설정 갤러리 미리보기는
/// `features/settings/widget_background_preview.dart`. **장면을 고치면 두
/// 곳을 함께 고칠 것** (§8.5 팔레트 미러와 같은 계약).
///
/// 설계 규칙 (레퍼런스 조사 2026-08-28, prd-amendments):
/// - 우상단은 코너 글로우(남은 빛 게이지)의 자리 — 배경의 가장 밝은
///   픽셀은 글로우보다 어두워야 한다.
/// - 좌하단은 언제나 어둠 (§5.1), 하단 중앙은 Todd — 중간톤 이하 유지.
/// - 색이 아니라 **명도 대비**로 구조를 잡는다 (iOS 18 Tinted 모드에서
///   색은 luminanceToAlpha로 뭉갠다).
/// - 채도는 낮게 — 배경이 화려해지면 앰버가 의미를 잃는다.
enum WidgetBackground {
  /// 깊은 밤 — 기본. 기존 ink 그라데이션 + 별 (무료).
  deepNight,

  /// 반딧불이 — 여름밤 숲, 따뜻한 점들. 주제 적합도 1위.
  fireflies,

  /// 창가의 비 — 빗줄기 너머, 차가운 바깥과 따뜻한 안.
  rainWindow,

  /// 큰 달 — 언덕 위, 광학적으로 틀리게 큰 달 (지브리 문법).
  bigMoon,

  /// 밤바다 — 가로 띠 셋과 글로우의 반사 한 줄.
  starrySea,

  /// 첫눈 — 침엽수 실루엣 2겹과 눈, 창문 하나.
  firstSnow,

  /// 오로라 — 초록 아래·보라 위 커튼 (물리를 어기면 가짜로 보인다).
  aurora,

  /// 몽글몽글 — 자두빛 검정 위 파스텔 (산리오 밤 문법).
  pastelDream,

  /// 이불 속 — 글로우가 배경이 아니라 손전등 그 자체가 되는 안.
  blanketFort;

  /// 설정 문자열 → 배경. 모르는 값(다운그레이드 등)은 기본 깊은 밤.
  static WidgetBackground fromName(String? name) =>
      values.asNameMap()[name] ?? deepNight;

  /// 실제로 위젯에 실어 보낼 배경 — 깊은 밤 외 전부 Todd Plus (§8.7
  /// 게이트 ③). 조명 색과 같은 규칙: 구독이 꺼지면 저장된 선택은 남긴 채
  /// 표시만 기본으로 돌아가고, 재구독하면 되살아난다.
  static WidgetBackground effective({
    required bool premium,
    required String? stored,
  }) => premium ? fromName(stored) : deepNight;
}
