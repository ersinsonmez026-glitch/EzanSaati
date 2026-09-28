import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Bir kıssanın okunduğu sayfa. Ayetler Kur'an verisinden değiştirilmeden alınır;
/// sonunda sure ve ayet aralıkları kaynak olarak gösterilir.
class StoryReadScreen extends StatefulWidget {
  final List<QuranStory> stories;
  final int index;

  const StoryReadScreen({super.key, required this.stories, required this.index});

  @override
  State<StoryReadScreen> createState() => _StoryReadScreenState();
}

class _StoryReadScreenState extends State<StoryReadScreen> {
  static const _fsKey = 'kissa_fs';

  final _pal = PagePalette.current();
  final _scroll = ScrollController();
  late int _index = widget.index;
  QuranData? _quran;
  ReadingPrefs? _prefs;
  bool _showArabic = true;
  bool _showMeal = true;
  double _fs = 1;

  @override
  void initState() {
    super.initState();
    Future.wait([QuranData.load(), ReadingPrefs.get()]).then((r) {
      if (!mounted) return;
      setState(() {
        _quran = r[0] as QuranData;
        _prefs = r[1] as ReadingPrefs;
        _fs = _prefs!.fontScale(_fsKey);
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _index = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toggle({bool arabic = false}) {
    // En az biri açık kalmalı.
    if (arabic) {
      if (_showArabic && !_showMeal) return;
      setState(() => _showArabic = !_showArabic);
    } else {
      if (_showMeal && !_showArabic) return;
      setState(() => _showMeal = !_showMeal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _quran;
    final st = widget.stories[_index];
    return PageShell(
      title: st.title,
      background: _pal.background,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: q == null
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : _content(st, q),
    );
  }

  List<Widget> _content(QuranStory st, QuranData q) {
    final last = widget.stories.length - 1;
    return [
      ReadingHero(
        lines: [
          const Opacity(opacity: 0.85, child: Text("Kur'an-ı Kerim'den", style: TextStyle(fontSize: 12))),
          Text(st.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          Opacity(
            opacity: 0.85,
            child: Text(
              '${st.ayahCount} ayet${st.passages.length > 1 ? ' · ${st.passages.length} bölüm' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
        tools: [
          HeroTool(label: 'Arapça', active: _showArabic, onTap: () => _toggle(arabic: true)),
          HeroTool(label: 'Meal', active: _showMeal, onTap: _toggle),
          HeroTool(
            label: 'A−',
            semanticLabel: 'Yazıyı küçült',
            onTap: () => setState(() => _fs = _prefs?.changeFontScale(_fsKey, -0.1) ?? _fs),
          ),
          HeroTool(
            label: 'A+',
            semanticLabel: 'Yazıyı büyüt',
            onTap: () => setState(() => _fs = _prefs?.changeFontScale(_fsKey, 0.1) ?? _fs),
          ),
        ],
      ),
      for (final p in st.passages) ...[
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: _passageLabel(q, p)),
        const SizedBox(height: 8),
        for (var a = p.from; a <= p.to; a++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _verse(q, p.surah, a),
          ),
      ],
      const SizedBox(height: 2),
      _sourceBox(st, q),
      const SizedBox(height: 10),
      PrevNextRow(
        prevLabel: '‹ Önceki hikâye',
        nextLabel: 'Sonraki hikâye ›',
        onPrev: _index > 0 ? () => _go(_index - 1) : null,
        onNext: _index < last ? () => _go(_index + 1) : null,
      ),
    ];
  }

  Widget _passageLabel(QuranData q, StoryPassage p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: RC.darkPanel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RC.gold(0.5)),
      ),
      child: Text(
        '${q.surahs[p.surah - 1].name} Sûresi · ${p.from}-${p.to}',
        style: const TextStyle(color: RC.goldText, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _verse(QuranData q, int surah, int no) {
    final a = q.verses[surah - 1][no - 1];
    final name = q.surahs[surah - 1].name;
    return PaperBox(
      pal: _pal,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OctaBadge(number: no, size: 32, color: _pal.gold, textColor: _pal.ink),
              const Spacer(),
              Semantics(
                button: true,
                label: '$no. ayeti kopyala',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => copyToClipboard(context, '${a.arabic}\n\n${a.meal}\n($name, $no)'),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.copy_outlined, size: 18, color: _pal.ink2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          if (_showArabic)
            Text(
              a.arabic,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: kQuranFont, fontSize: 24 * _fs, height: 2.2, color: _pal.ink),
            ),
          if (_showMeal) ...[
            const SizedBox(height: 4),
            Text(a.meal, style: TextStyle(fontSize: 14.5 * _fs, height: 1.6, color: _pal.ink)),
            if (a.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              DashedLine(color: _pal.line),
              const SizedBox(height: 6),
              Text(a.note, style: TextStyle(fontSize: 11.5, height: 1.45, color: _pal.ink2)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _sourceBox(QuranStory st, QuranData q) {
    return PaperBox(
      pal: _pal,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('KAYNAK',
              style: TextStyle(color: _pal.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          for (final line in st.sourceLines(q))
            Text("Kur'an-ı Kerim, $line",
                style: TextStyle(color: _pal.ink, fontSize: 14, fontWeight: FontWeight.w600, height: 1.5)),
          const SizedBox(height: 8),
          DashedLine(color: _pal.line),
          const SizedBox(height: 8),
          Text(
            'Arapça metin: Tanzil Projesi (CC BY 3.0) · Türkçe meal: Ruvvâd Tercüme Merkezi, QuranEnc.com (sürüm 1.0.4)',
            style: TextStyle(color: _pal.ink2, fontSize: 11.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}
