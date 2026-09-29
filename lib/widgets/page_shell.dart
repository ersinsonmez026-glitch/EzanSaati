import 'dart:math' as math;

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
/// Üstte gece/gündüz manzaralı başlık: solda konum, ortada Ezan Saati logosu; altında sayfa adı
/// ve alt yazısı, sağda sayfanın ayeti. Kaydırınca başlık kaydırmayla birlikte
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

  static const double fullHeight = 104; // açık başlık
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
            day: isDaytime(),
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
      body: background == null
          ? scroll
          : DecoratedBox(decoration: background!, child: scroll),
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

/// Gündüz/gece görünümünü değiştirir ve açık bütün sayfaları yeni renklerle yeniden çizer.
/// Seçilen görünüm vakte göre olanla aynıysa yeniden "Otomatik"e döner.
void toggleDayMode(BuildContext context) {
  final toDay = !isDaytime();
  final mode = toDay == isDaytimeByClock()
      ? DayMode.otomatik
      : (toDay ? DayMode.gunduz : DayMode.gece);
  AppPrefs.instance.setDayMode(mode);
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    duration: const Duration(seconds: 2),
    content: Text(mode == DayMode.otomatik
        ? 'Görünüm yine vakte göre değişecek'
        : "${toDay ? 'Gündüz' : 'Gece'} görünümü seçildi. Ayarlar'dan Otomatik'e alabilirsiniz."),
  ));
}

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
  final bool day; // gündüz görünümü mü; değişince başlık yeniden çizilir

  _HeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.verse,
    required this.source,
    required this.topInset,
    required this.showSettings,
    required this.day,
  });

  static const _shadow = [
    Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1))
  ];

  /// Yerleşimin dayandığı üst hiza: durum çubuğu (en az 24; logo bu çubuğun hizasından başlar).
  double get _base => math.max(topInset, 24);

  @override
  double get maxExtent => PageShell.fullHeight + _base;

  @override
  double get minExtent => PageShell.barHeight + topInset;

  @override
  bool shouldRebuild(covariant _HeaderDelegate old) =>
      old.title != title ||
      old.subtitle != subtitle ||
      old.verse != verse ||
      old.topInset != topInset ||
      old.showSettings != showSettings ||
      old.day != day;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final p = (shrinkOffset / range).clamp(0.0, 1.0); // 0 açık, 1 kapalı
    // Logo, konum, alt yazı ve ayet ilk kaydırmada kaybolur.
    final fade = (1 - shrinkOffset / 40).clamp(0.0, 1.0);
    final canPop = Navigator.of(context).canPop();
    final hasVerse = verse != null;
    // Sayfa adı ortada; ayetli sayfalarda iki yandan ayet kadar boşluk bırakılır.
    final side = hasVerse ? 100 - 52 * p : 48.0;
    final base = _base;
    final titleTop = base + 38 - (base + 36 - topInset) * p;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.darkGreen,
        border:
            Border(bottom: BorderSide(color: Color(0x99D4AF37), width: 1.5)),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Manzara: görselin tamamı genişliğe sığar, üstten hizalanır; başlıkla birlikte kayar.
            Positioned(
              left: 0,
              right: 0,
              top: -shrinkOffset,
              child: Image.asset(
                isDaytime()
                    ? 'assets/images/header_gunduz.jpg'
                    : 'assets/images/header_gece.jpg',
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            ),
            // Gündüz göğü aydınlık: yazılar okunsun diye biraz daha koyulaştırılır.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDaytime()
                      ? const [
                          Color(0x66000000),
                          Color(0x26000000),
                          Color(0x1A021C12),
                          Color(0xB3021C12)
                        ]
                      : const [
                          Color(0x40000000),
                          Color(0x00000000),
                          Color(0x00021C12),
                          Color(0xB3021C12)
                        ],
                  stops: const [0, 0.25, 0.55, 1],
                ),
              ),
            ),
            // Logo ve ayetin arkasında yumuşak gölge
            Positioned(
              top: base - 30 - shrinkOffset,
              left: 0,
              right: 0,
              height: 110,
              child: Opacity(
                opacity: fade,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.42,
                      colors: [Color(0x59000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            if (verse != null)
              Positioned(
                top: base + 20 - shrinkOffset,
                right: 0,
                width: 130,
                height: 100,
                child: Opacity(
                  opacity: fade,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0x66000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),

            if (fade > 0) ...[
              // Logo: durum çubuğu hizasından başlar, ortada
              Positioned(
                top: base - 14 - shrinkOffset,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: fade,
                  child: Center(
                    child: Image.asset('assets/images/logo_ezan_saati.png',
                        height: 53, fit: BoxFit.contain),
                  ),
                ),
              ),
              // Konum: minareleri kesmesin diye en üstte
              Positioned(
                top: base - 4 - shrinkOffset,
                left: 10,
                child: Opacity(opacity: fade, child: const _LocationPill()),
              ),
              if (showSettings)
                Positioned(
                  top: base - 4 - shrinkOffset,
                  right: 8,
                  child: Opacity(
                    opacity: fade,
                    child: Semantics(
                      button: true,
                      label: 'Ayarlar',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        ),
                        child: Image.asset('assets/images/ikon/ayarlar.webp',
                            width: 28.5, height: 28.5),
                      ),
                    ),
                  ),
                ),
              if (hasVerse)
                Positioned(
                  top: base + 36 - shrinkOffset,
                  right: 12,
                  width: 84,
                  height: 64,
                  child: Opacity(
                    opacity: fade,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 84,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              verse!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                height: 1.3,
                                shadows: _shadow,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '($source)',
                              style: const TextStyle(
                                  color: Color(0xFFE7DDC4),
                                  fontSize: 8,
                                  shadows: _shadow),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (subtitle != null)
                Positioned(
                  top: base + 72 - shrinkOffset,
                  left: hasVerse ? 100 : 48,
                  right: hasVerse ? 100 : 48,
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
                                color: Color(0xFFE6D3A0),
                                fontSize: 11,
                                shadows: _shadow),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const _Ornament(),
                      ],
                    ),
                  ),
                ),
            ],

            // Görselin altında gece/gündüz düğmesi: gecede güneş, gündüzde ay; dokununca görünüm değişir.
            if (fade > 0)
              Positioned(
                top: base + 74 - shrinkOffset,
                left: 10,
                width: 31,
                height: 31,
                child: Opacity(
                  opacity: fade,
                  child: Semantics(
                    button: true,
                    label: isDaytime()
                        ? 'Gece görünümüne geç'
                        : 'Gündüz görünümüne geç',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => toggleDayMode(context),
                      child: Image.asset(
                        isDaytime()
                            ? 'assets/images/ikon/imsak.webp'
                            : 'assets/images/ikon/ikindi.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

            // Sayfa adı: açıkken logonun altında ortada, kapanınca şeritte kalır.
            Positioned(
              top: titleTop,
              left: side,
              right: side,
              height: 36,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: GoldText(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    tone: GoldTone.onPhoto,
                    style: TextStyle(
                        fontSize: 26 - 6 * p,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'EBGaramond'),
                  ),
                ),
              ),
            ),

            // Geri düğmesi hep şeritte
            if (canPop)
              Positioned(
                top: titleTop + 2 - 2 * p,
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
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CityPickerScreen())),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 118),
            padding: const EdgeInsets.fromLTRB(7, 4, 4, 4),
            decoration: BoxDecoration(
              color: const Color(0x8C021C12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xCCD4AF37), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GoldIcon(Icons.location_on, size: 14),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    store.current?.name ?? 'Konum Seç',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFF8EED2),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 1),
                const Icon(Icons.chevron_right,
                    size: 14, color: Color(0xFFE9C96A)),
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
          width: 40,
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
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE9C96A), width: 1.2)),
          ),
        ),
        const SizedBox(width: 4),
        line(false),
      ],
    );
  }
}
