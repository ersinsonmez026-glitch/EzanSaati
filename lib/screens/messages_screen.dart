import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../services/takvim.dart';
import '../widgets/message_card.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'message_share_screen.dart';
import '../widgets/gold_icon.dart';

/// Dini Mesajlar: günün mesajı, arama, kategori ve favoriler, kart ızgarası.
/// Tasarım: onizleme/09-dini-mesajlar.html · Veri: assets/data/mesajlar.json (96 mesaj)
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  static const _catKey = 'mesaj_kategori';
  static const _favFilter = 'favori';

  final _pal = PagePalette.current();
  List<ReligiousMessage>? _all;
  ReadingPrefs? _prefs;
  String _query = '';
  String _cat = 'tum';
  int _dayIdx = 0;

  @override
  void initState() {
    super.initState();
    Future.wait([MessageData.all(), ReadingPrefs.get(), TakvimData.load()]).then((r) {
      if (!mounted) return;
      final all = r[0] as List<ReligiousMessage>;
      final prefs = r[1] as ReadingPrefs;
      final takvim = r[2] as TakvimData;
      final saved = prefs.getString(_catKey);
      setState(() {
        _all = all;
        _prefs = prefs;
        _dayIdx = dailyMessageIndex(all, DateTime.now(), takvim.religious);
        if (saved != null && (saved == 'tum' || saved == _favFilter || kMessageCategories.containsKey(saved))) {
          _cat = saved;
        }
      });
    });
  }

  Set<String> get _favs => _prefs?.favorites(kMessageFavKey) ?? const {};

  void _toggleFav(ReligiousMessage m) {
    final on = _prefs?.toggleFavorite(kMessageFavKey, '${m.index}') ?? false;
    setState(() {});
    showNote(context, on ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı');
  }

  void _setCat(String c) {
    setState(() => _cat = c);
    _prefs?.setString(_catKey, c);
  }

  List<ReligiousMessage> _filtered(List<ReligiousMessage> all) {
    final q = trSearchKey(_query.trim());
    final favs = _favs;
    return [
      for (final m in all)
        if ((_cat == 'tum' || (_cat == _favFilter ? favs.contains('${m.index}') : m.category == _cat)) &&
            (q.isEmpty ||
                trSearchKey('${m.title} ${m.body ?? ''} ${m.verse ?? ''} ${m.verseRef ?? ''}').contains(q)))
          m,
    ];
  }

  Future<void> _open(List<ReligiousMessage> list, int i) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MessageShareScreen(messages: list, index: i)),
    );
    if (mounted) setState(() {}); // favoriler değişmiş olabilir
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    return PageShell(
      title: 'Dini Mesajlar',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: all == null
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : _content(all),
    );
  }

  List<Widget> _content(List<ReligiousMessage> all) {
    const gap = SizedBox(height: 10);
    final list = _filtered(all);
    return [
      SearchBox(pal: _pal, hint: 'Mesaj ara (ör. cuma, kandil, bayram)', onChanged: (v) => setState(() => _query = v)),
      gap,
      _dailyCard(all),
      gap,
      _chips(all),
      gap,
      SectionHead(
        pal: _pal,
        title: _query.trim().isNotEmpty
            ? 'Arama sonuçları'
            : _cat == _favFilter
                ? 'Favori Mesajlar'
                : (kMessageCategories[_cat] ?? 'Tüm Mesajlar'),
        trailing: Text('${list.length} mesaj', style: TextStyle(color: _pal.gold, fontSize: 12)),
      ),
      const SizedBox(height: 6),
      if (list.isEmpty)
        PaperBox(
          pal: _pal,
          padding: const EdgeInsets.all(22),
          child: Text(
            _cat == _favFilter && _query.trim().isEmpty
                ? 'Henüz favori mesajınız yok. Kartların üzerindeki kalbe dokunarak ekleyebilirsiniz.'
                : 'Aradığınız mesaj bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _pal.ink2, fontSize: 13.5),
          ),
        )
      else
        _grid(list),
      gap,
      SourceNote(
        pal: _pal,
        text: 'Mesajlara dokunup görsel olarak paylaşabilirsiniz. Her görselin altında Ezan Saati imzası bulunur. '
            'Ayet mealleri: Ruvvâd Tercüme Merkezi, QuranEnc.com.',
      ),
    ];
  }

  Widget _dailyCard(List<ReligiousMessage> all) {
    final m = all[_dayIdx];
    return DailyCard(
      pal: _pal,
      title: 'Günün Mesajı',
      subtitle: '${kMessageCategories[m.category]} · ${m.title}',
      favorite: _favs.contains('${m.index}'),
      onFavorite: () => _toggleFav(m),
      onPrev: () => setState(() => _dayIdx = (_dayIdx + all.length - 1) % all.length),
      onNext: () => setState(() => _dayIdx = (_dayIdx + 1) % all.length),
      body: [
        const OrnamentStar(),
        const SizedBox(height: 4),
        if (m.hasVerse) ...[
          Text('“${m.verse}”', style: const TextStyle(fontSize: 15, height: 1.55, fontStyle: FontStyle.italic)),
          const SizedBox(height: 6),
          Text('(${m.verseRef})', style: const TextStyle(fontSize: 12, color: RC.verseInk2)),
          const SizedBox(height: 6),
          const OrnamentStar(),
          Text(m.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0B3F2B))),
        ] else ...[
          Text(m.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0B3F2B))),
          const SizedBox(height: 4),
          const OrnamentStar(),
          const SizedBox(height: 4),
          Text(m.body ?? '', style: const TextStyle(fontSize: 15, height: 1.55)),
        ],
      ],
      actions: [
        ActionItem(Icons.copy_outlined, 'Kopyala', () => copyToClipboard(context, m.shareText)),
        ActionItem(Icons.ios_share, 'Paylaş', () => _open(all, all.indexOf(m))),
        ActionItem(Icons.image_outlined, 'Görseli Aç', () => _open(all, all.indexOf(m))),
      ],
    );
  }

  Widget _chips(List<ReligiousMessage> all) {
    final favCount = _favs.length;
    Widget chip(String key, Widget child) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: PillButton(
            pal: _pal,
            selected: _cat == key,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onTap: () => _setCat(key),
            child: child,
          ),
        );
    Widget label(String t, int n) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Opacity(opacity: 0.7, child: Text('$n', style: const TextStyle(fontSize: 11.5))),
          ],
        );
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('tum', label('Tümü', all.length)),
          for (final e in kMessageCategories.entries)
            chip(e.key, label(e.value, all.where((m) => m.category == e.key).length)),
          chip(
            _favFilter,
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.favorite, size: 14),
              const SizedBox(width: 4),
              label('Favoriler', favCount),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<ReligiousMessage> list) {
    final favs = _favs;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final m = list[i];
        final fav = favs.contains('${m.index}');
        return Semantics(
          button: true,
          label: m.title,
          child: GestureDetector(
            onTap: () => _open(list, i),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF0B2E21),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: RC.gold(0.55)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: MessageCard(message: m)),
                  Positioned(
                    left: 4,
                    top: 4,
                    child: Semantics(
                      button: true,
                      toggled: fav,
                      label: '${m.title} favori',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _toggleFav(m),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x73000000)),
                          child: fav
                              ? const GoldIcon(Icons.favorite, size: 17)
                              : const Icon(Icons.favorite_border, size: 17, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
