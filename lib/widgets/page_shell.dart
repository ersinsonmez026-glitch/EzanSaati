import 'package:flutter/material.dart';

import '../data/sayfa_basliklari.dart';
import '../screens/city_picker_screen.dart';
import '../screens/settings_screen.dart';
import '../services/app_prefs.dart';
import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../theme.dart';
import 'gold_icon.dart';

/// Ana ekran dışındaki bütün sayfaların ortak şablonu.
///
/// Üstte gece/gündüz manzaralı başlık: solda konum, ortada Ezan Saati logosu, sağda ayarlar;
/// altında sayfa adı ve alt yazısı, sağda sayfanın ayeti. Kaydırınca başlık kaydırmayla birlikte
/// kapanır; yalnızca geri · sayfa adı şeridi kalır.
class PageShell extends StatelessWidget {
  final String title;

  /// Alt yazı; verilmezse [heading] anahtarıyla [kSayfaBasliklari]'ndan alınır.
  final String? subtitle;

  /// Alt yazı ve ayetin alınacağı sayfa anahtarı (varsayılan: [title]).
  final String? heading;
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
    this.heading,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(10, 10, 10, 24),
    this.showSettings = true,
    this.background,
    this.controller,
  });

  static const double fullHeight = 164; // açık başlık
  static const double barHeight = 44; // kapanınca kalan şerit

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final h = kSayfaBasliklari[heading ?? title];
    final scroll = CustomScrollView(
      controller: controller,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
            title: title,
            subtitle: subtitle ?? h?.subtitle,
            verse: h?.verse,
            source: h?.source,
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

/// Gündüz görünümü mü? Kullanıcı Gündüz/Gece seçtiyse o, yoksa vakte göre ([isDaytimeByClock]).
/// Başlık manzarası, ana görsel ve krem/yeşil sayfa görünümü buna göre seçilir.
bool isDaytime() => switch (AppPrefs.instance.dayMode) {
      DayMode.gunduz => true,
      DayMode.gece => false,
      DayMode.otomatik => isDaytimeByClock(),
    };

/// Gündüz (imsak ile akşam arası) mı? Seçili konum yoksa 06:00-19:00 kabul edilir.
bool isDaytimeByClock() {
  final now = DateTime.now();
  final loc = LocationStore.instance.current;
  if (loc == null) return now.hour >= 6 && now.hour < 19;
  final t = PrayerCalc.forDay(loc, now).slots;
  return now.isAfter(t[0].time) && now.isBefore(t[4].time);
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final String? subtitle;
  final String? verse;
  final String? source;
  final double topInset;
  final bool showSettings;

  _HeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.verse,
    required this.source,
    required this.topInset,
    required this.showSettings,
  });

  static const _shadow = [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1))];

  @override
  double get maxExtent => PageShell.fullHeight + topInset;

  @override
  double get minExtent => PageShell.barHeight + topInset;

  @override
  bool shouldRebuild(covariant _HeaderDelegate old) =>
      old.title != title ||
      old.subtitle != subtitle ||
      old.verse != verse ||
      old.topInset != topInset ||
      old.showSettings != showSettings;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final p = (shrinkOffset / range).clamp(0.0, 1.0); // 0 açık, 1 kapalı
    // Üst sıra, alt yazı ve ayet ilk kaydırmada kaybolur.
    final fade = (1 - shrinkOffset / 60).clamp(0.0, 1.0);
    final canPop = Navigator.of(context).canPop();
    final hasVerse = verse != null;
    // Açıkken sayfa adı ve alt yazı, geri düğmesi ile ayet arasındaki alanda ortalanır;
    // kapanınca şeridin ortasına gelir.
    final left = canPop ? 44.0 : 12.0;
    final right = hasVerse ? 130 - 82 * p : 48.0;
    final titleTop = topInset + 74 - 72 * p;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.darkGreen,
        border: Border(bottom: BorderSide(color: Color(0x99D4AF37), width: 1.5)),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Manzara başlıkla birlikte yukarı kayar; alt kısmı koyu yeşile iner.
            Positioned(
              left: 0,
              right: 0,
              top: -shrinkOffset,
              height: maxExtent,
              child: Image.asset(
                isDaytime() ? 'assets/images/header_gunduz.jpg' : 'assets/images/header_gece.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.7),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x59000000), Color(0x00000000), Color(0x33021C12), Color(0xCC021C12)],
                  stops: [0, 0.3, 0.6, 1],
                ),
              ),
            ),

            // Üst sıra: konum · logo · ayarlar
            if (fade > 0) ...[
              Positioned(
                top: topInset - 2 - shrinkOffset,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: fade,
                  child: Center(
                    // Gündüz göğünde de seçilsin diye logonun arkasında hafif gölge
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          colors: [Color(0x66000000), Color(0x00000000)],
                          stops: [0.35, 1],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                        child: Image.asset('assets/images/logo_ezan_saati.png', height: 64, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: topInset + 14 - shrinkOffset,
                left: 10,
                child: Opacity(opacity: fade, child: const _LocationPill()),
              ),
              if (showSettings)
                Positioned(
                  top: topInset + 6 - shrinkOffset,
                  right: 4,
                  child: Opacity(
                    opacity: fade,
                    child: IconButton(
                      tooltip: 'Ayarlar',
                      icon: const GoldIcon(Icons.settings, size: 26),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ),
                ),
              if (hasVerse)
                Positioned(
                  top: topInset + 72 - shrinkOffset,
                  right: 8,
                  width: 112,
                  height: 86,
                  child: Opacity(
                    opacity: fade,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topRight,
                      child: SizedBox(
                        width: 112,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              verse!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                height: 1.3,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                                shadows: _shadow,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '($source)',
                              style: const TextStyle(
                                color: AppColors.goldLight,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                shadows: _shadow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],

            // Sayfa adı: açıkken ortada, kapanınca şeritte kalır.
            Positioned(
              top: titleTop,
              left: left + (48 - left) * p,
              right: right,
              height: 40,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: GoldText(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    tone: GoldTone.onPhoto,
                    style: TextStyle(
                      fontSize: 30 - 10 * p,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'serif',
                    ),
                  ),
                ),
              ),
            ),
            if (subtitle != null && fade > 0)
              Positioned(
                top: topInset + 114 - shrinkOffset,
                left: left,
                right: hasVerse ? 130 : 48,
                child: Opacity(
                  opacity: fade,
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFFF3E6C4),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            shadows: _shadow,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const _Ornament(),
                    ],
                  ),
                ),
              ),

            // Geri düğmesi hep şeritte
            if (canPop)
              Positioned(
                top: titleTop,
                left: 2,
                width: 44,
                height: 40,
                child: IconButton(
                  tooltip: 'Geri',
                  icon: const GoldIcon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Başlıktaki konum düğmesi: şehir adı, dokununca şehir seçimi.
class _LocationPill extends StatelessWidget {
  const _LocationPill();

  @override
  Widget build(BuildContext context) {
    final store = LocationStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Semantics(
        button: true,
        label: 'Konum: ${store.current?.name ?? 'seçilmedi'}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CityPickerScreen())),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 128),
            padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
            decoration: BoxDecoration(
              color: const Color(0x8C021C12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xCCD4AF37), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GoldIcon(Icons.location_on, size: 16),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    store.current?.name ?? 'Konum Seç',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFF8EED2), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 1),
                const Icon(Icons.chevron_right, size: 16, color: Color(0xFFE9C96A)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Alt yazının altındaki ince altın süs: çizgi · baklava · çizgi.
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    Widget line(bool left) => Container(
          width: 46,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: left
                  ? const [Color(0x00D4AF37), Color(0xFFD4AF37)]
                  : const [Color(0xFFD4AF37), Color(0x00D4AF37)],
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(true),
        const SizedBox(width: 4),
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE9C96A), width: 1.2)),
          ),
        ),
        const SizedBox(width: 4),
        line(false),
      ],
    );
  }
}
