import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_prefs.dart';
import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../theme.dart';
import '../widgets/countdown_banner.dart';
import '../widgets/menu_tile.dart';
import '../widgets/page_shell.dart';
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
            double gridFor(double tileH) => _rows * tileH + (_rows - 1) * gap + pad + 2;

            // Tuşlar her ekranda resimleriyle aynı oranda (600 x 508): resimler hiç kesilmez. Kalan yükseklik
            // üst alana (fotoğraf, ayet, konum/saat, geri sayım) verilir; fotoğraf gerekirse üstten kesilir.
            final tileH = tileW * MenuTile.photoAspect;
            final gridH = gridFor(tileH);
            final labelSize = MenuTile.fitLabelSize(_items.map((e) => e.title), tileW);
            final heroH = math.max(_heroMin(w, k), h - gridH);
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
                      padding: const EdgeInsets.fromLTRB(pad, 2, pad, pad),
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
  static double _bannerW(double w) => math.min(w * 0.92, 520);
  // En az: geri sayım paneli ve üstünde ayet/konum yazıları kadar; daha kısa ekranda sayfa kayar.
  static double _heroMin(double w, double k) => _bannerW(w) / CountdownBanner.aspect + 2 + 70 * k;

  Widget _hero(DateTime now, AppLocation? loc, double k, List<Shadow> shadow) {
    return LayoutBuilder(builder: (context, box) {
      final bannerH = _bannerW(box.maxWidth) / CountdownBanner.aspect;
      // Caminin tabanı geri sayım panelinin hemen üstüne oturur; fotoğraf gerekirse üstten kesilir.
      final mosqueBase = box.maxHeight - bannerH + 4 * k;
      return Stack(
        children: [
          _heroPhoto(box.biggest, mosqueBase),
          // Ayet sol üstte, konum/tarih/saat sağ üstte; caminin iki yanında fotoğrafın üstünde durur.
          Positioned(
            left: 12,
            top: 2,
            child: _verse(k, shadow),
          ),
          Positioned(
            right: 10,
            top: 2,
            child: _cityDate(now, loc, k, shadow),
          ),
          Column(
            children: [
              const Spacer(),
              // Geri sayım paneli (ekranın %92'si, ortada, tuşlara yaslı)
              Center(
                child: SizedBox(
                  width: _bannerW(box.maxWidth),
                  child: GestureDetector(
                    onTap: () => _onTap(_items.first),
                    child: CountdownBanner(status: _status),
                  ),
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
          // Gündüz/gece düğmesi sağda, geri sayım panelinin kenarının üstünde
          Positioned(
            right: 10,
            bottom: 2 + bannerH * (1 - CountdownBanner.sideTop) + 4 * k,
            child: DayNightSwitch(height: 26 * k),
          ),
        ],
      );
    });
  }

  /// Arka plan fotoğrafı: caminin tabanı (görselde %54, %64) kutuda [mosqueY] yüksekliğine gelir;
  /// fotoğraf kutuyu her zaman tamamen kaplar (gece ve gündüz aynı kadraj).
  Widget _heroPhoto(Size box, double mosqueY) {
    const imgW = 1536.0, imgH = 1024.0, fx = 0.54, fy = 0.64;
    final scale = [box.width / imgW, box.height / imgH, mosqueY / (fy * imgH), (box.height - mosqueY) / ((1 - fy) * imgH)]
        .reduce(math.max);
    final w = imgW * scale, h = imgH * scale;
    final left = (box.width / 2 - fx * w).clamp(box.width - w, 0.0);
    final top = (mosqueY - fy * h).clamp(box.height - h, 0.0);
    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: Image.asset(
        isDaytime() ? 'assets/images/home_hero.jpg' : 'assets/images/home_hero_gece.jpg',
        fit: BoxFit.fill,
      ),
    );
  }

  Widget _cityDate(DateTime now, AppLocation? loc, double k, List<Shadow> shadow) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(AppRoute(builder: (_) => const CityPickerScreen())),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GoldIcon(Icons.location_on, size: 11 * k),
                  const SizedBox(width: 2),
                  Text(
                    loc?.name ?? 'Konum Seç',
                    maxLines: 1,
                    style:
                        TextStyle(color: Colors.white, fontSize: 12.5 * k, fontWeight: FontWeight.w700, shadows: shadow),
                  ),
                ],
              ),
              SizedBox(height: 2 * k),
              Text(
                '${formatDateTr(now)} · ${weekdayTr(now)}',
                maxLines: 1,
                style: TextStyle(color: Colors.white, fontSize: 10 * k, fontWeight: FontWeight.w600, shadows: shadow),
              ),
              SizedBox(height: 2 * k),
              Text(
                '${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
                style: TextStyle(
                  color: const Color(0xFFE8C88A),
                  shadows: shadow,
                  fontSize: 13.5 * k,
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
      alignment: Alignment.topLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Satırlar aşağı doğru uzar
          Text(
            '“Şüphesiz namaz,\nmüminler üzerine\nvakitleri belirlenmiş\nbir farzdır.”',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'serif',
              fontSize: 9.5 * k,
              fontWeight: FontWeight.w600,
              height: 1.25,
              fontStyle: FontStyle.italic,
              shadows: shadow,
            ),
          ),
          GoldText('Nisâ, 103', style: TextStyle(fontFamily: 'serif', fontSize: 8.5 * k, fontWeight: FontWeight.w600)),
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
