import 'package:flutter/material.dart';

import '../services/app_prefs.dart';
import 'gold_icon.dart';
import '../services/app_theme.dart';

/// Ana ekrandaki tek bir tuş. Görünümü ayarlardan seçilir.
class MenuTile extends StatelessWidget {
  final String image; // tiles klasöründeki dosya adı (uzantısız)
  final String title;
  final String icon; // assets/images/ikon içindeki simge adı
  final TileStyle style;
  final bool hasPhoto; // görseli henüz yoksa simgeli gösterilir
  final VoidCallback onTap;
  final double labelSize; // tüm tuşlarda aynı; en uzun isim levhaya sığacak şekilde [fitLabelSize] ile bulunur

  const MenuTile({
    super.key,
    required this.image,
    required this.title,
    required this.icon,
    required this.style,
    required this.onTap,
    this.hasPhoto = true,
    this.labelSize = 17.5,
  });

  /// Tuş resimlerinin oranı (yükseklik / genişlik; resimler 600 x 508). Görselli tuşlar bu oranda çizilir.
  static const photoAspect = 508 / 600;

  /// Levhada, uçlardaki motiflerin arasında yazıya kalan genişlik oranı.
  static const _textArea = 0.8;

  /// Verilen tuş genişliğinde, isimlerin hepsinin levhaya sığdığı en büyük yazı boyutu (en çok 20).
  static double fitLabelSize(Iterable<String> titles, double tileWidth) {
    const probe = 20.0;
    final avail = (tileWidth - 8) * _textArea;
    var widest = 0.0;
    for (final t in titles) {
      final p = TextPainter(
        text: TextSpan(
            text: t, style: const TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.w600, fontSize: probe)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      if (p.width > widest) widest = p.width;
    }
    return widest == 0 ? probe : (probe * avail / widest * 0.92).clamp(10.0, probe);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    final effective = (style == TileStyle.resimli && !hasPhoto) ? TileStyle.yesil : style;
    final label = GoldText(
      title,
      maxLines: 1,
      textAlign: TextAlign.center,
      tone: switch (effective) {
        TileStyle.resimli => GoldTone.onPhoto,
        TileStyle.krem => GoldTone.onLight,
        TileStyle.yesil => GoldTone.onDark,
      },
      style: const TextStyle(fontFamily: 'Lora', fontWeight: FontWeight.w600, fontSize: 16.5, letterSpacing: 0.1),
    );
    // Görselli tuşta isim, çift altın çizgili koyu yeşil levhanın içinde.
    // Görselli tuşta isim, altın kenarlı yeşil kartuş levhanın içinde (assets/images/levha.webp).
    final plate = Padding(
      padding: const EdgeInsets.fromLTRB(3, 0, 3, 3),
      child: AspectRatio(
        aspectRatio: 600 / 142,
        child: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(image: AssetImage(themedAsset('assets/images/levha.webp')), fit: BoxFit.fill),
          ),
          child: FractionallySizedBox(
            widthFactor: _textArea,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: GoldText(
                  title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  tone: GoldTone.onDark,
                  style: TextStyle(
                      fontFamily: 'Lora', fontWeight: FontWeight.w600, fontSize: labelSize, letterSpacing: 0),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Widget child;
    BoxDecoration deco;
    switch (effective) {
      case TileStyle.resimli:
        // Resim tuşun tamamını kaplar ve üstten hizalıdır: sığmazsa yalnızca alttan kesilir (levha da
        // resmin alt kısmının üstünde durur). Üstü koyulaştırılmaz.
        deco = BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: const Color(0x8CBEA05A)),
          boxShadow: const [BoxShadow(color: Color(0x403C280A), blurRadius: 4, offset: Offset(0, 2))],
        );
        child = Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.asset('assets/images/tiles/$image.webp', fit: BoxFit.cover, alignment: Alignment.topCenter),
              ),
            ),
            Align(alignment: Alignment.bottomCenter, child: plate),
          ],
        );
      case TileStyle.krem:
      case TileStyle.yesil:
        final krem = effective == TileStyle.krem;
        deco = BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: krem ? const [Color(0xFFEADBB8), Color(0xFFDCC9A0)] : [tc(0xFF0D4630), tc(0xFF05281B)],
          ),
          border: Border.all(color: krem ? const Color(0x8C8A6414) : const Color(0x8CCFAE68)),
          boxShadow: const [BoxShadow(color: Color(0x333C280A), blurRadius: 4, offset: Offset(0, 2))],
        );
        child = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ArtIcon(icon, size: 40),
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: FittedBox(child: label)),
          ],
        );
    }

    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(decoration: deco, child: child),
      ),
    );
  }
}
