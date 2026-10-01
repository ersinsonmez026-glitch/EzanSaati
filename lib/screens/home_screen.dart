import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_prefs.dart';
import '../services/location_store.dart';
import '../services/prayer_groups.dart';
import '../services/prayer_calc.dart';
import '../theme.dart';
import '../widgets/countdown_banner.dart';
import '../widgets/menu_tile.dart';
import '../widgets/page_shell.dart';
import 'city_picker_screen.dart';
import 'dhikr_screen.dart';
import 'dua_circle_screen.dart';
import 'tracking_screen.dart';
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
import '../services/app_theme.dart';

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
    _MenuItem('takibim', 'Takibim', 'takvim', () => const TrackingScreen()),
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

  /// İlk açılışta önce adı (Dua Zinciri'nde görünecek ad), sonra konumu sorar.
  Future<void> _askLocationIfNeeded() async {
    if (_location.current != null || !mounted) return;
    await GroupSync.instance.load();
    if (GroupSync.instance.myName.isEmpty && mounted) {
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: AppColors.darkGreen,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => const _NameSheet(),
      );
    }
    if (!mounted) return;
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
    final loc = _location.current;
    const shadow = [Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(1, 1))];

    // Uygulamanın yazı tipi Lora.
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Lora'),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Lora'),
      ),
      child: Scaffold(
        backgroundColor: isDaytime() ? const Color(0xFFD8C59C) : tc(0xFF03170F), // koyu krem / gece yeşili
        // Fotoğraf durum çubuğunun (saat, pil) arkasına kadar uzanır; ekran üstten kesilmiş görünmez.
        body: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, box) {
            final topInset = MediaQuery.paddingOf(context).top;
            final w = box.maxWidth, h = box.maxHeight - topInset;
            final k = (w / 390).clamp(0.8, 1.4); // yazı ve levha ölçeği (iPhone 390 genişlik esas)
            const gap = 6.0, pad = 6.0;
            final tileW = (w - 2 * pad - 2 * gap) / 3;
            double gridFor(double tileH) => _rows * tileH + (_rows - 1) * gap + pad + 2;

            // Tuşlar resimleriyle aynı oranda (600 x 508). Kalan yükseklik üst alana (fotoğraf, ayet, konum,
            // geri sayım) verilir; fotoğraf gerekirse üstten kesilir. Kısa ekranda cami görünsün diye tuşlar
            // biraz alçalır (en çok %20); resimleri yalnız alttan kesilir.
            final fullTileH = tileW * MenuTile.photoAspect;
            final roomTile = (h - _heroMin(w, k) - (_rows - 1) * gap - pad - 2) / _rows;
            final tileH = math.min(fullTileH, math.max(fullTileH * 0.8, roomTile));
            final gridH = gridFor(tileH);
            // Tüm isimler aynı boyutta; boyutu en uzun isim değil ikinci en uzun isim belirler (en uzun isim
            // levhaya sığmak için kendiliğinden biraz küçülür), böylece yazılar gereğinden küçük kalmaz.
            final fits = [for (final e in _items) MenuTile.fitLabelSize([e.title], tileW)]..sort();
            double labelSize(String _) => fits[1];
            final heroH = math.max(_heroMin(w, k), h - gridH) + topInset;
            // Çok kısa ekranlarda (ör. yatay) sığmazsa kaydırılabilir; normalde kaydırma yok.
            final scrolls = heroH - topInset + gridH > h + 0.5;

            return SingleChildScrollView(
              physics: scrolls ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: heroH, child: _hero(loc, k, shadow, topInset)),
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
                          labelSize: labelSize(item.title),
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
  static double _bannerW(double w) => math.min(w * 0.96, 540);
  // En az: geri sayım paneli ve caminin tamamı görünecek kadar (kısa ekranda tuşlar alçalır).
  static double _heroMin(double w, double k) => _bannerW(w) / CountdownBanner.aspect + 2 + 125 * k;

  Widget _hero(AppLocation? loc, double k, List<Shadow> shadow, double topInset) {
    return LayoutBuilder(builder: (context, box) {
      final bannerH = _bannerW(box.maxWidth) / CountdownBanner.aspect;
      // Caminin tabanı "kalan" satırının hemen üstüne oturur (alt tarafı görünür); fotoğraf gerekirse üstten kesilir.
      final mosqueBase = box.maxHeight - 2 - bannerH;
      return Stack(
        children: [
          _heroPhoto(box.biggest, mosqueBase),
          // Ayet sol altta: alt kenarı vakit kartlarına değer. Kalan süre üst ortada, konum sağ üstte.
          Positioned(
            left: 12,
            bottom: 2 + bannerH * (1 - CountdownBanner.sideTop) + 3 * k,
            child: _verse(k, shadow),
          ),
          // Sonraki vakte kalan süre: üst ortada
          Positioned(
            left: 0,
            right: 0,
            top: topInset + 26 * k,
            child: Center(child: RemainingLine(status: _status, k: k)),
          ),
          Positioned(
            right: 10,
            top: topInset + 64 * k,
            child: _locationLabel(loc, k, shadow),
          ),
          Column(
            children: [
              const Spacer(),
              // Kalan süre satırı ve vakit kartları (ekranın %96'sı, ortada, tuşlara yaslı)
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
          // Gündüz/gece düğmesi: her ekranda sağda, geri sayım çerçevesinin sağ kenarının biraz üstünde
          Positioned(
            right: 12,
            bottom: 2 + bannerH * (1 - CountdownBanner.sideTop) + 5 * k,
            child: DayNightSwitch(height: 24 * k, labels: true),
          ),
        ],
      );
    });
  }

  /// Arka plan fotoğrafı: caminin tabanı (görselde %54, %66) kutuda [mosqueY] yüksekliğine gelir;
  /// fotoğraf kutuyu her zaman tamamen kaplar (gece ve gündüz aynı kadraj).
  Widget _heroPhoto(Size box, double mosqueY) {
    const imgW = 1536.0, imgH = 1024.0, fx = 0.54, fy = 0.66;
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
        isDaytime() ? 'assets/images/home_hero.webp' : 'assets/images/home_hero_gece.webp',
        fit: BoxFit.fill,
      ),
    );
  }

  /// Sağ üstteki konum; dokununca şehir seçimi açılır.
  Widget _locationLabel(AppLocation? loc, double k, List<Shadow> shadow) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(AppRoute(builder: (_) => const CityPickerScreen())),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GoldIcon(Icons.location_on, size: 17 * k),
            const SizedBox(width: 2),
            Text(
              loc?.name ?? 'Konum Seç',
              maxLines: 1,
              style: TextStyle(color: Colors.white, fontSize: 17.5 * k, fontWeight: FontWeight.w700, shadows: shadow),
            ),
          ],
        ),
      ),
    );
  }


  /// Nisâ 103 (eski yazı tipiyle kalın italik); ayrılan alana sığmazsa küçülür, hiç gizlenmez.
  Widget _verse(double k, List<Shadow> shadow) {
    // Satırlar aşağı doğru uzar; kaynak son satırın yanında (altındaki kalan süre satırına yer kalsın).
    return Text.rich(
      TextSpan(children: [
        const TextSpan(text: '“Şüphesiz namaz,\nmüminler üzerine\nvakitleri belirlenmiş\nbir farzdır.”\n'),
        TextSpan(
          text: 'Nisâ, 103',
          style: TextStyle(
              color: const Color(0xFFE8C88A), fontSize: 9.5 * k, fontStyle: FontStyle.normal, fontWeight: FontWeight.w700),
        ),
      ]),
      style: TextStyle(
        color: Colors.white,
        fontFamily: 'Lora',
        fontSize: 11 * k,
        fontWeight: FontWeight.w600,
        height: 1.25,
        fontStyle: FontStyle.italic,
        shadows: shadow,
      ),
    );
  }

}

/// İlk açılışta çıkan "adınız" penceresi: Dua Zinciri gruplarında görünecek ad.
class _NameSheet extends StatefulWidget {
  const _NameSheet();

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _ctrl.text.trim();
    if (n.isEmpty) return;
    final navigator = Navigator.of(context);
    await GroupSync.instance.saveName(n);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ArtIcon('cami', size: 60),
          const SizedBox(height: 12),
          const Text(
            'Hoş Geldiniz',
            style: TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.w700, fontFamily: 'Lora'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adınız nedir? Dua Zinciri\'nde birlikte okuduğunuz kişiler sizi bu adla görür. '
            'Sonradan değiştirebilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.35),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: 40,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            style: const TextStyle(color: Colors.white, fontSize: 17),
            decoration: InputDecoration(
              hintText: 'Örn. Ayşe Demir',
              hintStyle: const TextStyle(color: Colors.white38),
              counterText: '',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _ctrl.text.trim().isEmpty ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: const Text('Devam'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Şimdilik geç', style: TextStyle(color: Colors.white60, fontSize: 14)),
          ),
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
              fontFamily: 'Lora',
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
