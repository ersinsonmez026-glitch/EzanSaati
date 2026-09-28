import 'package:flutter/material.dart';

import '../screens/settings_screen.dart';
import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../theme.dart';

/// Ana ekran dışındaki bütün sayfaların ortak şablonu.
///
/// Üstte ince gece manzaralı başlık vardır: köşelerde levhalar, ortada logo ve
/// konum, altında geri · sayfa adı · ayarlar. Kaydırınca başlık kaydırmayla
/// birebir (aynı hızda) yukarı kapanır; sadece sayfa adının olduğu şerit kalır.
class PageShell extends StatelessWidget {
  final String title;
  final String? subtitle; // artık başlıkta gösterilmiyor, uyumluluk için duruyor
  final List<Widget> children;
  final EdgeInsets padding;
  final bool showSettings;

  /// Sayfa zemini. Verilmezse koyu yeşil düz renk kullanılır.
  final Decoration? background;

  /// Sayfanın kaydırmasını dışarıdan izlemek/yönetmek için (ör. kaldığın ayete gitme).
  final ScrollController? controller;

  const PageShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(10, 10, 10, 24),
    this.showSettings = true,
    this.background,
    this.controller,
  });

  static const double fullHeight = 118; // açık başlık
  static const double barHeight = 44; // kapanınca kalan şerit

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final scroll = CustomScrollView(
      controller: controller,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
            title: title,
            topInset: top,
            showSettings: showSettings,
          ),
        ),
        SliverPadding(
          padding: padding,
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      body: background == null ? scroll : DecoratedBox(decoration: background!, child: scroll),
    );
  }
}

/// Gündüz (imsak ile akşam arası) mı? Seçili konum yoksa 06:00-19:00 kabul edilir.
/// Başlık manzarası ve krem/yeşil sayfa görünümü buna göre seçilir.
bool isDaytime() {
  final now = DateTime.now();
  final loc = LocationStore.instance.current;
  if (loc == null) return now.hour >= 6 && now.hour < 19;
  final t = PrayerCalc.forDay(loc, now).slots;
  return now.isAfter(t[0].time) && now.isBefore(t[4].time);
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final double topInset;
  final bool showSettings;

  _HeaderDelegate({required this.title, required this.topInset, required this.showSettings});

  @override
  double get maxExtent => PageShell.fullHeight + topInset;

  @override
  double get minExtent => PageShell.barHeight + topInset;

  @override
  bool shouldRebuild(covariant _HeaderDelegate old) =>
      old.title != title || old.topInset != topInset || old.showSettings != showSettings;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    const shadow = [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2))];
    // Üst sıra (levhalar, logo, konum) ilk 45 pikselde kaybolur
    final topOpacity = (1 - shrinkOffset / 55).clamp(0.0, 1.0);
    final canPop = Navigator.of(context).canPop();

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.darkGreen,
        border: Border(bottom: BorderSide(color: Color(0x99D4AF37), width: 1.5)),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Manzara başlıkla birlikte yukarı kayar
            Positioned(
              left: 0,
              right: 0,
              top: -shrinkOffset,
              height: maxExtent,
              child: Image.asset(
                isDaytime() ? 'assets/images/header_gunduz.jpg' : 'assets/images/header_gece.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0.24, 0.16),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0x00000000), Color(0x40021C12), Color(0xD9021C12)],
                  stops: [0, 0.4, 0.62, 1],
                ),
              ),
            ),

            // Üst sıra
            if (topOpacity > 0)
              Positioned(
                top: topInset + 6 - shrinkOffset,
                left: 10,
                right: 10,
                child: Opacity(
                  opacity: topOpacity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/images/levha_allah.png', width: 64, height: 64),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          // Logo levhalardan küçük ve daha aşağıda durur (levhalar önde).
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Opacity(
                              opacity: 0.9,
                              child: Image.asset('assets/images/logo_sembol.png', height: 46, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                      Image.asset('assets/images/levha_muhammed.png', width: 64, height: 64),
                    ],
                  ),
                ),
              ),

            // Alt şerit: geri · sayfa adı · ayarlar (hep görünür)
            Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              height: 40,
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: canPop
                        ? IconButton(
                            tooltip: 'Geri',
                            icon: const Icon(Icons.arrow_back_ios_new,
                                size: 20, color: AppColors.goldLight, shadows: shadow),
                            onPressed: () => Navigator.of(context).maybePop(),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'serif',
                        shadows: shadow,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: showSettings
                        ? IconButton(
                            tooltip: 'Ayarlar',
                            icon: const Icon(Icons.settings, size: 22, color: AppColors.gold, shadows: shadow),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
