import 'package:flutter/material.dart';

import '../services/prayer_calc.dart';
import '../theme.dart';

/// Ana ekrandaki altın-yeşil geri sayım şeridi.
/// Arka plan resimdir (assets/images/countdown.png), yazılar canlı çizilir.
class CountdownBanner extends StatelessWidget {
  final PrayerStatus? status;

  const CountdownBanner({super.key, required this.status});

  // Görselin kendi oranı (2048 x 592)
  static const double aspect = 2048 / 592;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final s = status;

          Widget at(double fx, double fy, Widget child, {double fw = 0.14}) {
            // fx, fy: görsel üzerindeki konum (0..1), fw: izin verilen genişlik
            return Positioned(
              left: fx * w - w * fw / 2,
              width: w * fw,
              top: fy * h - h * 0.10,
              height: h * 0.20,
              child: Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: child),
              ),
            );
          }

          TextStyle style(double size, Color color, {FontWeight weight = FontWeight.w600}) {
            return TextStyle(
              color: color,
              fontSize: w * size,
              fontWeight: weight,
              fontFamily: 'serif',
              height: 1.0,
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1)),
              ],
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset('assets/images/countdown.png', fit: BoxFit.fill),
              ),
              // Sol: şu anki vakit
              at(0.223, 0.365, Text('Şu An', style: style(0.021, AppColors.goldLight))),
              at(0.223, 0.470,
                  Text(s?.current.name ?? '--', style: style(0.036, Colors.white, weight: FontWeight.w800))),
              at(0.223, 0.575, Text('Vakti', style: style(0.021, AppColors.goldLight))),
              // Orta: geri sayım
              at(0.5, 0.445,
                  Text(s == null ? '--:--:--' : formatDuration(s.remaining),
                      style: style(0.05, Colors.white, weight: FontWeight.w800)),
                  fw: 0.17),
              // Sağ: sıradaki vakit
              at(0.78, 0.365, Text('Sonraki Vakit', style: style(0.021, AppColors.goldLight))),
              at(0.78, 0.470,
                  Text(s?.next.name ?? '--', style: style(0.036, Colors.white, weight: FontWeight.w800))),
              at(0.78, 0.575,
                  Text(s == null ? '--:--' : formatHm(s.next.time),
                      style: style(0.024, const Color(0xFFDDE6F0)))),
            ],
          );
        },
      ),
    );
  }
}
