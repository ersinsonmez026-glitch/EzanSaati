import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../services/home_widgets.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'surah_read_screen.dart';
import '../widgets/gold_icon.dart';

/// Sureler: arama, Mekkî/Medenî/Favori filtresi, günün ayeti, sık okunanlar ve 114 sure.
/// Tasarım: onizleme/03-sureler.html
class SurahsScreen extends StatefulWidget {
  const SurahsScreen({super.key});

  @override
  State<SurahsScreen> createState() => _SurahsScreenState();
}

enum _Filter { all, meccan, medinan, fav }

class _SurahsScreenState extends State<SurahsScreen> {
  static const _favKey = 'sure_fav';

  // Sık okunanlar
  static const _popular = [1, 36, 67, 18, 55, 78, 56, 112, 113, 114];

  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  QuranData? _data;
  ReadingPrefs? _prefs;
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    Future.wait([QuranData.load(), ReadingPrefs.get()]).then((r) {
      if (!mounted) return;
      setState(() {
        _data = r[0] as QuranData;
        _prefs = r[1] as ReadingPrefs;
      });
    });
  }

  Set<String> get _favs => _prefs?.favorites(_favKey) ?? const {};

  void _toggleFav(String id, {String? message}) {
    final on = _prefs?.toggleFavorite(_favKey, id) ?? false;
    HomeWidgets.syncSoon(); // widget çalarındaki "Favori sûreler" listesi
    setState(() {});
    if (message != null) showNote(context, on ? message : 'Favorilerden çıkarıldı');
  }

  Future<void> _open(int surah, [int ayah = 1, bool listen = false]) async {
    await Navigator.of(context).push(
      AppRoute(builder: (_) => SurahReadScreen(surah: surah, startAyah: ayah, listen: listen)),
    );
    if (mounted) setState(() {}); // kaldığın yer ve favoriler güncellensin
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return PageShell(
      title: 'Sureler',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: data == null
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : _content(data),
    );
  }

  List<Widget> _content(QuranData data) {
    const gap = SizedBox(height: 10);
    final last = _prefs?.lastRead;
    return [
      SearchBox(
        pal: _pal,
        hint: 'Sure ara (ör. Yâsîn, Mülk, 36)',
        onChanged: (v) => setState(() => _query = v),
      ),
      gap,
      _chips(),
      if (last != null && last.$1 >= 1 && last.$1 <= 114) ...[gap, _resume(data, last.$1, last.$2)],
      gap,
      SectionHead(
        pal: _pal,
        title: 'Sık Okunanlar',
        trailing: Text('kaydır ›', style: TextStyle(color: _pal.gold, fontSize: 12)),
      ),
      const SizedBox(height: 6),
      _popularRow(data),
      gap,
      ..._list(data),
      gap,
      SourceNote(
        pal: _pal,
        text: 'Arapça metin: Tanzil Projesi (CC BY 3.0) · Türkçe meal: Ruvvâd Tercüme Merkezi, '
            'QuranEnc.com (sürüm 1.0.4)',
      ),
    ];
  }

  Widget _chips() {
    Widget chip(_Filter f, Widget child) => Expanded(
          child: PillButton(
            pal: _pal,
            selected: _filter == f,
            onTap: () => setState(() => _filter = f),
            child: child,
          ),
        );
    return Row(
      children: [
        chip(_Filter.all, const Text('Tümü')),
        const SizedBox(width: 6),
        chip(_Filter.meccan, const Text('Mekkî')),
        const SizedBox(width: 6),
        chip(_Filter.medinan, const Text('Medenî')),
        const SizedBox(width: 6),
        chip(
          _Filter.fav,
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(children: [Icon(Icons.favorite), SizedBox(width: 4), Text('Favoriler')]),
          ),
        ),
      ],
    );
  }

  Widget _resume(QuranData data, int surah, int ayah) {
    final s = data.surahs[surah - 1];
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => _open(surah, ayah),
        child: PaperBox(
          pal: _pal,
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RC.darkPanel,
                  border: Border.all(color: RC.gold(0.6)),
                ),
                child: const GoldIcon(Icons.bookmark_border, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kaldığın yer: ${s.name}',
                        style: TextStyle(color: _pal.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text('$ayah. ayet · ${s.ayahCount} ayetten',
                        style: TextStyle(color: _pal.ink2, fontSize: 11.5)),
                  ],
                ),
              ),
              Text('Devam et ›', style: TextStyle(color: _pal.gold, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _popularRow(QuranData data) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: _popular.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = data.surahs[_popular[i] - 1];
          return Semantics(
            button: true,
            label: s.name,
            child: GestureDetector(
              onTap: () => _open(s.no),
              child: Container(
                width: 86,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  gradient: RC.darkPanel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: RC.gold(0.6), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.arabic,
                        maxLines: 1,
                        style: const TextStyle(
                            fontFamily: kArabicFont, fontSize: 20, height: 1.3, color: RC.goldText)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(s.name,
                          style: const TextStyle(color: RC.cream, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    Text('${s.ayahCount} ayet', style: const TextStyle(color: RC.creamSoft, fontSize: 10)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _list(QuranData data) {
    final q = trSearchKey(_query.trim(), dropSpaces: true);
    final favs = _favs;
    final rows = <Widget>[];
    for (final s in data.surahs) {
      if (_filter == _Filter.meccan && !s.meccan) continue;
      if (_filter == _Filter.medinan && s.meccan) continue;
      if (_filter == _Filter.fav && !favs.contains('s${s.no}')) continue;
      if (q.isNotEmpty && !trSearchKey(s.name, dropSpaces: true).contains(q) && '${s.no}' != q) continue;
      rows.add(_row(s, favs.contains('s${s.no}')));
    }
    final title = switch (_filter) {
      _Filter.fav => 'Favori Sureler',
      _Filter.meccan => 'Mekkî Sureler',
      _Filter.medinan => 'Medenî Sureler',
      _Filter.all => 'Tüm Sureler',
    };
    return [
      SectionHead(
        pal: _pal,
        title: title,
        trailing: Text('${rows.length} sure', style: TextStyle(color: _pal.gold, fontSize: 12)),
      ),
      const SizedBox(height: 6),
      PaperBox(
        pal: _pal,
        child: rows.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(22),
                child: Text(
                  _filter == _Filter.fav
                      ? 'Henüz favori sure yok. Listede kalp simgesine dokunarak ekleyebilirsiniz.'
                      : 'Aradığınız sure bulunamadı.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _pal.ink2, fontSize: 13.5),
                ),
              )
            : Column(children: withDividers(rows, _pal.line)),
      ),
    ];
  }

  Widget _row(Surah s, bool fav) {
    return InkWell(
      onTap: () => _open(s.no),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
        child: Row(
          children: [
            OctaBadge(number: s.no, size: 32, color: _pal.gold, textColor: _pal.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: TextStyle(color: _pal.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('${s.kind} · ${s.ayahCount} ayet', style: TextStyle(color: _pal.ink2, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(s.arabic,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: kArabicFont, fontSize: 20, color: _pal.gold)),
            const SizedBox(width: 6),
            ListenButton(pal: _pal, label: s.name, onTap: () => _open(s.no, 1, true)),
            HeartButton(pal: _pal, on: fav, label: s.name, onTap: () => _toggleFav('s${s.no}')),
          ],
        ),
      ),
    );
  }
}
