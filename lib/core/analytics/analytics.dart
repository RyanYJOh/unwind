import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

import '../utils/dates.dart';

/// Mixpanel 애널리틱스 (Quick Start 2026-08-22, §8.8).
///
/// - **릴리즈 빌드에서만 전송한다** — 프로젝트(토큰)가 하나뿐이라 디버그
///   세션이 프로덕션 데이터를 오염시키지 않게 여기서 가른다. 디버그에선
///   이벤트를 debugPrint로만 흘려 무엇이 나갈지 확인할 수 있다.
/// - 계정·로그인이 없는 로컬 온리 앱이라 identify/reset은 쓰지 않는다 —
///   Mixpanel이 기기 단위 익명 id를 관리한다.
/// - 이벤트·프로퍼티 이름은 snake_case, 숫자 값은 문자열로 감싸지 말 것,
///   이름을 런타임에 조립하지 말 것 (유니크 이벤트 폭발).
abstract final class ToddAnalytics {
  static const _token = '93e612829cbf2a9668b723197952ae5c';

  static Future<Mixpanel>? _mixpanel;

  /// main()에서 한 번 부른다. await하지 않는다 — 앱 시작을 막지 않고,
  /// track()이 내부 Future에 붙어 초기화 완료를 알아서 기다린다.
  static void init() {
    if (!kReleaseMode) return;
    _mixpanel ??= Mixpanel.init(_token, trackAutomaticEvents: false);
  }

  /// dayKey(yyyy-MM-dd) → Mixpanel Date (로컬 자정).
  static DateTime isoDate(String dayKey) => parseDayKey(dayKey);

  /// To-do 관련 이벤트 공용 프로퍼티 (add / toggle).
  static Map<String, dynamic> todoEventProps({
    required String title,
    required String targetDateKey,
    required bool hasMemo,
    required bool isAutoPostpone,
    String? repeatType,
    int? scheduledTimeMinutes,
  }) {
    return {
      'title': title,
      'target_date': isoDate(targetDateKey),
      'has_memo': hasMemo,
      'is_auto_postpone': isAutoPostpone,
      'repeat_type': ?repeatType,
      if (scheduledTimeMinutes != null)
        'time': timeOfDay(
          scheduledTimeMinutes ~/ 60,
          scheduledTimeMinutes % 60,
        ),
    };
  }

  /// Mixpanel Date 프로퍼티용 시각. Mixpanel은 시각-only 타입이 없어
  /// DateTime을 보내고, 날짜는 당일(로컬)을 쓴다 — 의미는 시각이다.
  static DateTime timeOfDay(int hour, [int minute = 0]) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, hour, minute);
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
