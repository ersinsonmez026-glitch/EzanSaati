import 'package:flutter/material.dart';

import '../services/prayer_calc.dart';

/// Ana ekrandaki vakit kartları: günün altı vakti simgeli kartlarda (çerçeve, simgeler ve adlar resimdir: assets/images/geri_sayim.webp; saatler
/// canlı yazılır). İçinde bulunulan vaktin saat kutusu açık altınla vurgulanır.
class CountdownBanner extends StatelessWidget {
  final PrayerStatus? status;

  const CountdownBanner({super.key, required this.status});

  // Kart görseli 1400 x 167: vakit simgeleri ve adları resimdedir; saatler alttaki kutulara kodla yazılır.
  // Konumlar 2068 x 246 ölçülü çizime göre.
  static const double _w = 2068, _h = 246;

  /// Genişlik / yükseklik.
  static const double aspect = _w / _h;

  /// Kartların üst kenarı, yüksekliğe oranı (kalan süre satırı artık ekranın üstünde: [RemainingLine]).
  static const double sideTop = 0;

  static const _boxes = [
    (21.0, 322.0),
    (354.0, 671.0),
    (703.0, 1016.0),
    (1048.0, 1363.0),
    (1396.0, 1715.0),
    (1749.0, 2048.0)
  ];
  static const double _boxTop = 125, _boxBottom = 227;

  static const _cream = Color(0xFFF6E3B0);
  static const _shadow = [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1))];

  /// "İkindiye", "Akşama" gibi yönelme hâli.
  static const _to = {
    'İmsak': 'İmsaka',
    'Güneş': 'Güneşe',
    'Öğle': 'Öğleye',
    'İkindi': 'İkindiye',
    'Akşam': 'Akşama',
    'Yatsı': 'Yatsıya',
  };

  /// Kalan süre "2:40" (saat:dakika); son bir saatte "0:25".
  static String remainingText(Duration d) => '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = status;
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final k = w / 400; // 400 genişlik esas
        final cardsH = w * _h / _w;
        final slots = s?.today.slots ?? const <PrayerSlot>[];

        return Column(
          children: [
            SizedBox(
              height: cardsH,
              child: Stack(
                children: [
                  Positioned.fill(child: Image.asset('assets/images/geri_sayim.webp', fit: BoxFit.fill)),
                  for (var i = 0; i < 6; i++)
                    Positioned(
                      left: _boxes[i].$1 / _w * w,
                      width: (_boxes[i].$2 - _boxes[i].$1) / _w * w,
                      top: _boxTop / _h * cardsH,
                      height: (_boxBottom - _boxTop) / _h * cardsH,
                      child: _time(i < slots.length ? formatHm(slots[i].time) : '--:--',
                          s?.current.name == PrayerCalc.names[i], k),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _time(String time, bool current, double k) {
    final text = Text(
      time,
      style: TextStyle(
        fontFamily: 'EBGaramond',
        fontSize: 14 * k,
        fontWeight: FontWeight.w700,
        color: current ? const Color(0xFF241802) : _cream,
        shadows: current ? null : _shadow,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Container(
      margin: EdgeInsets.all(1.2 * k),
      alignment: Alignment.center,
      decoration: current
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(5 * k),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF0DCA6), Color(0xFFC9A35E)],
              ),
            )
          : null,
      child: FittedBox(fit: BoxFit.scaleDown, child: text),
    );
  }
}

/// Sonraki vakte kalan süre ("Öğleye kalan 1:08"): çerçevesiz, hafif şeffaf tek satır (ana ekranın üst ortası).
class RemainingLine extends StatelessWidget {
  final PrayerStatus? status;
  final double k;

  const RemainingLine({super.key, required this.status, required this.k});

  @override
  Widget build(BuildContext context) {
    final s = status;
    return Opacity(
      opacity: 0.92,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
              text: s == null
                  ? 'Konum seçin'
                  : '${CountdownBanner._to[s.next.name] ?? s.next.name} kalan '),
          if (s != null)
            TextSpan(
                text: CountdownBanner.remainingText(s.remaining),
                style: TextStyle(
                    fontSize: 19 * k, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        maxLines: 1,
        style: TextStyle(
          fontFamily: 'EBGaramond',
          fontSize: 15.5 * k,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: CountdownBanner._shadow,
          height: 1.1,
        ),
      ),
    );
  }
}
