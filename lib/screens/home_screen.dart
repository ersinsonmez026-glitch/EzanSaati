import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../services/app_prefs.dart';
import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../theme.dart';
import '../widgets/countdown_banner.dart';
import '../widgets/menu_tile.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'city_picker_screen.dart';
import 'dhikr_screen.dart';
import 'dua_circle_screen.dart';
import 'hadiths_screen.dart';
import 'learn_namaz_screen.dart';
import 'messages_screen.dart';
import 'mosque_finder_screen.dart';
import 'prayer_times_screen.dart';
import 'prayers_screen.dart';
import 'qibla_screen.dart';
import 'ramadan_screen.dart';
import 'settings_screen.dart';
import 'surahs_screen.dart';
import '../widgets/gold_icon.dart';

/// Ana ekrandaki bir tuş: görseli, adı ve açacağı sayfa.
class _MenuItem {
  final String image;
  final String title;
  final String icon; // assets/images/ikon içindeki simge (Krem/Yeşil görünüm)
  final Widget Function() page;

  const _MenuItem(this.image, this.title, this.icon, this.page);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 12 tuş, 3 sütun × 4 sıra. Sıra sabittir (kullanıcı onayı), değiştirme.
  static final List<_MenuItem> _items = [
    _MenuItem('namaz_vakitleri', 'Namaz Vakitleri', 'namaz_vakitleri', () => const PrayerTimesScreen()),
    _MenuItem('sureler', 'Sureler', 'kuran', () => const SurahsScreen()),
    _MenuItem('dualar', 'Dualar', 'dualar', () => const PrayersScreen()),
    _MenuItem('zikir_sayaci', 'Zikir Sayacı', 'tesbih', () => const DhikrScreen()),
    _MenuItem('kible_bulucu', 'Kıble Bulucu', 'kible_bulucu', () => const QiblaScreen()),
    _MenuItem('cami_bulucu', 'Cami Bulucu', 'cami_bulucu', () => const MosqueFinderScreen()),
    _MenuItem('dua_cemberi', 'Dua Zinciri', 'dua_cemberi', () => const DuaCircleScreen()),
    _MenuItem('hadisler', 'Hadisler', 'hadisler', () => const HadithsScreen()),
    _MenuItem('ramazan', 'Ramazan', 'fener', () => const RamadanScreen()),
    _MenuItem('namaz_ogren', 'Namaz Öğren', 'cami', () => const LearnNamazScreen()),
    _MenuItem('dini_mesajlar', 'Dini Mesajlar', 'dini_mesajlar', () => const MessagesScreen()),
    _MenuItem('ayarlar', 'Ayarlar', 'ayarlar', () => const SettingsScreen()),
  ];
  static const _rows = 4;

  Timer? _ticker;
  PrayerStatus? _status;
  final _location = LocationStore.instance;

