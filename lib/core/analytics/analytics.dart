import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

/// Mixpanel 애널리틱스 (Quick Start 2026-08-22, §8.8).
///
/// - **릴리즈 빌드에서만 전송한다** — 프로젝트(토큰)가 하나뿐이라 디버그
///   세션이 프로덕션 데이터를 오염시키지 않게 여기서 가른다. 디버그에선
///   이벤트를 debugPrint로만 흘려 무엇이 나갈지 확인할 수 있다.
/// - 계정·로그인이 없는 로컬 온리 앱이라 identify/reset은 쓰지 않는다 —
///   Mixpanel이 기기 단위 익명 id를 관리한다.
/// - 이벤트·프로퍼티 이름은 snake_case, 숫자 값은 문자열로 감싸지 말 것,
///   이름을 런타임에 조립하지 말 것 (유니크 이벤트 폭발).
abstract final class UnwindAnalytics {
  static const _token = '93e612829cbf2a9668b723197952ae5c';

  static Future<Mixpanel>? _mixpanel;

  /// main()에서 한 번 부른다. await하지 않는다 — 앱 시작을 막지 않고,
  /// track()이 내부 Future에 붙어 초기화 완료를 알아서 기다린다.
  static void init() {
    if (!kReleaseMode) return;
    _mixpanel ??= Mixpanel.init(_token, trackAutomaticEvents: false);
  }

  /// 이벤트 하나. 디버그 빌드에선 콘솔 출력만, init 전이면 무시된다.
  static void track(String name, [Map<String, dynamic>? props]) {
    if (!kReleaseMode) {
      debugPrint('[analytics] $name ${props ?? const {}}');
      return;
    }
    _mixpanel?.then((m) => m.track(name, properties: props));
  }

  /// 유저 프로필 프로퍼티 하나 (People). identify 없이 기기 익명 id의
  /// 프로필에 붙는다. 디버그 빌드에선 콘솔 출력만.
  static void setProfile(String key, Object value) {
    if (!kReleaseMode) {
      debugPrint('[analytics] profile $key = $value');
      return;
    }
    _mixpanel?.then((m) => m.getPeople().set(key, value));
  }
}
