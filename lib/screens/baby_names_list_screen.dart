import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'surah_read_screen.dart';

/// Bir isim kategorisinin listesi: Kız / Erkek sekmeleri, arama ve favoriler.
/// Kur'an'da geçen isimlerde sure ve ayetler gösterilir; ayete dokununca Sureler'de açılır.
class BabyNamesListScreen extends StatefulWidget {
  final BabyNameCategory category;

  const BabyNamesListScreen({super.key, required this.category});

  @override
  State<BabyNamesListScreen> createState() => _BabyNamesListScreenState();
}

class _BabyNamesListScreenState extends State<BabyNamesListScreen> {
  final _pal = PagePalette.current();
  ReadingPrefs? _prefs;
  QuranData? _quran;
  String _query = '';
  bool _girls = true;
  bool _onlyFav = false;
  final Set<String> _open = {};

  bool get _isQuran => widget.category.key == 'kuran';

  @override
  void initState() {
    super.initState();
    Future.wait([ReadingPrefs.get(), QuranData.load()]).then((r) {
      if (!mounted) return;
      setState(() {
        _prefs = r[0] as ReadingPrefs;
        _quran = r[1] as QuranData;
      });
    });
  }

  Set<String> get _favs => _prefs?.favorites(kBabyNameFavKey) ?? const {};

  void _toggleFav(BabyName n) {
    final on = _prefs?.toggleFavorite(kBabyNameFavKey, n.id) ?? false;
    setState(() {});
    showNote(context, on ? '${n.name} favorilere eklendi' : 'Favorilerden çıkarıldı');
  }

  String _ref(int s, int a) => '${_quran?.surahs[s - 1].name ?? s} $a';

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final q = trSearchKey(_query.trim(), dropSpaces: true);
    final favs = _favs;
    final list = [
      for (final n in c.names)
        if (n.girl == _girls &&
            (!_onlyFav || favs.contains(n.id)) &&
            (q.isEmpty || trSearchKey(n.name, dropSpaces: true).contains(q)))
          n,
    ];
    final girls = c.names.where((n) => n.girl).length;
    final boys = c.names.length - girls;

    return PageShell(
      title: 'Bebek İsimleri',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Text(c.title,
            textAlign: TextAlign.center,
            style: TextStyle(color: _pal.gold, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SearchBox(pal: _pal, hint: 'İsim ara', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 10),
        _tabs(girls, boys),
        const SizedBox(height: 10),
        SectionHead(
          pal: _pal,
          title: _onlyFav ? 'Favori İsimler' : (_girls ? 'Kız İsimleri' : 'Erkek İsimleri'),
          trailing: _favChip(),
        ),
        const SizedBox(height: 6),
        if (list.isEmpty)
          PaperBox(
            pal: _pal,
            padding: const EdgeInsets.all(22),
            child: Text(
              _onlyFav && q.isEmpty
                  ? 'Bu bölümde favori isminiz yok. Kalp simgesine dokunarak ekleyebilirsiniz.'
                  : 'Aradığınız isim bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _pal.ink2, fontSize: 13.5),
            ),
          )
        else
          PaperBox(
            pal: _pal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: withDividers([for (final n in list) _row(n, favs.contains(n.id))], _pal.line),
            ),
          ),
        const SizedBox(height: 10),
        SourceNote(pal: _pal, text: c.description),
      ],
    );
  }

  Widget _tabs(int girls, int boys) {
    Widget tab(bool girl, String title, int count) => Expanded(
          child: PillButton(
            pal: _pal,
            selected: _girls == girl,
            height: 44,
            radius: 12,
            border: false,
            background: Colors.transparent,
            onTap: () => setState(() => _girls = girl),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.1)),
                  Text('$count isim',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: _girls == girl ? RC.bronzeText : _pal.ink2,
                      )),
                ],
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _pal.paper2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pal.line),
      ),
      child: Row(children: [tab(true, 'Kız İsimleri', girls), const SizedBox(width: 6), tab(false, 'Erkek İsimleri', boys)]),
    );
  }

  Widget _favChip() {
    return Semantics(
      button: true,
      toggled: _onlyFav,
      child: GestureDetector(
        onTap: () => setState(() => _onlyFav = !_onlyFav),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _onlyFav ? const Color(0xFFC0392B) : _pal.chip,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _onlyFav ? const Color(0xFFC0392B) : _pal.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_onlyFav ? Icons.favorite : Icons.favorite_border,
                  size: 14, color: _onlyFav ? Colors.white : _pal.ink),
              const SizedBox(width: 4),
              Text('Favoriler',
                  style: TextStyle(
                      color: _onlyFav ? Colors.white : _pal.ink, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BabyName n, bool fav) {
    final open = _open.contains(n.id);
    final subtitle = _isQuran && n.verses.isNotEmpty
        ? '${_ref(n.verses.first.$1, n.verses.first.$2)}${n.verses.length > 1 ? ' · ${n.verses.length} ayette geçer' : ''}'
        : n.meaning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            onTap: () => setState(() => open ? _open.remove(n.id) : _open.add(n.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RC.darkPanel,
                      border: Border.all(color: RC.gold(0.6)),
                    ),
                    child: Text(n.name.characters.first,
                        style: const TextStyle(color: RC.goldText, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.name, style: TextStyle(color: _pal.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(
                          subtitle,
                          maxLines: open ? 3 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _isQuran ? _pal.gold : _pal.ink2, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  HeartButton(pal: _pal, on: fav, label: n.name, onTap: () => _toggleFav(n)),
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.chevron_right, color: _pal.gold),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open) _details(n),
      ],
    );
  }

  Widget _details(BabyName n) {
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 3),
          child: Text(t,
              style: TextStyle(color: _pal.gold, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        );
    final text = TextStyle(color: _pal.ink, fontSize: 13.5, height: 1.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashedLine(color: _pal.line),
          label('ANLAMI'),
          Text(n.meaning, style: text),
          label('BİLGİ'),
          Text(n.info, style: text),
          if (_isQuran && n.verses.isNotEmpty) ...[
            label("KUR'AN'DA GEÇTİĞİ AYETLER"),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (s, a) in n.verses)
                  Semantics(
                    button: true,
                    label: '${_ref(s, a)} ayetini aç',
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SurahReadScreen(surah: s, startAyah: a)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _pal.chip,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _pal.line),
                        ),
                        child: Text(_ref(s, a),
                            style: TextStyle(color: _pal.ink, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text('Kaynak: ${n.source}', style: TextStyle(color: _pal.ink2, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }
}
