import 'package:flutter/services.dart';

/// Pusuladan gelen tek ölçüm.
class CompassReading {
  /// Gerçek kuzeye göre yön (0-360, saat yönünde).
  final double heading;

  /// Sensör doğruluğu: 0 güvenilmez, 1 düşük, 2 orta, 3 yüksek.
  final int accuracy;

  const CompassReading(this.heading, this.accuracy);
}

/// Telefonun pusula sensörü. Android tarafı MainActivity.kt içinde.
class Compass {
  static const EventChannel _events = EventChannel('ezan_saati/compass');
  static const MethodChannel _config = MethodChannel('ezan_saati/compass_config');

  static Stream<CompassReading> stream() {
    return _events.receiveBroadcastStream().map((dynamic e) {
      final list = e as List<dynamic>;
      return CompassReading((list[0] as num).toDouble(), (list[1] as num).toInt());
    });
  }

  /// Manyetik kuzey ile gerçek kuzey arasındaki farkı hesaplamak için konumu bildirir.
  static Future<void> setLocation(double lat, double lng) async {
    try {
      await _config.invokeMethod<void>('setLocation', {'lat': lat, 'lng': lng});
    } catch (_) {
      // Desteklenmeyen platformda sessizce geç.
    }
  }
}
