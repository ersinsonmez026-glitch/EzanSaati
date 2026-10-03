import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Tesbih tanesi sesi (assets/audio/tesbih.wav, uygulamada üretilmiş kısa "tık"): her sayışta çalar.
class TesbihSound {
  TesbihSound._();

  static AudioPlayer? _p;
  static bool _ready = false;

  static Future<void> play() async {
    try {
      final p = _p ??= AudioPlayer();
      if (!_ready) {
        await p.setAsset('assets/audio/tesbih.wav');
        _ready = true;
      }
      await p.seek(Duration.zero);
      await p.play();
    } catch (e) {
      debugPrint('Tesbih sesi çalınamadı: $e');
    }
  }
}
