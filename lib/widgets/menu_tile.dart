import 'package:flutter/material.dart';

import '../services/app_prefs.dart';
import 'gold_icon.dart';

/// Ana ekrandaki tek bir tuş. Görünümü ayarlardan seçilir.
class MenuTile extends StatelessWidget {
  final String image; // tiles klasöründeki dosya adı (uzantısız)
  final String title;
  final String icon; // assets/images/ikon içindeki simge adı
  final TileStyle style;
  final bool hasPhoto; // görseli henüz yoksa simgeli gösterilir
  final VoidCallback onTap;

  const MenuTile({
    super.key,
    required this.image,
    required this.title,
    required this.icon,
    required this.style,
    required this.onTap,
    this.hasPhoto = true,
  });

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
      style: const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.2),
    );

    Widget child;
    BoxDecoration deco;
    switch (effective) {
      case TileStyle.resimli:
        deco = BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: const Color(0x8CBEA05A)),
          image: DecorationImage(image: AssetImage('assets/images/tiles/$image.jpg'), fit: BoxFit.cover),
          boxShadow: const [BoxShadow(color: Color(0x403C280A), blurRadius: 4, offset: Offset(0, 2))],
        );
        child = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x001C160E), Color(0xD11C160E)],
              stops: [0.4, 0.82],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 9), child: FittedBox(child: label)),
          ),
        );
      case TileStyle.krem:
      case TileStyle.yesil:
        final krem = effective == TileStyle.krem;
        deco = BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: krem ? const [Color(0xFFEADBB8), Color(0xFFDCC9A0)] : const [Color(0xFF0D4630), Color(0xFF05281B)],
          ),
          border: Border.all(color: krem ? const Color(0x8C8A6414) : const Color(0x8CD4AF37)),
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