  @override
  void initState() {
    super.initState();
    _location.addListener(_refresh);
    AppPrefs.instance.addListener(_refresh);
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => _askLocationIfNeeded());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _location.removeListener(_refresh);
    AppPrefs.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    final loc = _location.current;
    if (!mounted) return;
    setState(() {
      _status = loc == null ? null : PrayerCalc.status(loc, DateTime.now());
    });
  }

  /// İlk açılışta konum seçilmemişse sorar.
  Future<void> _askLocationIfNeeded() async {
    if (_location.current != null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.darkGreen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _LocationSheet(),
    );
  }

  void _onTap(_MenuItem item) {
    Navigator.of(context).push(AppRoute(builder: (_) => item.page()));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final loc = _location.current;
    const shadow = [Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(1, 1))];

    // Ana ekran eski yazı tipiyle kalır; diğer sayfalar EB Garamond kullanır.
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'EBGaramond'),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'EBGaramond'),
      ),
      child: Scaffold(
        backgroundColor: isDaytime() ? const Color(0xFFD8C59C) : const Color(0xFF03170F), // koyu krem / gece yeşili
        body: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth, h = box.maxHeight;
            final k = (w / 390).clamp(0.8, 1.4); // yazı ve levha ölçeği (iPhone 390 genişlik esas)
            const gap = 6.0, pad = 6.0;
            final tileW = (w - 2 * pad - 2 * gap) / 3;
            double gridFor(double tileH) => _rows * tileH + (_rows - 1) * gap + 2 * pad;

            // Üst alan içeriği (üstten alta): levhalar ve şehir/tarih/saat, ayet ve gece/gündüz tuşu,
            // geri sayım paneli. Ölçüler ekran genişliğinden hesaplanır; yükseklik bunların toplamı kadardır,
            // hiçbir şey üst üste binmez. Sığmazsa tuşlar basıklaşır.
            final minHero = math.max(math.max(250.0, h * 0.36), _heroContent(w, k));            final maxHero = math.max(h * 0.56, minHero);
            var tileH = tileW / 1.2;
            if (h - gridFor(tileH) < minHero) {
              tileH = math.max(tileW / 1.75, (h - minHero - (_rows - 1) * gap - 2 * pad) / _rows);
            } else if (h - gridFor(tileH) > maxHero) {
              tileH = math.min(tileW / 0.95, (h - maxHero - (_rows - 1) * gap - 2 * pad) / _rows);
            }
            final gridH = gridFor(tileH);
            final labelSize = MenuTile.fitLabelSize(_items.map((e) => e.title), tileW);
            final heroH = math.max(minHero, h - gridH);
            // Çok kısa ekranlarda (ör. yatay) sığmazsa kaydırılabilir; normalde kaydırma yok.
            final scrolls = heroH + gridH > h + 0.5;

            return SingleChildScrollView(
              physics: scrolls ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: heroH, child: _hero(now, loc, k, shadow)),
                  // ============================================================
                  // ALT KISIM - 12 TUŞ (3 × 4)
                  // ============================================================
                  SizedBox(
                    height: gridH,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(pad),
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                        childAspectRatio: tileW / tileH,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return MenuTile(
                          image: item.image,
                          title: item.title,
                          icon: item.icon,
                          style: AppPrefs.instance.tileStyle,
                          labelSize: labelSize,
                          onTap: () => _onTap(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // ============================================================
  // ÜST YARI - ANA GÖRSEL, LEVHALAR, KONUM/TARİH, AYET, GERİ SAYIM
  // ============================================================
  // Üst alanın ölçüleri (k: ekran genişliği ölçeği)
  static double _medal(double k) => 80 * k;
  static double _verseH(double k) => 46 * k;
  static double _bannerW(double w) => math.min(w * 0.9, 500);
  static double _heroContent(double w, double k) =>
      6 + _medal(k) + 4 + _verseH(k) + 6 + _bannerW(w) / CountdownBanner.aspect + 8;

  Widget _hero(DateTime now, AppLocation? loc, double k, List<Shadow> shadow) {
    final medal = _medal(k);
    return Stack(
      children: [
        // Arka plan: cami her ekran boyunda ortada dursun (gece ve gündüz aynı kadraj)
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) => Image.asset(
              isDaytime() ? 'assets/images/home_hero.jpg' : 'assets/images/home_hero_gece.jpg',
              fit: BoxFit.cover,
              alignment: _alignOn(box.biggest, 1536, 1024, 0.54, 0.52),
            ),
          ),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) => Column(
              children: [
                const SizedBox(height: 6),
                // 1. sıra: Allah · şehir / tarih / saat · Muhammed
                SizedBox(
                  height: medal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 6),
                      _Medallion('assets/images/hat_allah.webp', size: medal),
                      Expanded(child: _cityDate(now, loc, k, shadow)),
                      _Medallion('assets/images/hat_muhammed.webp', size: medal),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // 2. sıra: ayet (ortada) · gece/gündüz tuşu (sağda)
                SizedBox(
                  height: _verseH(k),
                  child: Row(
                    children: [
                      SizedBox(width: 40 * k),
                      Expanded(child: _verse(k, shadow)),
                      SizedBox(width: 40 * k, child: Center(child: _DayNightButton(size: 32 * k))),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                const Spacer(),
                // 3. sıra: geri sayım paneli (ekranın %90'ı, ortada)
                Center(
                  child: SizedBox(
                    width: _bannerW(box.maxWidth),
                    child: GestureDetector(
                      onTap: () => _onTap(_items.first),
                      child: CountdownBanner(status: _status),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cityDate(DateTime now, AppLocation? loc, double k, List<Shadow> shadow) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(AppRoute(builder: (_) => const CityPickerScreen())),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.fromLTRB(2, 4 * k, 2, 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GoldIcon(Icons.location_on, size: 13 * k),
                  const SizedBox(width: 2),
                  Text(
                    loc?.name ?? 'Konum Seç',
                    maxLines: 1,
                    style:
                        TextStyle(color: Colors.white, fontSize: 14.5 * k, fontWeight: FontWeight.w700, shadows: shadow),
                  ),
                ],
              ),
              SizedBox(height: 2 * k),
              Text(
                '${formatDateTr(now)} · ${weekdayTr(now)}',
                maxLines: 1,
                style: TextStyle(color: Colors.white, fontSize: 11.5 * k, fontWeight: FontWeight.w600, shadows: shadow),
              ),
              SizedBox(height: 2 * k),
              Text(
                '${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
                style: TextStyle(
                  color: const Color(0xFFE8C88A),
                  shadows: shadow,
                  fontSize: 16 * k,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nisâ 103 (eski yazı tipiyle kalın italik); ayrılan alana sığmazsa küçülür, hiç gizlenmez.
  Widget _verse(double k, List<Shadow> shadow) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '“Şüphesiz namaz, müminler üzerine\nvakitleri belirlenmiş bir farzdır.”',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'serif',
              fontSize: 12.5 * k,
              fontWeight: FontWeight.w600,
              height: 1.25,
              fontStyle: FontStyle.italic,
              shadows: shadow,
            ),
          ),
          GoldText('Nisâ, 103', style: TextStyle(fontFamily: 'serif', fontSize: 10.5 * k, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Arka plan fotoğrafını, caminin kutunun ortasına geleceği şekilde hizalar.
  static Alignment _alignOn(Size box, double imgW, double imgH, double mosqueX, double mosqueY) {
    final scale = math.max(box.width / imgW, box.height / imgH);
    double axis(double frac, double scaled, double view) {
      final extra = scaled - view;
      if (extra <= 0.5) return 0;
      final offset = (frac * scaled - view / 2).clamp(0.0, extra);
      return offset / extra * 2 - 1;
    }

    return Alignment(axis(mosqueX, imgW * scale, box.width), axis(mosqueY, imgH * scale, box.height));
  }
}

/// Gündüz/gece geçiş tuşu. Vakte göre olan görünümün tersine geçer; yeniden basınca otomatiğe döner.
class _DayNightButton extends StatelessWidget {
  final double size;

  const _DayNightButton({required this.size});

  @override
  Widget build(BuildContext context) {
    final day = isDaytime();
    return Semantics(
      button: true,
      label: day ? 'Gece görünümüne geç' : 'Gündüz görünümüne geç',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // simgenin saydam yerleri de tuşa sayılır
        onTap: () {
          final toDay = !day;
          final mode = toDay == isDaytimeByClock() ? DayMode.otomatik : (toDay ? DayMode.gunduz : DayMode.gece);
          AppPrefs.instance.setDayMode(mode);
          showNote(
            context,
            mode == DayMode.otomatik
                ? 'Görünüm yine vakte göre değişecek'
                : '${toDay ? 'Gündüz' : 'Gece'} görünümü seçildi. Ayarlar\'dan Otomatik\'e alabilirsiniz.',
          );
        },
        // Diğer sayfaların başlığındaki gibi şeffaf altın simge: gündüzde ay (geceye geç), gecede güneş.
        child: Image.asset(
          day ? 'assets/images/ikon/imsak.webp' : 'assets/images/ikon/ikindi.webp',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Üst köşelerdeki hat levhası.
class _Medallion extends StatelessWidget {
  final String asset;
  final double size;

  const _Medallion(this.asset, {required this.size});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(asset, fit: BoxFit.contain);
    // Altın hat, açık gökyüzünde de seçilsin: arkasında hattın bulanık koyu gölgesi.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.translate(
            offset: const Offset(0, 1.5),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Color(0xB3000000), BlendMode.srcIn),
                child: image,
              ),
            ),
          ),
          image,
        ],
      ),
    );
  }
}

/// İlk açılışta çıkan "konumunu seç" penceresi.
class _LocationSheet extends StatefulWidget {
  const _LocationSheet();

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _useGps() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await LocationStore.instance.updateFromGps();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _pickCity() async {
    final navigator = Navigator.of(context);
    await navigator.push(AppRoute(builder: (_) => const CityPickerScreen()));
    if (LocationStore.instance.current != null && mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ArtIcon('cami', size: 60),
          const SizedBox(height: 12),
          const Text(
            'Hoş Geldiniz',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'EBGaramond',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Namaz vakitlerini doğru hesaplayabilmemiz için bulunduğunuz yeri seçin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFB4A8), fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _useGps,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.my_location),
              label: Text(_busy ? 'Konum bulunuyor...' : 'Konumumu Bul'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _pickCity,
              icon: const Icon(Icons.list),
              label: const Text('Şehri Listeden Seç'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.gold),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
