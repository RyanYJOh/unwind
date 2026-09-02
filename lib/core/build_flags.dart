/// 빌드 시점에 굳는 플래그 (신설 2026-09-02).
///
/// 런타임 설정이 아니라 `--dart-define`이다 — 유저가 켤 수 있는 스위치가
/// 아니라 **어떤 바이너리인가**를 가른다.
library;

/// App Store 심사 제출용 빌드인가.
///
/// ```bash
/// flutter build ipa --dart-define=REVIEW_BUILD=true
/// ```
///
/// 켜지면 온보딩의 앱스토어 별점 팝업을 건너뛴다 (§8.5 — 온보딩 중 평점
/// 요구로 리젝, 2026-09-02). 기본값 false라 평소 개발·배포 빌드는 그대로다.
///
/// ⚠️ 심사에 통과한 바이너리가 곧 스토어에 나가는 바이너리다 — 이 플래그로
/// 구운 빌드를 그대로 출시하면 유저에게도 별점 팝업이 안 뜬다.
const bool kReviewBuild = bool.fromEnvironment('REVIEW_BUILD');
