/// §7.2 Lumi 인터페이스 — 최종 에셋(또는 Rive)으로 교체할 때도 이 인터페이스를
/// 유지한다. LumiView는 이 상태만 받아 렌더링한다.
enum LumiEvent { blink, yawn, react, fallAsleep }

class LumiState {
  /// 0.0 ~ 1.0, 조도 엔진에서 주입
  final double brightness;

  /// 전등 줄을 당긴 후 true
  final bool isAsleep;

  /// 외부에서 주입하는 이벤트 (react 등). 같은 이벤트를 연속 발생시키기 위해
  /// [eventTick]이 바뀔 때마다 재생한다.
  final LumiEvent? event;
  final int eventTick;

  const LumiState({
    required this.brightness,
    this.isAsleep = false,
    this.event,
    this.eventTick = 0,
  });
}
