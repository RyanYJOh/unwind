/// Rive 브리프 §6.2 — 이름 계약의 단일 소스.
/// Rive 에디터에서 이름을 바꾸면 이 파일부터 갱신한다.
abstract final class GhostContract {
  static const asset = 'assets/rive/ghost.riv';
  static const artboard = 'Ghost';
  static const stateMachine = 'GhostSM';
  static const vmName = 'GhostVM';
  static const vmSleepiness = 'sleepiness'; // Number 0~100
  static const vmYawn = 'yawn'; // Trigger
  static const vmCheckOff = 'checkOff'; // Trigger
  static const vmAllDone = 'allDone'; // Boolean
  static const vmHappy = 'happy'; // Boolean
}
