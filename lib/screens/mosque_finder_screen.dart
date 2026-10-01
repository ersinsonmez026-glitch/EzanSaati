import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_store.dart';
import '../services/mosque_store.dart';
import '../widgets/gold_icon.dart';
import '../widgets/mosque_map.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'city_picker_screen.dart';
import '../services/app_theme.dart';

/// Cami Bulucu: üstte uygulamanın içinde harita (ekranın yarısı), altta yakındaki camiler (OpenStreetMap).
/// Listeden bir camiye dokununca harita o camiyi, "Yol tarifi" deyince yürüme yolunu gösterir; uygulamadan çıkılmaz.
class MosqueFinderScreen extends StatefulWidget {
  final MosqueStore? store;
  final GooglePlaces? places;

  const MosqueFinderScreen({super.key, this.store, this.places});

  @override
  State<MosqueFinderScreen> createState() => _MosqueFinderScreenState();
}

class _MosqueFinderScreenState extends State<MosqueFinderScreen> {
  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  late final MosqueStore _store = widget.store ?? MosqueStore();
  late final GooglePlaces _places = widget.places ?? GooglePlaces();
  bool _fromGoogle = false; // liste Google Haritalar'dan mı geldi
  final _location = LocationStore.instance;
  List<Mosque>? _items;
  String? _error;
  bool _loading = false;
  bool _gpsBusy = false;
  Mosque? _selected; // haritada gösterilen cami (yoksa çevredeki bütün camiler)
  bool _route = false; // seçili camiye yol tarifi

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
      // Önce Google (adlarıyla, eksiksiz); kullanılamıyorsa OpenStreetMap'te adı kayıtlı en yakın camiler.
      final google = await _places.near(loc.lat, loc.lng);
      if (google != null && google.isNotEmpty) {
        if (mounted) {
          setState(() {
            _items = google;
            _fromGoogle = true;
          });
        }
        return;
      }
      final all = await _store.near(loc.lat, loc.lng);
      final named = all.where((m) => m.name != Mosque.unnamed).toList();
      if (mounted) {
        setState(() {
          _items = (named.isEmpty ? all : named).take(GooglePlaces.resultCount).toList();
          _fromGoogle = false;
        });
      }
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
              _mapCard(loc),
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
                text: _fromGoogle
                    ? 'Harita ve liste: Google Haritalar. Uzaklıklar kuş uçuşudur.'
                    : 'Harita: Google Haritalar. Liste: © OpenStreetMap katkıcıları (ODbL). Uzaklıklar kuş uçuşudur. '
                        'Listede olmayan camiler haritada adlarıyla görünür.',
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

  /// Üstte, ekranın yaklaşık yarısında harita ve ne gösterdiğini anlatan şerit.
  Widget _mapCard(AppLocation loc) {
    final m = _selected;
    final url = m == null
        ? MosqueMap.search(loc.lat, loc.lng)
        : _route
            ? MosqueMap.route(loc.lat, loc.lng, m.lat, m.lng)
            : MosqueMap.place(m.lat, m.lng);
    final n = _items?.length;
    final h = (MediaQuery.sizeOf(context).height * 0.46).clamp(260.0, 520.0);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tc(0xFF062A1C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.gold(0.75), width: 1.5),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(children: [
            GoldIcon(m == null ? Icons.mosque : (_route ? Icons.directions_walk : Icons.place), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                m == null
                    ? (n == null ? '${loc.name} çevresinde aranıyor…' : 'Size en yakın $n cami')
                    : (_route ? '${m.name} · yürüyüş yolu' : '${m.name} · ${m.distanceText}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            if (_loading && _items != null)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: RC.goldText)),
              ),
            if (m != null)
              PillButton(
                pal: _pal,
                selected: true,
                height: 30,
                onTap: () => setState(() {
                  _selected = null;
                  _route = false;
                }),
                child: const Text('Tümü',
                    style: TextStyle(color: RC.bronzeText, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        SizedBox(height: h, child: MosqueMap(url: url)),
      ]),
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
    final on = _selected == m;
    return InkWell(
      onTap: () => setState(() {
        _selected = m;
        _route = false;
      }),
      child: Container(
        color: on ? _pal.gold.withValues(alpha: 0.14) : null,
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
              selected: on && _route,
              onTap: () => setState(() {
                _selected = m;
                _route = true;
              }),
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
      ),
    );
  }
}
