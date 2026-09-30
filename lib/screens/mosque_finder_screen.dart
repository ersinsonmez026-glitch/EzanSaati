import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_store.dart';
import '../services/mosque_store.dart';
import '../widgets/gold_icon.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'city_picker_screen.dart';
import '../services/app_theme.dart';

/// Cami Bulucu: yakındaki camiler (OpenStreetMap), uzaklık ve yön; yol tarifi harita uygulamasında.
class MosqueFinderScreen extends StatefulWidget {
  final MosqueStore? store;

  const MosqueFinderScreen({super.key, this.store});

  @override
  State<MosqueFinderScreen> createState() => _MosqueFinderScreenState();
}

class _MosqueFinderScreenState extends State<MosqueFinderScreen> {
  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  late final MosqueStore _store = widget.store ?? MosqueStore();
  final _location = LocationStore.instance;
  List<Mosque>? _items;
  String? _error;
  bool _loading = false;
  bool _gpsBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loc = _location.current;
    if (loc == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _store.near(loc.lat, loc.lng);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Camiler yüklenemedi. İnternet bağlantınızı kontrol edip tekrar deneyin ya da '
            'harita uygulamasında arayın.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useGps() async {
    setState(() => _gpsBusy = true);
    final error = await _location.updateFromGps();
    if (!mounted) return;
    setState(() => _gpsBusy = false);
    if (error != null) {
      showNote(context, error);
    } else {
      await _load();
    }
  }

  Future<void> _launch(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) showNote(context, 'Harita uygulaması açılamadı.');
  }

  /// Harita uygulamasında "cami" araması (uygulama içi liste açılamazsa).
  Future<void> _openMapSearch() async {
    final loc = _location.current;
    for (final uri in [
      Uri.parse('geo:${loc?.lat ?? 0},${loc?.lng ?? 0}?q=cami'),
      Uri.parse('https://www.google.com/maps/search/cami/${loc == null ? '' : '@${loc.lat},${loc.lng},14z'}'),
    ]) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    if (mounted) showNote(context, 'Harita uygulaması açılamadı.');
  }

  @override
  Widget build(BuildContext context) {
    final loc = _location.current;
    const gap = SizedBox(height: 10);
    return PageShell(
      title: 'Cami Bulucu',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: loc == null
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: PaperBox(
                  pal: _pal,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('Yakındaki camileri bulmak için önce konumunuzu seçin.',
                          textAlign: TextAlign.center, style: TextStyle(color: _pal.ink, fontSize: 15)),
                      const SizedBox(height: 14),
                      DarkButton(
                        label: 'Şehir Seç',
                        onTap: () async {
                          await Navigator.of(context).push(AppRoute(builder: (_) => const CityPickerScreen()));
                          if (mounted) {
                            setState(() {});
                            _load();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ]
          : [
              _hero(loc),
              if (!loc.fromGps) ...[gap, _gpsHint()],
              gap,
              if (_error != null)
                PaperBox(
                  pal: _pal,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Icon(Icons.wifi_off, color: _pal.gold, size: 36),
                      const SizedBox(height: 8),
                      Text(_error!,
                          textAlign: TextAlign.center, style: TextStyle(color: _pal.ink, fontSize: 14, height: 1.5)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: DarkButton(label: 'Tekrar dene', onTap: _load)),
                          const SizedBox(width: 8),
                          Expanded(child: DarkButton(label: 'Haritada ara', onTap: _openMapSearch)),
                        ],
                      ),
                    ],
                  ),
                )
              else if (_items == null || (_loading && _items!.isEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator(color: _pal.gold)),
                )
              else if (_items!.isEmpty)
                PaperBox(
                  pal: _pal,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text('10 km içinde kayıtlı cami bulunamadı.',
                          textAlign: TextAlign.center, style: TextStyle(color: _pal.ink, fontSize: 14)),
                      const SizedBox(height: 12),
                      DarkButton(label: 'Harita uygulamasında ara', onTap: _openMapSearch),
                    ],
                  ),
                )
              else
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: _pal.paperGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _pal.line),
                  ),
                  child: Column(
                    children: withDividers([for (final m in _items!) _row(m)], _pal.line),
                  ),
                ),
              gap,
              SourceNote(
                pal: _pal,
                text: 'Harita verisi © OpenStreetMap katkıcıları (ODbL). Uzaklıklar kuş uçuşudur; yol tarifi '
                    'telefonunuzdaki harita uygulamasında açılır. Listede olmayan camiler için "Haritada ara".',
              ),
              gap,
              Center(
                child: TextButton.icon(
                  onPressed: _openMapSearch,
                  icon: GoldIcon(Icons.map_outlined, size: 18, light: !_pal.night),
                  label: Text('Harita uygulamasında ara', style: TextStyle(color: _pal.gold)),
                ),
              ),
            ],
    );
  }

  Widget _hero(AppLocation loc) {
    final n = _items?.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: tc(0xFF062A1C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.gold(0.75), width: 1.5),
        image: const DecorationImage(
          image: AssetImage('assets/images/tiles/cami_bulucu.webp'),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x40000000),
              border: Border.all(color: RC.goldBorder, width: 1.5),
            ),
            child: const Center(child: ArtIcon('cami_bulucu', size: 40)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Yakındaki Camiler',
                    style: TextStyle(color: Colors.white, fontSize: 22, height: 1.15, fontWeight: FontWeight.w800)),
                Text(
                  n == null ? '${loc.name} çevresinde aranıyor…' : '${loc.name} çevresinde $n cami',
                  style: const TextStyle(color: RC.goldText, fontSize: 13),
                ),
              ],
            ),
          ),
          if (_loading && _items != null)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: RC.goldText)),
        ],
      ),
    );
  }

  Widget _gpsHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: _pal.paperGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _pal.line),
      ),
      child: Row(
        children: [
          GoldIcon(Icons.my_location, size: 22, light: !_pal.night),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Şehir merkezine göre aranıyor. Size en yakın camiler için konumunuzu kullanın.',
                style: TextStyle(color: _pal.ink, fontSize: 12.5, height: 1.4)),
          ),
          const SizedBox(width: 8),
          _gpsBusy
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _pal.gold))
              : PillButton(
                  pal: _pal,
                  selected: true,
                  onTap: _useGps,
                  child: const Text('Konumum', style: TextStyle(color: RC.bronzeText, fontWeight: FontWeight.w700)),
                ),
        ],
      ),
    );
  }

  Widget _row(Mosque m) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _pal.pill, borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: Transform.rotate(
                angle: m.bearing * 3.141592653589793 / 180,
                child: GoldIcon(Icons.navigation, size: 20, light: !_pal.night),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: TextStyle(color: _pal.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
                Text('${m.distanceText} · ${m.directionText}', style: TextStyle(color: _pal.ink2, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PillButton(
            pal: _pal,
            selected: false,
            onTap: () => _launch(m.directionsUri),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GoldIcon(Icons.directions_walk, size: 16, light: !_pal.night),
                const SizedBox(width: 4),
                Text('Yol tarifi', style: TextStyle(color: _pal.ink, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
