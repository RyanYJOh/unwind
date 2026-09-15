import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/push/push.dart';
import '../../core/tokens/palette.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../ui/ui.dart';

/// OneSignal 연동 확인 시트 (2026-09-15, OneSignal 통합 가이드 요구).
///
/// 서버가 구독 ID를 발급하면(= 기기 등록 성공) 프로세스당 한 번 뜨고,
/// "Got it"이 푸시 권한을 묻는다. **디버그 빌드 전용** — 개발자 확인용
/// 스캐폴드라 TestFlight·App Store 유저에게는 절대 보이지 않는다
/// (§10 첫 실행 권한 요청 금지와 충돌하므로). 문구도 그래서 영어 고정.
class PushVerification {
  static bool _shown = false;

  /// OneSignal은 옵저버를 약하게 쥔다는 가이드 요구 — State 필드로 보관한다.
  PushIdObserver? _observer;

  static bool _isRegistered(String? id) =>
      id != null && id.isNotEmpty && !id.startsWith('local-');

  void attach(State state) {
    if (!kDebugMode) return;
    _observer = (id) => _maybeShow(state, id);
    ToddPush.addPushSubscriptionObserver(_observer!);
    // 옵저버가 붙기 전에 이미 발급됐을 수 있다 — 지금 값도 바로 본다.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShow(state, ToddPush.pushSubscriptionId),
    );
  }

  void detach() {
    final observer = _observer;
    if (observer != null) ToddPush.removePushSubscriptionObserver(observer);
    _observer = null;
  }

  void _maybeShow(State state, String? id) {
    if (_shown || !_isRegistered(id) || !state.mounted) return;
    _shown = true;
    showUnwindSheet<void>(
      state.context,
      builder: (ctx) => UnwindSheet(
        title: 'Your OneSignal SDK integration is complete!',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You can now send Push Notifications & In-App Messages '
              'through OneSignal. Tap below to enable push notifications.',
              style: UnwindType.body.copyWith(
                color: UnwindColors.textSecondary,
              ),
            ),
            const SizedBox(height: UnwindSpacing.s20),
            UnwindButton(
              label: 'Got it',
              onPressed: () {
                Navigator.of(ctx).pop();
                ToddPush.requestPermission();
              },
            ),
          ],
        ),
      ),
    );
  }
}
