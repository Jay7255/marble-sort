import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Short sound effects and haptics. Sounds live in assets/sounds/.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  bool enabled = true;
  final List<AudioPlayer> _pool = [];
  int _next = 0;

  Future<void> init() async {
    for (var i = 0; i < 6; i++) {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      _pool.add(p);
    }
  }

  void _play(String file, {double volume = 1}) {
    if (!enabled || _pool.isEmpty) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    p.play(AssetSource('sounds/$file'), volume: volume).catchError((_) {});
  }

  void pick() {
    _play('pick.wav', volume: .6);
    HapticFeedback.selectionClick();
  }

  void clink(int slot) {
    _play('clink${slot.clamp(0, 3)}.wav', volume: .8);
    HapticFeedback.lightImpact();
  }

  void bad() {
    _play('bad.wav', volume: .5);
    HapticFeedback.heavyImpact();
  }

  void cork() {
    _play('cork.wav');
    HapticFeedback.mediumImpact();
  }

  void win() {
    _play('win.wav');
    HapticFeedback.heavyImpact();
  }

  void coin() => _play('coin.wav', volume: .6);
  void star() => _play('star.wav', volume: .7);
  void start() => _play('start.wav', volume: .5);
  void pop() => _play('pop.wav', volume: .7);
}
