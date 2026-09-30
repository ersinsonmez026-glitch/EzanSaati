import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/content_store.dart';
import '../services/quran_audio.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import '../widgets/surah_audio_bar.dart';

/// Bir surenin okunduğu sayfa: Arapça metin, meal ve dipnotlar.
/// Kaldığın ayet kaydedilir, yazı boyutu ayarlanabilir.
class SurahReadScreen extends StatefulWidget {
  final int surah;
  final int startAyah;
  final bool listen; // açılışta sesli okumayı başlat

  const SurahReadScreen({super.key, required this.surah, this.startAyah = 1, this.listen = false});

  @override
  State<SurahReadScreen> createState() => _SurahReadScreenState();
}

class _SurahReadScreenState extends State<SurahReadScreen> {
  static const _fsKey = 'sure_fs';
  static const _besmele = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  final _scroll = ScrollController();
  QuranData? _data;
  ReadingPrefs? _prefs;
  late int _surah = widget.surah;
  List<GlobalKey> _keys = const [];
  bool _showArabic = true;
  bool _showMeal = true;
  double _fs = 1;
  Timer? _saveTimer;
  late bool _audio = widget.listen; // sesli okuma çubuğu açık mı
  late int _audioStart = widget.startAyah; // sesli okumanın başlayacağı ayet
  int? _playingAyah; // okunan ayet (0 = besmele)
  int _audioToken = 0; // "bu ayetten dinle" her dokunuşta artar
  DateTime _userScrollAt = DateTime(0); // son elle kaydırma

  /// Elle kaydırıldıktan sonra okunan ayeti takip etmeye ara verilen süre.
  static const followPause = Duration(seconds: 4);

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
      _audioStart = ayah;
      _playingAyah = null;
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

