import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'story_read_screen.dart';

/// Dini Hikâyeler: yalnızca Kur'an-ı Kerim'deki kıssalar; arama ve kategori.
/// Metinler Kur'an verisinden (Tanzil + Ruvvâd meali) değiştirilmeden gösterilir.
class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  final _pal = PagePalette.current();
  StoryData? _stories;
  QuranData? _quran;
  String _query = '';
  String _cat = 'tum';

  @override
  void initState() {
    super.initState();
    Future.wait([StoryData.load(), QuranData.load()]).then((r) {
      if (!mounted) return;
      setState(() {
        _stories = r[0] as StoryData;
        _quran = r[1] as QuranData;
      });
    });
  }

  void _open(List<QuranStory> list, int i) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryReadScreen(stories: list, index: i)));
  }

  @override
  Widget build(BuildContext context) {
    final s = _stories, q = _quran;
    return PageShell(
      title: 'Dini Hikâyeler',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: s == null || q == null
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : _content(s, q),
    );
  }

  List<Widget> _content(StoryData data, QuranData q) {
    const gap = SizedBox(height: 10);
    final key = trSearchKey(_query.trim());
    final list = [
      for (final st in data.stories)
        if ((_cat == 'tum' || st.category == _cat) &&
            (key.isEmpty || trSearchKey('${st.title} ${st.sourceLines(q).join(' ')}').contains(key)))
          st,
    ];

    Widget chip(String k, String label) => Expanded(
          child: PillButton(
            pal: _pal,
            selected: _cat == k,
            onTap: () => setState(() => _cat = k),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
          ),
        );

    return [
      SearchBox(pal: _pal, hint: 'Hikâye ara (ör. Yûsuf, Nûh, Kehf)', onChanged: (v) => setState(() => _query = v)),
      gap,
      Row(
        children: [
          chip('tum', 'Tümü'),
          for (final e in data.categories.entries) ...[const SizedBox(width: 6), chip(e.key, e.value)],
        ],
      ),
      gap,
      SectionHead(
        pal: _pal,
        title: key.isNotEmpty ? 'Arama sonuçları' : (data.categories[_cat] ?? "Kur'an'daki Kıssalar"),
        trailing: Text('${list.length} kıssa', style: TextStyle(color: _pal.gold, fontSize: 12)),
      ),
      const SizedBox(height: 6),
      PaperBox(
        pal: _pal,
        child: list.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(22),
                child: Text('Aradığınız hikâye bulunamadı.',
                    textAlign: TextAlign.center, style: TextStyle(color: _pal.ink2, fontSize: 13.5)),
              )
            : Column(
                children: withDividers([
                  for (var i = 0; i < list.length; i++) _row(list, i, q),
                ], _pal.line),
              ),
      ),
      gap,
      SourceNote(
        pal: _pal,
        text: "Hikâyeler yalnızca Kur'an-ı Kerim'deki kıssalardır; ayetler değiştirilmeden gösterilir. "
            'Arapça metin: Tanzil Projesi (CC BY 3.0) · Türkçe meal: Ruvvâd Tercüme Merkezi, QuranEnc.com (sürüm 1.0.4)',
      ),
    ];
  }

  Widget _row(List<QuranStory> list, int i, QuranData q) {
    final st = list[i];
    return InkWell(
      onTap: () => _open(list, i),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        child: Row(
          children: [
            OctaBadge(number: st.index + 1, color: _pal.gold, textColor: _pal.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(st.title, style: TextStyle(color: _pal.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(
                    '${st.sourceLines(q).join(' · ')} · ${st.ayahCount} ayet',
                    style: TextStyle(color: _pal.ink2, fontSize: 11.5, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: _pal.gold),
          ],
        ),
      ),
    );
  }
}
