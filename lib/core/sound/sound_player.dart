import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'sound.dart';

/// §9.3 사운드 재생.
/// - iOS 무음 스위치 존중: AVAudioSession ambient 카테고리
/// - 에셋은 -18dB 기준으로 미리 렌더링됨 (assets/sound/*.wav)
/// - 테스트/시뮬레이터 등 플랫폼 채널이 없는 환경에서도 죽지 않아야 한다.
class SoundPlayer {
  bool enabled;
  final Map<String, AudioPlayer> _players = {};
  bool _initialized = false;

  SoundPlayer({this.enabled = true});

  static const _noteAssets = <String, String>{
    'C5': 'sound/note_c5.wav',
    'A4': 'sound/note_a4.wav',
    'F4': 'sound/note_f4.wav',
    'D4': 'sound/note_d4.wav',
    'C4': 'sound/note_c4.wav',
    'C3': 'sound/note_c3.wav',
  };
  static const _clickAsset = 'sound/click.wav';

  Future<void> init() async {
    if (_initialized) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {},
          ),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      for (final asset in [..._noteAssets.values, _clickAsset]) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setSourceAsset(asset);
        await p.setReleaseMode(ReleaseMode.stop);
        _players[asset] = p;
      }
      _initialized = true;
    } catch (e) {
      // 사운드 없이도 앱은 동작해야 한다.
      debugPrint('SoundPlayer init failed (non-fatal): $e');
    }
  }

  Future<void> _play(String asset) async {
    if (!enabled || !_initialized) return;
    final p = _players[asset];
    if (p == null) return;
    try {
      await p.stop();
      await p.resume();
    } catch (e) {
      debugPrint('SoundPlayer play failed (non-fatal): $e');
    }
  }

  /// 개별 체크의 짧은 딸깍 (§9.2)
  Future<void> click() => _play(_clickAsset);

  /// 소등 도미노 k번째 등의 음 (§9.3) — 반음계 하강, 5음 순환
  Future<void> dominoNote(int index) => _play(
    _noteAssets[UnwindSound.dominoNotes[index %
        UnwindSound.dominoNotes.length]]!,
  );

  /// 마지막 등 — 항상 가장 낮은 음 C3 (§9.3)
  Future<void> lastNote() => _play(_noteAssets[UnwindSound.lastNote]!);

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    _players.clear();
    _initialized = false;
  }
}
