import 'dart:async';

import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Bir surenin okunduğu sayfa: Arapça metin, meal ve dipnotlar.
/// Kaldığın ayet kaydedilir, yazı boyutu ayarlanabilir.
class SurahReadScreen extends StatefulWidget {
  final int surah;
  final int startAyah;

  const SurahReadScreen({super.key, required this.surah, this.startAyah = 1});

  @override
  State<SurahReadScreen> createState() => _SurahReadScreenState();
}

class _SurahReadScreenState extends State<SurahReadScreen> {
  static const _fsKey = 'sure_fs';
  static const _besmele = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  final _pal = PagePalette.current();
  final _scroll = ScrollController();
  QuranData? _data;
  ReadingPrefs? _prefs;
  late int _surah = widget.surah;
  List<GlobalKey> _keys = const [];
  bool _showArabic = true;
  bool _showMeal = true;
  double _fs = 1;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    Future.wait([QuranData.load(), ReadingPrefs.get()]).then((r) {
      if (!mounted) return;
      setState(() {
        _data = r[0] as QuranData;
        _prefs = r[1] as ReadingPrefs;
        _fs = _prefs!.fontScale(_fsKey);
      });
      _openSurah(_surah, widget.startAyah);
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _openSurah(int surah, int ayah) {
    final data = _data!;
    setState(() {
      _surah = surah;
      _keys = List.generate(data.verses[surah - 1].length, (_) => GlobalKey());
    });
    _prefs?.setLastRead(surah, ayah);
    if (ayah > 1) {
      _jumpToAyah(ayah);
    } else if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  /// Sabit başlığın altında kalan görünür alanın üst kenarı.
  double get _visibleTop => MediaQuery.paddingOf(context).top + PageShell.barHeight + 8;

  /// Uzun surelerde ayetler ekrana geldikçe çizilir; hedef ayet çizilene kadar tahminle yaklaşılır.
  Future<void> _jumpToAyah(int ayah) async {
    final visibleTop = _visibleTop;
    for (var tries = 0; tries < 15; tries++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scroll.hasClients) return;
      if (_jumpStep(ayah, visibleTop)) return;
    }
  }

  /// Hedef ayet çizildiyse ona gider ve true döner; değilse tahmini yere atlar.
  bool _jumpStep(int ayah, double visibleTop) {
    final pos = _scroll.position;
    RenderBox? boxOf(int i) => _keys[i].currentContext?.findRenderObject() as RenderBox?;

    final target = boxOf(ayah - 1);
    if (target != null) {
      final dy = target.localToGlobal(Offset.zero).dy - visibleTop;
      pos.jumpTo((pos.pixels + dy).clamp(pos.minScrollExtent, pos.maxScrollExtent));
      return true;
    }
    // Çizilmiş ayetlerden ortalama yüksekliği bul, hedefe doğru atla.
    int? first, last;
    double? firstTop, lastBottom;
    for (var i = 0; i < _keys.length; i++) {
      final b = boxOf(i);
      if (b == null) continue;
      final top = b.localToGlobal(Offset.zero).dy;
      if (first == null) {
        first = i;
        firstTop = top;
      }
      last = i;
      lastBottom = top + b.size.height;
    }
    double next;
    if (first == null) {
      next = pos.maxScrollExtent * (ayah - 1) / _keys.length;
    } else {
      final avg = (lastBottom! - firstTop!) / (last! - first + 1);
      next = pos.pixels + firstTop - visibleTop + (ayah - 1 - first) * avg;
    }
    pos.jumpTo(next.clamp(pos.minScrollExtent, pos.maxScrollExtent));
    return false;
  }

  /// Okurken en üstte görünen ayeti "kaldığın yer" olarak kaydeder.
  void _onScroll() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      var current = 1;
      for (var i = 0; i < _keys.length; i++) {
        final c = _keys[i].currentContext;
        if (c == null) continue;
        final top = (c.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy;
        if (top > _visibleTop + 4) break;
        current = i + 1;
      }
      _prefs?.setLastRead(_surah, current);
    });
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
    final data = _data;
    final surah = data?.surahs[_surah - 1];
    return PageShell(
      title: surah?.name ?? 'Sureler',
      background: _pal.background,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: data == null || surah == null || _keys.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : _content(data, surah),
    );
  }

  List<Widget> _content(QuranData data, Surah s) {
    final verses = data.verses[s.no - 1];
    return [
      ReadingHero(
        lines: [
          Text(s.arabic, style: const TextStyle(fontFamily: kArabicFont, fontSize: 30, height: 1.3, color: RC.goldText)),
          Text('${s.name} Sûresi', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          Opacity(
            opacity: 0.85,
            child: Text('${s.no}. sure · ${s.kind} · ${s.ayahCount} ayet', style: const TextStyle(fontSize: 12)),
          ),
        ],
        tools: [
          HeroTool(label: 'Arapça', active: _showArabic, onTap: () => _toggle(arabic: true)),
          HeroTool(label: 'Meal', active: _showMeal, onTap: _toggle),
          HeroTool(
            label: 'A−',
            semanticLabel: 'Yazıyı küçült',
            onTap: () => setState(() => _fs = _prefs!.changeFontScale(_fsKey, -0.1)),
          ),
          HeroTool(
            label: 'A+',
            semanticLabel: 'Yazıyı büyüt',
            onTap: () => setState(() => _fs = _prefs!.changeFontScale(_fsKey, 0.1)),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_showArabic && s.no != 1 && s.no != 9) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            _besmele,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: kQuranFont, fontSize: 26, color: _pal.gold),
          ),
        ),
        const SizedBox(height: 8),
      ],
      for (var i = 0; i < verses.length; i++)
        Padding(
          key: _keys[i],
          padding: const EdgeInsets.only(bottom: 8),
          child: _verse(s, i + 1, verses[i]),
        ),
      const SizedBox(height: 2),
      PrevNextRow(
        prevLabel: '‹ Önceki sure',
        nextLabel: 'Sonraki sure ›',
        onPrev: s.no > 1 ? () => _openSurah(s.no - 1, 1) : null,
        onNext: s.no < 114 ? () => _openSurah(s.no + 1, 1) : null,
      ),
      const SizedBox(height: 10),
      SourceNote(
        pal: _pal,
        text: 'Arapça metin: Tanzil Projesi (CC BY 3.0) · Türkçe meal: Ruvvâd Tercüme Merkezi, '
            'QuranEnc.com (sürüm 1.0.4)',
      ),
    ];
  }

  Widget _verse(Surah s, int no, Ayah a) {
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
                  onTap: () => copyToClipboard(context, '${a.arabic}\n\n${a.meal}\n(${s.name}, $no)'),
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
}
