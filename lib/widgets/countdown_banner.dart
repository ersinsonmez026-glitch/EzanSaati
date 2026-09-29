import 'package:flutter/material.dart';

import '../services/prayer_calc.dart';
import 'gold_icon.dart';

/// Ana ekrandaki geri sayım paneli. Çerçeve resimdir (assets/images/geri_sayim.webp); yazılar canlı çizilir.
/// Üstte solda şu anki vakit, ortada kalan süre, sağda sonraki vakit; altta günün altı vakti.
class CountdownBanner extends StatelessWidget {
  final PrayerStatus? status;

  const CountdownBanner({super.key, required this.status});

  // Görselin özgün ölçüsü (2172 x 724); kutu konumları bu ölçüye göre.
  static const double _w = 2172, _h = 724;
  static const double aspect = _w / _h;

  static const _time = Color(0xFFF6E3B0);
  static const _shadow = [Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(0, 1))];

  @override
  Widget build(BuildContext context) {
    final s = status;
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final k = w / 400; // 400 genişlik esas
          Widget at(double x0, double y0, double x1, double y1, Widget child) => Positioned(
                left: x0 / _w * w,
                top: y0 / _h * box.maxHeight,
                width: (x1 - x0) / _w * w,
                height: (y1 - y0) / _h * box.maxHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3 * k, vertical: 2 * k),
                  child: FittedBox(fit: BoxFit.scaleDown, child: child),
                ),
              );
          TextStyle t(double size, Color c, {FontWeight weight = FontWeight.w600}) => TextStyle(
                fontFamily: 'EBGaramond',
                fontSize: size * k,
                fontWeight: weight,
                color: c,
                height: 1.1,
                shadows: _shadow,
              );
          Widget gold(String text, double size) => GoldText(
                text,
                maxLines: 1,
                style:
                    TextStyle(fontFamily: 'EBGaramond', fontSize: size * k, fontWeight: FontWeight.w600, height: 1.1),
              );
          int iconOf(PrayerSlot? p) => p == null ? 2 : PrayerCalc.names.indexOf(p.name).clamp(0, 5);

          Widget side(String label, PrayerSlot? p) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  gold(label, 11.5),
                  SizedBox(height: 2 * k),
                  gold(p?.name ?? '--', 21),
                  SizedBox(height: 2 * k),
                  Text(p == null ? '--:--' : formatHm(p.time), style: t(13, _time)),
                ],
              );

          final slots = s?.today.slots ?? const <PrayerSlot>[];
          const bottom = [
            (41.0, 354.0),
            (377.0, 712.0),
            (737.0, 1074.0),
            (1098.0, 1437.0),
            (1461.0, 1798.0),
            (1822.0, 2131.0)
          ];
          return Stack(
            children: [
              Positioned.fill(child: Image.asset('assets/images/geri_sayim.webp', fit: BoxFit.fill)),
              at(82, 142, 597, 432, side('Şu Anki Vakit', s?.current)),
              at(
                605,
                95,
                1568,
                432,
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    gold(s == null ? 'Kalan Süre' : '${s.next.name} Vaktine Kalan Süre', 11),
                    gold(s == null ? '--:--:--' : formatDuration(s.remaining), 34),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ArtIcon(kVakitIkonlari[iconOf(s?.next)], size: 18 * k),
                        SizedBox(width: 4 * k),
                        gold(s?.next.name ?? '--', 15),
                      ],
                    ),
                  ],
                ),
              ),
              at(1577, 142, 2092, 432, side('Sonraki Vakit', s?.next)),
              for (var i = 0; i < 6; i++)
                Positioned(
                  left: bottom[i].$1 / _w * w,
                  width: (bottom[i].$2 - bottom[i].$1) / _w * w,
                  top: 456 / _h * box.maxHeight,
                  height: 208 / _h * box.maxHeight,
                  child: _SlotBox(
                    name: PrayerCalc.names[i],
                    time: i < slots.length ? formatHm(slots[i].time) : '--:--',
                    current: s?.current.name == PrayerCalc.names[i],
                    k: k,
                    style: t,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Alttaki küçük vakit kutusu; içinde bulunulan vakit altın ışıkla vurgulanır.
class _SlotBox extends StatelessWidget {
  final String name;
  final String time;
  final bool current;
  final double k;
  final TextStyle Function(double size, Color c, {FontWeight weight}) style;

  const _SlotBox({required this.name, required this.time, required this.current, required this.k, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(2.2 * k),
      decoration: current
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(6 * k),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE6CC92), Color(0xFFC4A060)],
              ),
              boxShadow: const [BoxShadow(color: Color(0x66E6CC92), blurRadius: 8)],
            )
          : null,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current)
              Text(name, style: style(11, const Color(0xFF2E2004)).copyWith(shadows: const []))
            else
              GoldText(name, style: TextStyle(fontFamily: 'EBGaramond', fontSize: 11 * k, fontWeight: FontWeight.w600)),
            Text(
              time,
              style: current
                  ? style(13.5, const Color(0xFF241802), weight: FontWeight.w700).copyWith(shadows: const [])
                  : style(13.5, const Color(0xFFF6E3B0), weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
