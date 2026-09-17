import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 구독 구매 화면의 법률 링크 (App Store 가이드라인 3.1.2 — 2026-09-16 리젝
/// 대응). 자동 갱신 구독을 파는 화면엔 이용약관·개인정보처리방침으로 가는
/// **작동하는 링크**가 있어야 한다.
///
/// 이용약관은 App Store Connect "앱 정보 → 사용권 계약"과 같은 것을 가리켜야
/// 한다 — 지금은 Apple 표준 EULA. 자체 약관(docs/legal/)을 게시하면 ASC와
/// 여기, 앱 설명의 링크를 함께 바꿀 것.
final kTermsOfUseUrl = Uri.parse(
  'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
);

/// ASC "앱 개인정보 → 개인정보 처리방침 URL"과 같은 주소 (Notion 공개 페이지)
final kPrivacyPolicyUrl = Uri.parse(
  'https://ryanyjoh.notion.site/3c98cdcda5128002be86d46d969a9e61',
);

/// 앱 안 Safari 뷰로 연다 — 결제 흐름에서 앱을 떠나지 않게. 실패하면 false.
Future<bool> openLegalLink(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.inAppBrowserView);
  } catch (e) {
    debugPrint('[legal] 링크 열기 실패: $e');
    return false;
  }
}
