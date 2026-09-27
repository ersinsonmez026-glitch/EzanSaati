import 'package:flutter/material.dart';

import '../screens/city_picker_screen.dart';
import '../screens/settings_screen.dart';
import '../services/location_store.dart';
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

  const PageShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(10, 10, 10, 24),
    this.showSettings = true,
  });

  static const double fullHeight = 104; // açık başlık
  static const double barHeight = 44; // kapanınca kalan şerit

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      body: CustomScrollView(
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
      ),
    );
  }
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
    final topOpacity = (1 - shrinkOffset / 45).clamp(0.0, 1.0);
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
                'assets/images/header_night.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.15),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x73000000), Color(0x8C021C12), Color(0xEB021C12)],
                  stops: [0, 0.55, 1],
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/levha_allah.png', width: 44, height: 44),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              '☾ Ezan Saati',
                              style: TextStyle(
                                color: AppColors.goldLight,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'serif',
                                shadows: shadow,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ListenableBuilder(
                              listenable: LocationStore.instance,
                              builder: (context, _) => InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const CityPickerScreen()),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.85)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on, color: AppColors.gold, size: 13),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${LocationStore.instance.current?.name ?? 'Konum Seç'} ›',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
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
                      Image.asset('assets/images/levha_muhammed.png', width: 44, height: 44),
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
