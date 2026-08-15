/// §7.2 Lumi 인터페이스 — 최종 에셋(또는 Rive)으로 교체할 때도 이 인터페이스를
/// 유지한다. LumiView는 이 상태만 받아 렌더링한다.
/// [poke]: 사용자가 Lumi를 톡 건드렸다 (개편 2026-08-12).
/// 반응은 렌더러가 **자기 모드를 보고** 고른다 — 깨어 있으면 간지럼,
/// 졸리면 실눈으로 두리번, 잠들었으면 무반응.
enum LumiEvent { blink, yawn, react, fallAsleep, poke }

/// Lumi의 하루 (개편 2026-08-08) — 시각·체크리스트 상태로 결정되는 생활 모드.
/// - [day]: 낮(기본 06~19시). 행복한 펫 — 2시간마다 일과가 바뀐다.
/// - [nightAwake]: 밤인데 아직 불(할 일)이 남아 못 자는 상태.
///   남은 불이 많을수록 눈이 부시고, 어두워질수록 꾸벅꾸벅 존다.
/// - [asleep]: 모든 체크 완료(시간 무관) / 소등 / 밤의 빈 방 — 만족스러운 잠.
enum LumiMode { day, nightAwake, asleep }

/// 낮 일과 — enum 순서가 곧 하루의 흐름이다 (기상 → 취침).
/// 슬롯은 기상~취침 구간을 활동 개수로 **균등 분할**한다 (개정 2026-08-15:
/// 활동이 10개가 되며 2시간 고정 슬롯으로는 하루에 다 담기지 않는다 —
/// Lumi의 하루 길이에 맞춰 일과가 늘고 준다).
/// 기본(05~22시) 기준: stretch(기지개) → coffee(커피) → read(독서) →
/// doodle(낙서) → walk(산책) → hum(콧노래) → snack(간식) → dance(춤) →
/// bubbles(비눗방울) → rest(취침 전 휴식)
enum LumiDayActivity {
  stretch,
  coffee,
  read,
  doodle,
  walk,
  hum,
  snack,
  dance,
  bubbles,
  rest,
}

class LumiState {
  /// 0.0 ~ 1.0, 조도 엔진에서 주입
  final double brightness;

  /// 잠든 상태 (소등·전체 완료·밤의 빈 방)
  final bool isAsleep;

  /// 생활 모드. null이면 이전 방식(brightness→졸림 매핑)으로 동작한다
  /// — 온보딩 등 모드 개념이 없는 화면의 하위 호환.
  final LumiMode? mode;

  /// [LumiMode.day]일 때의 현재 일과
  final LumiDayActivity? activity;

  /// [LumiMode.nightAwake]일 때 눈부심 정도 (= 방에 남은 빛, 1 - t)
  final double dazzle;

  /// 전날 밤 불을 남긴 채 잤다 (세계관 2026-08-15) — 하루 종일 눈 밑에
  /// 옅은 다크서클이 남는다. 표정·행동은 평소 그대로다.
  final bool darkCircles;

  /// 외부에서 주입하는 이벤트 (react 등). 같은 이벤트를 연속 발생시키기 위해
  /// [eventTick]이 바뀔 때마다 재생한다.
  final LumiEvent? event;
  final int eventTick;

  const LumiState({
    required this.brightness,
    this.isAsleep = false,
    this.mode,
    this.activity,
    this.dazzle = 0.0,
    this.darkCircles = false,
    this.event,
    this.eventTick = 0,
  });
}