  /// Okurken en üstte görünen ayet.
  int _topAyah() {
    var current = 1;
    for (var i = 0; i < _keys.length; i++) {
      final c = _keys[i].currentContext;
      if (c == null) continue;
      final top = (c.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy;
      if (top > _visibleTop + 4) break;
      current = i + 1;
    }
    return current;
  }

  /// Okurken en üstte görünen ayeti "kaldığın yer" olarak kaydeder.
  void _onScroll() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _prefs?.setLastRead(_surah, _topAyah());
    });
  }

  /// Sesli okumada sıradaki ayete geçildi: vurgula ve ekranda tut.
  void _onAyahPlaying(int ayah) {
    if (!mounted) return;
    setState(() => _playingAyah = ayah);
    if (ayah < 1 || ayah > _keys.length) return;
    if (DateTime.now().difference(_userScrollAt) < followPause) return;
    _follow(ayah);
  }

  void _follow(int ayah) {
    if (!mounted || !_scroll.hasClients || ayah > _keys.length) return;
    final box = _keys[ayah - 1].currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      _jumpToAyah(ayah); // uzun surelerde henüz çizilmemiş ayet
      return;
    }
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final visibleBottom = MediaQuery.sizeOf(context).height - (_audio ? SurahAudioBar.height : 0) - 8;
    if (top >= _visibleTop && bottom <= visibleBottom) return; // zaten görünüyor
    final pos = _scroll.position;
    _scroll.animateTo(
      (pos.pixels + top - _visibleTop).clamp(pos.minScrollExtent, pos.maxScrollExtent),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  bool _onScrollNote(ScrollNotification n) {
    // Yalnızca parmakla kaydırma takibi durdurur; otomatik kaydırma durdurmaz.
    if ((n is ScrollStartNotification && n.dragDetails != null) ||
        (n is ScrollUpdateNotification && n.dragDetails != null) ||
        (n is UserScrollNotification && n.direction != ScrollDirection.idle)) {
      _userScrollAt = DateTime.now();
    }
    return false;
  }

  /// Ayetin yanındaki dinle simgesi: sesli okumayı o ayetten başlatır.
  void _listenFrom(int ayah) {
    setState(() {
      _audio = true;
      _audioStart = ayah;
      _audioToken++;
      _userScrollAt = DateTime(0);
    });
  }

  void _toggleAudio() {
    setState(() {
      if (_audio) {
        _audio = false;
        _playingAyah = null;
      } else {
        _audioStart = _topAyah(); // ekranda hangi ayet varsa oradan
        _audio = true;
      }
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
    final shell = PageShell(
      title: surah?.name ?? 'Sureler',
      heading: 'Sureler',
      background: _pal.background,
      controller: _scroll,
      // Sesli okuma çubuğu açıkken son ayetler çubuğun altında kalmasın.
      padding: EdgeInsets.fromLTRB(12, 12, 12, 24 + (_audio ? SurahAudioBar.height : 0)),
      children: data == null || surah == null || _keys.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : _content(data, surah),
    );
    if (!_audio || surah == null) return shell;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(onNotification: _onScrollNote, child: shell),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SurahAudioBar(
            surah: surah.no,
            surahName: surah.name,
            startAyah: _audioStart,
            startToken: _audioToken,
            onPrevSurah: surah.no > 1 ? () => _openSurah(surah.no - 1, 1) : null,
            onNextSurah: surah.no < 114 ? () => _openSurah(surah.no + 1, 1) : null,
            onAyahChanged: _onAyahPlaying,
            // Son ayetten sonra sonraki sûrenin 1. ayetinden devam; Nâs'ta durur.
            onSurahFinished: surah.no < 114 ? () => _openSurah(surah.no + 1, 1) : null,
            onClose: () => setState(() {
              _audio = false;
              _playingAyah = null;
            }),
          ),
        ),
      ],
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
          HeroTool(
            label: 'Dinle',
            icon: Icons.headphones,
            active: _audio,
            semanticLabel: _audio ? 'Sesli okumayı kapat' : 'Sûreyi dinle',
            onTap: _toggleAudio,
          ),
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
        Builder(builder: (_) {
          final lit = _audio && _playingAyah == 0;
          final text = Text(
            _besmele,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: kQuranFont, fontSize: 26, color: lit && !_pal.night ? _pal.ink : _pal.gold),
          );
          if (!lit) return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: text);
          return Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            foregroundDecoration: _playingDecoration(),
            decoration: BoxDecoration(
              gradient: _litGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _pal.gold.withValues(alpha: 0.5), blurRadius: 18, spreadRadius: 1)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_nowReading(s, 0), text]),
          );
        }),
        const SizedBox(height: 8),
      ],
      for (var i = 0; i < verses.length; i++)
        Padding(
          key: _keys[i],
          padding: const EdgeInsets.only(bottom: 6),
          child: _verse(s, i + 1, verses[i], playing: _audio && _playingAyah == i + 1),
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
            'QuranEnc.com (sürüm 1.0.4)${_audio ? '\n${quranAudioSource()}' : ''}',
      ),
    ];
  }

  /// Okunan ayetin altın çerçevesi (yerleşimi kaydırmaz).
  BoxDecoration _playingDecoration() => BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _pal.gold, width: 2.5),
      );

  Widget _verse(Surah s, int no, Ayah a, {bool playing = false}) {
    final box = _verseBox(s, no, a, playing: playing);
    if (!playing) return box;
    return Semantics(
      label: '$no. ayet okunuyor',
      child: Container(
        foregroundDecoration: _playingDecoration(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: _pal.gold.withValues(alpha: _pal.night ? 0.55 : 0.5), blurRadius: 18, spreadRadius: 1)],
        ),
        child: box,
      ),
    );
  }

  /// Okunan ayetin ışıklı zemini (gece: altın ışıklı yeşil, gündüz: sıcak altın).
  LinearGradient get _litGradient => _pal.night
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A3A14), Color(0xFF1C2A14), Color(0xFF0E2016)],
          stops: [0, 0.45, 1],
        )
      : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFEDB0), Color(0xFFFBE3A2), Color(0xFFF4D98F)],
          stops: [0, 0.5, 1],
        );

  /// Okunan ayetin üstündeki etiket: "Okunuyor · Yâsin Sûresi, 12. ayet".
  Widget _nowReading(Surah s, int no) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
              decoration: BoxDecoration(
                gradient: RC.bronze,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: RC.bronzeBorder),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.graphic_eq, size: 14, color: RC.bronzeText),
                SizedBox(width: 4),
                Text('Okunuyor', style: TextStyle(color: RC.bronzeText, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                no == 0 ? '${s.name} Sûresi · Besmele' : '${s.name} Sûresi · $no. ayet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _pal.night ? _pal.gold : _pal.ink, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  Widget _verseBox(Surah s, int no, Ayah a, {bool playing = false}) {
    Widget tool(IconData icon, String label, VoidCallback onTap) => Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Icon(icon, size: 17, color: _pal.ink2),
            ),
          ),
        );
    // Numara rozeti ve dinle/kopyala ayrı bir satır yerine solda dar bir sütunda: metne daha çok yer kalır.
    final content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              OctaBadge(number: no, size: 28, color: _pal.gold, textColor: _pal.ink),
              const SizedBox(height: 2),
              tool(Icons.headphones_outlined, '$no. ayetten dinle', () => _listenFrom(no)),
              tool(Icons.copy_outlined, '$no. ayeti kopyala',
                  () => copyToClipboard(context, '${a.arabic}\n\n${a.meal}\n(${s.name}, $no)')),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_showArabic)
                  Text(
                    a.arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontFamily: kQuranFont, fontSize: 24 * _fs, height: 2.0, color: _pal.ink),
                  ),
                if (_showMeal) ...[
                  const SizedBox(height: 2),
                  Text(a.meal, style: TextStyle(fontSize: 14.5 * _fs, height: 1.5, color: _pal.ink)),
                  if (a.note.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    DashedLine(color: _pal.line),
                    const SizedBox(height: 5),
                    Text(a.note, style: TextStyle(fontSize: 11.5, height: 1.4, color: _pal.ink2)),
                  ],
                ],
              ],
            ),
          ),
        ],
      );
    if (!playing) {
      return PaperBox(pal: _pal, radius: 14, padding: const EdgeInsets.fromLTRB(8, 8, 10, 8), child: content);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: _litGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _pal.gold),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_nowReading(s, no), content]),
    );
  }
}
