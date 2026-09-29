import 'package:flutter/material.dart';

import '../data/namaz_videolari.dart';
import '../services/content_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'prayer_read_screen.dart';
import 'video_screen.dart';

/// Dualar: günün duası, Namaz Duaları / Diğer Dualar / Esmâü'l-Hüsnâ sekmeleri, arama ve favoriler.
/// Tasarım: onizleme/04-dualar.html · Veri: assets/data/dualar.json (106 dua)
class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  List<Dua>? _duas;
  List<EsmaName> _esma = const [];
  ReadingPrefs? _prefs;
  String _query = '';
  String _group = 'namaz';
  bool _onlyFav = false;

  @override
  void initState() {
    super.initState();
    EsmaName.all().then((e) {
      if (mounted) setState(() => _esma = e);
    });
    Future.wait([DuaData.all(), ReadingPrefs.get()]).then((r) {
      if (!mounted) return;
      final duas = r[0] as List<Dua>;
      setState(() {
        _duas = duas;
        _prefs = r[1] as ReadingPrefs;
      });
    });
  }

  Set<String> get _favs => _prefs?.favorites(kDuaFavKey) ?? const {};

  void _toggleFav(Dua d) {
    final on = _prefs?.toggleFavorite(kDuaFavKey, d.title) ?? false;
    setState(() {});
    showNote(context, on ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı');
  }

  Future<void> _open(int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PrayerReadScreen(duas: _duas!, index: index)),
    );
    if (mounted) setState(() {}); // favoriler değişmiş olabilir
  }

  @override
  Widget build(BuildContext context) {
    final duas = _duas;
    return PageShell(
      title: 'Dualar',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: duas == null
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : _content(duas),
    );
  }

  List<Widget> _content(List<Dua> duas) {
    const gap = SizedBox(height: 10);
    final searching = _query.trim().isNotEmpty;
    return [
      SearchBox(
        pal: _pal,
        hint: 'Dua ara (ör. yemek, yolculuk, anne)',
        onChanged: (v) => setState(() => _query = v),
      ),
      gap,
      _tabs(duas),
      gap,
      if (_group == 'esma' && !searching) ..._esmaView() else ...[
      SectionHead(
        pal: _pal,
        title: searching ? 'Arama sonuçları' : kDuaGroupNames[_group]!,
        trailing: _favChip(),
      ),
      const SizedBox(height: 6),
      _list(duas),
      gap,
      SourceNote(
        pal: _pal,
        text: "Kur'an'dan alınan duaların Arapçası ayetin kendisidir (Tanzil Projesi), anlamı ayetin "
            "mealidir (Ruvvâd Tercüme Merkezi, QuranEnc.com). Hadis kaynakları kitap adıyla verilmiştir. "
            'Okunuşlar Türkçe telaffuza göredir; yayından önce bir din görevlisine kontrol ettirilmelidir.',
      ),
      ],
    ];
  }

  // ---------------------------------------------------------------- Esmâü'l-Hüsnâ

  List<Widget> _esmaView() {
    return [
      DarkButton(
        label: 'Sesli Dinle (ritimli okunuş)',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VideoScreen(videos: esmaVideolari)),
        ),
      ),
      const SizedBox(height: 10),
      SectionHead(pal: _pal, title: "Esmâü'l-Hüsnâ"),
      const SizedBox(height: 6),
      PaperBox(
        pal: _pal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: withDividers([
            for (var i = 0; i < _esma.length; i++) _esmaRow(i + 1, _esma[i]),
          ], _pal.line),
        ),
      ),
      const SizedBox(height: 10),
      SourceNote(
        pal: _pal,
        text: "İsimler ve sırası Tirmizî'nin rivayetine göredir (Deavât, 82). İsim listesinin hadise râvi "
            'tarafından eklendiği görüşü de vardır (TDV İslâm Ansiklopedisi, "Esmâ-i Hüsnâ"). Anlamlar TDV İslâm '
            'Ansiklopedisi maddelerinden kısaltılmıştır. Sesli okunuş YouTube videosudur; internet gerekir.',
      ),
    ];
  }

  Widget _esmaRow(int n, EsmaName e) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          OctaBadge(number: n, color: _pal.gold, textColor: _pal.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.reading, style: TextStyle(color: _pal.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(e.meaning, style: TextStyle(color: _pal.ink2, fontSize: 12.5, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                e.arabic,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: kQuranFont, fontSize: 20, height: 1.6, color: _pal.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs(List<Dua> duas) {
    final counts = {
      'namaz': '${duas.where((d) => d.group == 'namaz').length} dua ve sure',
      'diger': '${duas.where((d) => d.group == 'diger').length} dua',
      'esma': '99 isim',
    };
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _pal.paper2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pal.line),
      ),
      child: Row(
        children: [
          for (final g in const ['namaz', 'diger', 'esma']) ...[
            if (g != 'namaz') const SizedBox(width: 6),
            Expanded(
              child: PillButton(
                pal: _pal,
                selected: _group == g,
                height: 44,
                radius: 12,
                border: false,
                background: Colors.transparent,
                onTap: () => setState(() => _group = g),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(kDuaGroupNames[g] ?? "Esmâü'l-Hüsnâ",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.1)),
                      Text(
                        counts[g]!,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: _group == g ? RC.bronzeText : _pal.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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

  Widget _list(List<Dua> duas) {
    final q = trSearchKey(_query.trim());
    final favs = _favs;
    final children = <Widget>[];
    var n = 0;
    var lastSection = '';
    for (var i = 0; i < duas.length; i++) {
      final d = duas[i];
      if (q.isNotEmpty) {
        if (!trSearchKey('${d.title} ${d.meaning} ${d.reading}').contains(q)) continue;
      } else {
        if (d.group != _group) continue;
        if (_onlyFav && !favs.contains(d.title)) continue;
      }
      n++;
      if (q.isEmpty && _group == 'namaz' && d.section.isNotEmpty && d.section != lastSection) {
        lastSection = d.section;
        children.add(_sectionHeader(d.section, first: children.isEmpty));
      } else if (children.isNotEmpty) {
        children.add(Container(height: 1, color: _pal.line));
      }
      children.add(_row(i, n, d, favs.contains(d.title), showGroup: q.isNotEmpty));
    }
    return PaperBox(
      pal: _pal,
      child: children.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(22),
              child: Text(
                _onlyFav && q.isEmpty
                    ? 'Bu bölümde favori dua yok. Kalp simgesine dokunarak ekleyebilirsiniz.'
                    : 'Aradığınız dua bulunamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _pal.ink2, fontSize: 13.5),
              ),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _sectionHeader(String text, {required bool first}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: _pal.paper2,
        border: first ? null : Border(top: BorderSide(color: _pal.line)),
      ),
      child: Text(
        trUpper(text),
        style: TextStyle(color: _pal.gold, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      ),
    );
  }

  Widget _row(int index, int n, Dua d, bool fav, {required bool showGroup}) {
    return InkWell(
      onTap: () => _open(index),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        child: Row(
          children: [
            OctaBadge(number: n, color: _pal.gold, textColor: _pal.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.title, style: TextStyle(color: _pal.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(
                    showGroup ? '${kDuaGroupNames[d.group]} · ${d.reading}' : d.reading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _pal.ink2, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            HeartButton(pal: _pal, on: fav, label: d.title, onTap: () => _toggleFav(d)),
          ],
        ),
      ),
    );
  }
}
