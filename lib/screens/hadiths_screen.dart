import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../services/hadith_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'hadith_read_screen.dart';

/// Hadisler (onizleme/08-hadisler.html): günün hadisi, Tüm Hadisler / Favorilerim, arama.
/// Metinler Diyanet'in "Hadislerle İslâm" eserinden değiştirilmeden alınır (bkz. HadithStore).
class HadithsScreen extends StatefulWidget {
  /// Testlerde sahte kaynak verilebilir.
  final HadithStore? store;

  /// Dualar sayfasının "Hadisler" sekmesinde: sayfa başlığı ve kendi arama kutusu olmadan, [query] ile.
  final bool embedded;
  final String query;

  const HadithsScreen({super.key, this.store, this.embedded = false, this.query = ''});

  @override
  State<HadithsScreen> createState() => _HadithsScreenState();
}

class _HadithsScreenState extends State<HadithsScreen> {
  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  late final HadithStore _store = widget.store ?? const HadithStore();
  List<Hadith>? _items;
  ReadingPrefs? _prefs;
  String? _error;
  bool _loading = true;
  String _query = '';
  bool _onlyFav = false;
  String? _topic; // seçili konu başlığı; null: tümü

  @override
  void initState() {
    super.initState();
    ReadingPrefs.get().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Önce telefonda saklananlar hemen gösterilir, sonra kaynaktan yenilenir.
    final cached = await _store.cached();
    if (mounted && cached.isNotEmpty && _items == null) _set(cached);
    try {
      final items = await _store.load(force: force);
      if (mounted) _set(items);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Hadisler açılamadı.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _set(List<Hadith> items) {
    setState(() => _items = items);
  }

  Set<String> get _favs => _prefs?.favorites(kHadithFavKey) ?? const {};

  void _toggleFav(Hadith h) {
    final on = _prefs?.toggleFavorite(kHadithFavKey, h.id) ?? false;
    setState(() {});
    showNote(context, on ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı');
  }

  Future<void> _open(List<Hadith> list, int index) async {
    await Navigator.of(context).push(AppRoute(builder: (_) => HadithReadScreen(items: list, index: index)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items == null
            ? [
                if (_error == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Center(child: CircularProgressIndicator(color: _pal.gold)),
                  )
                else
                  _errorBox(),
              ]
            : _content(items),
      );
    }
    return PageShell(
      title: 'Hadisler',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: items == null
          ? [
              if (_error == null)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator(color: _pal.gold)),
                )
              else
                _errorBox(),
            ]
          : _content(items),
    );
  }

  Widget _errorBox() {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: PaperBox(
        pal: _pal,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.wifi_off, color: _pal.gold, size: 40),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: _pal.ink, fontSize: 14, height: 1.5)),
            const SizedBox(height: 14),
            DarkButton(label: 'Tekrar dene', onTap: _load),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(List<Hadith> items) {
    const gap = SizedBox(height: 10);
    final favs = _favs;
    final q = trSearchKey((widget.embedded ? widget.query : _query).trim());
    final shown = [
      for (var i = 0; i < items.length; i++)
        if ((!_onlyFav || favs.contains(items[i].id)) &&
            (_topic == null || items[i].topic == _topic) &&
            (q.isEmpty || trSearchKey('${items[i].text} ${items[i].attribution} ${items[i].topic}').contains(q)))
          i,
    ];
    return [
      Row(
        children: [
          for (final (fav, label) in const [(false, 'Tüm Hadisler'), (true, 'Favorilerim')]) ...[
            if (fav) const SizedBox(width: 6),
            Expanded(
              child: PillButton(
                pal: _pal,
                selected: _onlyFav == fav,
                height: 38,
                onTap: () => setState(() => _onlyFav = fav),
                child: Text(label,
                    style: TextStyle(
                        color: _onlyFav == fav ? RC.bronzeText : _pal.ink, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
      gap,
      if (!widget.embedded) ...[
        SearchBox(pal: _pal, hint: 'Hadislerde ara', onChanged: (v) => setState(() => _query = v)),
        gap,
        _topicButton(items),
        gap,
      ],
      PaperBox(
        pal: _pal,
        child: shown.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(22),
                child: Text(
                  _onlyFav && q.isEmpty
                      ? 'Henüz favori hadisiniz yok. Kalp simgesine dokunarak ekleyebilirsiniz.'
                      : 'Aradığınız hadis bulunamadı.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _pal.ink2, fontSize: 13.5),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: withDividers([
                  for (var k = 0; k < shown.length; k++)
                    _row(items, shown[k], k + 1, favs.contains(items[shown[k]].id)),
                ], _pal.line),
              ),
      ),
      if (_loading) ...[
        gap,
        Center(
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _pal.gold))),
      ],
      gap,
      SourceNote(
        pal: _pal,
        text: 'Kaynak: Diyanet İşleri Başkanlığı, Hadislerle İslâm (hadislerleislam.diyanet.gov.tr). Eserde '
            'Hz. Peygamber\'in sözü olarak verilen ve dipnotta Kütüb-i Sitte\'ye dayandırılan ${items.length} hadis, '
            'eserdeki konu başlıklarıyla ve metinleri değiştirilmeden gösterilir.',
      ),
    ];
  }

  /// Konu seçimi: eserdeki konu başlıkları (alfabetik, hadis sayısıyla); "Tüm konular" ile kaldırılır.
  Widget _topicButton(List<Hadith> items) {
    return PillButton(
      pal: _pal,
      selected: _topic != null,
      height: 40,
      onTap: () => _pickTopic(items),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.topic_outlined, size: 18, color: _topic != null ? RC.bronzeText : _pal.gold),
        const SizedBox(width: 6),
        Flexible(
          child: Text(_topic == null ? 'Konu seç (tüm konular)' : 'Konu: $_topic',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: _topic != null ? RC.bronzeText : _pal.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
        Icon(Icons.expand_more, size: 20, color: _topic != null ? RC.bronzeText : _pal.ink2),
      ]),
    );
  }

  Future<void> _pickTopic(List<Hadith> items) async {
    final counts = <String, int>{};
    for (final h in items) {
      counts[h.topic] = (counts[h.topic] ?? 0) + 1;
    }
    final topics = counts.keys.toList()..sort((a, b) => trSearchKey(a).compareTo(trSearchKey(b)));
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _pal.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        var filter = '';
        return StatefulBuilder(builder: (ctx, setSheet) {
          final shown = [for (final t in topics) if (filter.isEmpty || trSearchKey(t).contains(filter)) t];
          return SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.8,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                child: SearchBox(
                    pal: _pal, hint: 'Konu ara (${topics.length} konu)', onChanged: (v) => setSheet(() => filter = trSearchKey(v.trim()))),
              ),
              ListTile(
                key: const Key('topicAll'),
                title: Text('Tüm konular', style: TextStyle(color: _pal.ink, fontWeight: FontWeight.w700)),
                trailing: Text('${items.length}', style: TextStyle(color: _pal.ink2)),
                onTap: () => Navigator.of(ctx).pop(''),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (ctx, i) => ListTile(
                    dense: true,
                    title: Text(shown[i], style: TextStyle(color: _pal.ink, fontSize: 14.5)),
                    trailing: Text('${counts[shown[i]]}', style: TextStyle(color: _pal.ink2)),
                    selected: shown[i] == _topic,
                    onTap: () => Navigator.of(ctx).pop(shown[i]),
                  ),
                ),
              ),
            ]),
          );
        });
      },
    );
    if (picked != null && mounted) setState(() => _topic = picked.isEmpty ? null : picked);
  }

  Widget _row(List<Hadith> items, int index, int n, bool fav) {
    final h = items[index];
    return InkWell(
      onTap: () => _open(items, index),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        child: Row(
          children: [
            OctaBadge(number: n, size: 32, color: _pal.gold, textColor: _pal.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('“${h.text}”',
                      style: TextStyle(color: _pal.ink, fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w700)),
                  Text('${h.topic} · ${h.attribution}', style: TextStyle(color: _pal.ink2, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HeartButton(pal: _pal, on: fav, label: h.text, onTap: () => _toggleFav(h)),
          ],
        ),
      ),
    );
  }
}
