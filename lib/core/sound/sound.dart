/// §9.3 사운드 명세 상수.
/// 하강 음계만 사용한다 — 상승 음계는 각성시키므로 금지.
abstract final class UnwindSound {
  /// 소등 시퀀스: 등마다 한 음씩 반음계 하강. 6개 이상이면 순환.
  static const dominoNotes = <String>['C5', 'A4', 'F4', 'D4', 'C4'];

  /// 마지막 등은 항상 가장 낮은 음.
  static const lastNote = 'C3';

  /// 볼륨 기준 (§9.3) — iOS 무음 스위치 존중(AVAudioSession ambient)
  static const volumeDb = -18;
}
