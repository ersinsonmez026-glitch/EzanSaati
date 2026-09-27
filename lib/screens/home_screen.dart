import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_prefs.dart';
import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../theme.dart';
import '../widgets/countdown_banner.dart';
import '../widgets/menu_tile.dart';
import 'city_picker_screen.dart';
import 'coming_soon_screen.dart';
import 'dhikr_screen.dart';
import 'learn_namaz_screen.dart';
import 'prayer_times_screen.dart';
import 'prayers_screen.dart';
import 'qibla_screen.dart';
import 'settings_screen.dart';
import 'surahs_screen.dart';

/// Ana ekrandaki bir tuş: görseli, adı ve açacağı sayfa.
class _MenuItem {
  final String image;
  final String title;
  final IconData icon;
  final Widget Function()? page;

  const _MenuItem(this.image, this.title, this.icon, this.page);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Tuşların sırası burada. Yer değiştirmek için satırların sırasını değiştir.
  static final List<_MenuItem> _items = [
    _MenuItem('namaz_vakitleri', 'Namaz Vakitleri', Icons.schedule, () => const PrayerTimesScreen()),
    _MenuItem('sureler', 'Sureler', Icons.menu_book, () => const SurahsScreen()),
    _MenuItem('dualar', 'Dualar', Icons.volunteer_activism, () => const PrayersScreen()),
    _MenuItem('namaz_ogren', 'Namaz Öğren', Icons.mosque, () => const LearnNamazScreen()),
    _MenuItem('zikir_sayaci', 'Zikir Sayacı', Icons.touch_app, () => const DhikrScreen()),
    _MenuItem('kible_bulucu', 'Kıble Bulucu', Icons.explore, () => const QiblaScreen()),
    _MenuItem('hadisler', 'Hadisler', Icons.auto_stories, null),
    _MenuItem('dini_mesajlar', 'Dini Mesajlar', Icons.mail_outline, null),
    _MenuItem('dua_cemberi', 'Dua Çemberi', Icons.groups, null),
    _MenuItem('ramazan', 'Ramazan', Icons.nightlight_round, null),
    _MenuItem('cami_bulucu', 'Cami Bulucu', Icons.place, null), // Harita uygulamasını açar
    _MenuItem('ilahiler', 'İlahiler', Icons.music_note, null),
    _MenuItem('dini_hikayeler', 'Dini Hikâyeler', Icons.menu_book_outlined, null),
    _MenuItem('ayarlar', 'Ayarlar', Icons.settings, () => const SettingsScreen()),
  ];

  // Görseli henüz hazırlanmamış tuşlar
  static const _noPhoto = <String>{};

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

  Future<void> _openMosqueFinder() async {
    final messenger = ScaffoldMessenger.of(context);
    final loc = _location.current;
    final uris = <Uri>[
      Uri.parse('geo:${loc?.lat ?? 0},${loc?.lng ?? 0}?q=cami'),
      Uri.parse('https://www.google.com/maps/search/cami/'
          '${loc == null ? '' : '@${loc.lat},${loc.lng},14z'}'),
    ];
    for (final uri in uris) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        // Sıradakini dene
      }
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Harita uygulaması açılamadı.')),
    );
  }

  void _onTap(_MenuItem item) {
    if (item.image == 'cami_bulucu') {
      _openMosqueFinder();
      return;
    }
    final page = item.page?.call() ??
        ComingSoonScreen(
          title: item.title,
          image: _noPhoto.contains(item.image) ? null : 'assets/images/tiles/${item.image}.jpg',
        );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final loc = _location.current;
    const shadow = [Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(1, 1))];

    return Scaffold(
      backgroundColor: const Color(0xFFD8C59C), // koyu krem
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          // Tuş alanının yüksekliği: 5 sıra, 3 sütun
          const gap = 6.0, pad = 6.0;
          final tileW = (box.maxWidth - 2 * pad - 2 * gap) / 3;
          final rows = ((_items.length + 1) / 3).ceil();
          final gridH = rows * tileW / 1.3 + (rows - 1) * gap + 2 * pad;
          // Üst görsel en az 300 olsun; ekran kısaysa sayfa kaydırılır
          final heroH = math.max(300.0, box.maxHeight - gridH);
          return SingleChildScrollView(
            physics: heroH + gridH > box.maxHeight + 1
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: Column(
          children: [
            // ============================================================
            // ÜST YARI - ANA GÖRSEL + GERİ SAYIM
            // ============================================================
            SizedBox(
              height: heroH,
              child: Stack(
                children: [
                  // Arka plan: cami her ekran boyunda ortada dursun
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, box) => Image.asset(
                        'assets/images/home_hero.jpg',
                        fit: BoxFit.cover,
                        alignment: _heroAlignment(box.biggest),
                      ),
                    ),
                  ),

                  // Üst sıra: sol levha · şehir / tarih / saat · sağ levha
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tasarımdaki düzen: solda "Allah", sağda "Muhammed"
                        const _Medallion('assets/images/levha_allah.png'),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CityPickerScreen()),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.location_on,
                                          color: Colors.white, size: 20, shadows: shadow),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        child: Text(
                                          loc?.name ?? 'Konum Seç',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            shadows: shadow,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${formatDateTr(now)} · ${weekdayTr(now)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      shadows: shadow,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
                                    style: const TextStyle(
                                      color: AppColors.goldLight,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                      shadows: shadow,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const _Medallion('assets/images/levha_muhammed.png'),
                      ],
                    ),
                  ),

                  // Alt kısım: ayet + geri sayım şeridi
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ayet: satırlar yukarıdan aşağı genişler
                        const Padding(
                          padding: EdgeInsets.only(left: 14, bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '“Şüphesiz\nnamaz, müminler\nüzerine vakitleri\nbelirlenmiş bir farzdır.”',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                  fontStyle: FontStyle.italic,
                                  shadows: shadow,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Nisâ, 103',
                                style: TextStyle(
                                  color: AppColors.goldLight,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  shadows: shadow,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _onTap(_items.first),
                          child: FractionallySizedBox(
                            widthFactor: 0.86,
                            child: CountdownBanner(status: _status),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ============================================================
            // ALT KISIM - 12 TUŞ (kaydırmasız, kendi yüksekliği kadar)
            // ============================================================
            GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(6),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.3,
                ),
                itemCount: _items.length + 1, // son yer yeni özellik için boş
                itemBuilder: (context, index) {
                  if (index == _items.length) return const EmptyTile();
                  final item = _items[index];
                  return MenuTile(
                    image: item.image,
                    title: item.title,
                    icon: item.icon,
                    style: AppPrefs.instance.tileStyle,
                    hasPhoto: !_noPhoto.contains(item.image),
                    onTap: () => _onTap(item),
                  );
                },
              ),
          ],
            ),
          );
        }),
      ),
    );
  }

  /// Arka plan fotoğrafını, caminin kutunun ortasına geleceği şekilde hizalar.
  static Alignment _heroAlignment(Size box) {
    const imgW = 1536.0, imgH = 1024.0;
    const mosqueX = 0.54, mosqueY = 0.62; // caminin fotoğraftaki yeri (oran)
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

/// Üst köşelerdeki hat levhası.
class _Medallion extends StatelessWidget {
  final String asset;

  const _Medallion(this.asset);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 12, spreadRadius: -4)],
        ),
        child: Image.asset(asset, fit: BoxFit.contain),
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
    await navigator.push(MaterialPageRoute(builder: (_) => const CityPickerScreen()));
    if (LocationStore.instance.current != null && mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mosque, color: AppColors.gold, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Hoş Geldiniz',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'serif',
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
