import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/compass.dart';
import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../theme.dart';
import 'city_picker_screen.dart';

/// Telefonun pusulasıyla çalışan Kıble bulucu.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  static const double _kaabaLat = 21.4225;
  static const double _kaabaLng = 39.8262;

  StreamSubscription<CompassReading>? _sub;
  double? _heading; // yumuşatılmış yön
  int _accuracy = 3;
  String? _error;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    final loc = LocationStore.instance.current;
    if (loc != null) Compass.setLocation(loc.lat, loc.lng);
    _sub = Compass.stream().listen(
      _onReading,
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _error = e is PlatformException && e.message != null
            ? e.message
            : 'Bu cihazda pusula kullanılamıyor.');
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onReading(CompassReading r) {
    final prev = _heading;
    double next;
    if (prev == null) {
      next = r.heading;
    } else {
      // 359° -> 0° geçişinde zıplamasın diye en kısa farkla yumuşat.
      final diff = _signedDiff(r.heading, prev);
      next = (prev + diff * 0.25) % 360;
      if (next < 0) next += 360;
    }
    if (!mounted) return;
    setState(() {
      _heading = next;
      _accuracy = r.accuracy;
    });
  }

  /// a - b farkını -180..180 aralığında verir.
  static double _signedDiff(double a, double b) {
    var d = (a - b) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  static String _directionName(double deg) {
    const names = ['Kuzey', 'Kuzeydoğu', 'Doğu', 'Güneydoğu', 'Güney', 'Güneybatı', 'Batı', 'Kuzeybatı'];
    return names[((deg + 22.5) % 360 ~/ 45)];
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocationStore.instance.current;

    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      appBar: goldAppBar('Kıble Bulucu'),
      body: loc == null ? _noLocation() : _content(loc),
    );
  }

  Widget _noLocation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kıble yönünü hesaplamak için önce şehrinizi seçin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CityPickerScreen()),
                );
                final l = LocationStore.instance.current;
                if (l != null) Compass.setLocation(l.lat, l.lng);
                if (mounted) setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Şehir Seç'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AppLocation loc) {
    final qibla = PrayerCalc.qiblaDirection(loc);
    final km = LocationStore.distanceKm(loc.lat, loc.lng, _kaabaLat, _kaabaLng);
    final heading = _heading;
    final diff = heading == null ? null : _signedDiff(qibla, heading);
    final aligned = diff != null && diff.abs() <= 5;

    if (aligned && !_wasAligned) HapticFeedback.mediumImpact();
    _wasAligned = aligned;

    String hint;
    if (_error != null) {
      hint = _error!;
    } else if (heading == null) {
      hint = 'Pusula hazırlanıyor...';
    } else if (aligned) {
      hint = 'Kıbleye yöneldiniz';
    } else if (diff! > 0) {
      hint = 'Sağa dönün (${diff.round()}°)';
    } else {
      hint = 'Sola dönün (${(-diff!).round()}°)';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          loc.name,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
            color: aligned ? AppColors.mint : AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            fontFamily: 'serif',
          ),
          child: Text(hint, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 20),

        // Pusula
        Center(
          child: SizedBox(
            width: 300,
            height: 330,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Telefonun baktığı yönü gösteren sabit üçgen
                const Positioned(
                  top: 0,
                  child: Icon(Icons.arrow_drop_down, color: AppColors.gold, size: 48),
                ),
                Positioned(
                  top: 30,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (aligned ? AppColors.mint : AppColors.gold)
                              .withValues(alpha: aligned ? 0.55 : 0.2),
                          blurRadius: aligned ? 40 : 18,
                          spreadRadius: aligned ? 6 : 2,
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: -(heading ?? 0) * math.pi / 180,
                      child: Stack(
                        children: [
                          const Positioned.fill(child: CustomPaint(painter: _DialPainter())),
                          // Kâbe işareti kadranın üzerinde, kıble açısında durur
                          Positioned.fill(
                            child: Transform.rotate(
                              angle: qibla * math.pi / 180,
                              child: const Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 34),
                                  child: _KaabaMarker(),
                                ),
                              ),
                            ),
                          ),
                          // Merkezden Kâbe'ye çizgi
                          Positioned.fill(
                            child: Transform.rotate(
                              angle: qibla * math.pi / 180,
                              child: const CustomPaint(painter: _NeedlePainter()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Bilgi kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _info('Kıble Açısı', '${qibla.round()}° ${_directionName(qibla)}'),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(
                child: _info('Kâbe\'ye Uzaklık', '${km.round()} km'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_accuracy <= 1 && _error == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A3B00),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.gold),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pusula hassasiyeti düşük. Telefonu havada birkaç kez "8" çizecek '
                    'şekilde hareket ettirerek kalibre edin.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Telefonu yere paralel tutun, mıknatıs ve metal eşyalardan uzak durun.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _info(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ],
    );
  }
}

/// Küçük Kâbe simgesi.
class _KaabaMarker extends StatelessWidget {
  const _KaabaMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(height: 4, color: AppColors.gold),
        ],
      ),
    );
  }
}

/// Pusula kadranı: halka, çentikler ve yön harfleri.
class _DialPainter extends CustomPainter {
  const _DialPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF014D31), Color(0xFF002B1B)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.gold,
    );

    final tick = Paint()..color = AppColors.gold;
    for (var deg = 0; deg < 360; deg += 5) {
      final a = deg * math.pi / 180;
      final major = deg % 30 == 0;
      final len = major ? 14.0 : 7.0;
      tick.strokeWidth = major ? 2.5 : 1.2;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(c + dir * (r - 8), c + dir * (r - 8 - len), tick);
    }

    const letters = {'K': 0, 'D': 90, 'G': 180, 'B': 270};
    letters.forEach((text, deg) {
      final a = deg * math.pi / 180;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: text == 'K' ? const Color(0xFFFF6B5B) : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = c + Offset(math.sin(a), -math.cos(a)) * (r - 40);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(a);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Merkezden yukarı (Kâbe yönüne) uzanan altın ibre.
class _NeedlePainter extends CustomPainter {
  const _NeedlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, c - Offset(0, r - 70), paint);
    canvas.drawCircle(c, 9, Paint()..color = AppColors.gold);
    canvas.drawCircle(c, 4, Paint()..color = AppColors.darkGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
