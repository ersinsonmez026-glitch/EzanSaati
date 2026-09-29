import 'package:flutter/material.dart';

import '../services/prayer_calc.dart';
import 'gold_icon.dart';

/// Ana ekrandaki geri sayım paneli. Çerçeve resimdir (assets/images/geri_sayim.webp); yazılar canlı çizilir.
/// Üstte tek satırda sonraki vakte kalan süre ("Öğleye Kalan 3 saat 10 dakika"), altta günün altı vakti;
/// içinde bulunulan vakit altın zeminle vurgulanır.
class CountdownBanner extends StatelessWidget {
  final PrayerStatus? status;

  const CountdownBanner({super.key, required this.status});

  // Kutu konumları çerçevenin 2100 x 607 ölçülü çizimine göre.
  static const double _w = 2100, _h = 607;
  static const double aspect = _w / _h;

  /// Çerçevenin sağ ve sol kenarının üstü (ortadaki kemer daha yukarıda), yüksekliğe oranı.
  static const double sideTop = 114 / _h;

  static const _slotsX = [
    (45.0, 352.0),
    (389.0, 696.0),
    (733.0, 1033.0),
    (1069.0, 1368.0),
    (1404.0, 1705.0),
    (1742.0, 2055.0)
  ];

  static const _cream = Color(0xFFF6E3B0);
  static const _shadow = [Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(0, 1))];

  /// "Öğleye", "Akşama" gibi yönelme hâli.
  static const _to = {
    'İmsak': 'İmsaka',
    'Güneş': 'Güneşe',
    'Öğle': 'Öğleye',
    'İkindi': 'İkindiye',
    'Akşam': 'Akşama',
    'Yatsı': 'Yatsıya',
  };

  @override
  Widget build(BuildContext context) {
    final s = status;
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final k = w / 400; // 400 genişlik esas
        Rect r(double x0, double y0, double x1, double y1) =>
            Rect.fromLTRB(x0 / _w * w, y0 / _h * h, x1 / _w * w, y1 / _h * h);

        TextStyle gold(double size, {FontWeight weight = FontWeight.w600}) =>
            TextStyle(fontFamily: 'EBGaramond', fontSize: size * k, fontWeight: weight, height: 1.0);

        // Üst satır: kalan süre (bir saatten azsa dakika ve saniye)
        final List<(String, bool)> parts;
        if (s == null) {
          parts = const [('Konum seçin', false)];
        } else {
          final d = s.remaining;
          final hh = d.inHours, mm = d.inMinutes % 60, ss = d.inSeconds % 60;
          parts = [
            ('${_to[s.next.name] ?? s.next.name} Kalan', false),
            if (hh > 0) ...[('$hh', true), ('saat', false), ('$mm', true), ('dakika', false)]
            else ...[('$mm', true), ('dakika', false), ('$ss', true), ('saniye', false)],
          ];
        }
        final slots = s?.today.slots ?? const <PrayerSlot>[];

        return Stack(
          children: [
            Positioned.fill(child: Image.asset('assets/images/geri_sayim.webp', fit: BoxFit.fill)),
            // Bulunulan vaktin kutusu altın zemin (kutunun içinde, kenarı açıkta)
            for (var i = 0; i < 6; i++)
              if (s?.current.name == PrayerCalc.names[i])
                Positioned.fromRect(
                  rect: r(_slotsX[i].$1 + 10, 390, _slotsX[i].$2 - 10, 551),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8 * k),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF0DCA6), Color(0xFFC9A35E)],
                      ),
                    ),
                  ),
                ),
            Positioned.fromRect(
              rect: r(340, 140, 1760, 330),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    // Küçük kelimeler ve büyük rakamlar dikeyde aynı çizgide ortalanır (süs çizgisi hizası).
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (final (i, (text, big)) in parts.indexed) ...[
                        if (i > 0) SizedBox(width: (big ? 5 : 4) * k),
                        GoldText(text, maxLines: 1, style: big ? gold(30, weight: FontWeight.w700) : gold(15)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            for (var i = 0; i < 6; i++)
              Positioned.fromRect(
                rect: r(_slotsX[i].$1, 380, _slotsX[i].$2, 560),
                child: _slot(PrayerCalc.names[i], i < slots.length ? formatHm(slots[i].time) : '--:--',
                    s?.current.name == PrayerCalc.names[i], k),
              ),
          ],
        );
      }),
    );
  }

  Widget _slot(String name, String time, bool current, double k) {
    const dark = Color(0xFF241802);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3 * k, vertical: 2 * k),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current)
              Text(name,
                  style: TextStyle(
                      fontFamily: 'EBGaramond', fontSize: 11 * k, fontWeight: FontWeight.w600, color: dark, height: 1.1))
            else
              GoldText(name,
                  style: TextStyle(fontFamily: 'EBGaramond', fontSize: 11 * k, fontWeight: FontWeight.w600, height: 1.1)),
            Text(
              time,
              style: TextStyle(
                fontFamily: 'EBGaramond',
                fontSize: 13 * k,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: current ? dark : _cream,
                shadows: current ? null : _shadow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
