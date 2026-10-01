import 'dart:io';

import 'package:flutter/services.dart';

/// Telefonun titreşim motorunu doğrudan çalıştırır. HapticFeedback, telefonda "dokunma titreşimi"
/// kapalıysa hiç titremez; zikir sayacında bu yüzden doğrudan titreşim kullanılır.
class Vibration {
  static const _ch = MethodChannel('ezan_saati/titresim');

  static Future<void> pulse({int ms = 30, int amp = 160}) async {
    if (!Platform.isAndroid) return HapticFeedback.lightImpact();
    try {
      await _ch.invokeMethod('vibrate', {'ms': ms, 'amp': amp});
    } catch (_) {
      await HapticFeedback.lightImpact();
    }
  }

  static Future<void> light() => pulse(ms: 25, amp: 120);
  static Future<void> medium() => pulse(ms: 40, amp: 190);
  static Future<void> heavy() => pulse(ms: 70, amp: 255);
}
