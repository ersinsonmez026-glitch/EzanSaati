import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../data/namaz_videolari.dart';
import '../services/content_store.dart';
import '../services/quran_audio.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'dhikr_screen.dart';
import 'video_screen.dart';

/// Tek bir duanın okunduğu sayfa: Arapça, okunuşu, anlamı ve kaynağı.
class PrayerReadScreen extends StatefulWidget {
  final List<Dua> duas;
  final int index;

  const PrayerReadScreen({super.key, required this.duas, required this.index});

  @override
  State<PrayerReadScreen> createState() => _PrayerReadScreenState();
}

class _PrayerReadScreenState extends State<PrayerReadScreen> {
  static const _fsKey = 'dua_fs';

  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  final _scroll = ScrollController();
  late int _index = widget.index;
  ReadingPrefs? _prefs;
  bool _showReading = true;
  double _fs = 1;

  // Kur'an dualarının sesli okunuşu (Sureler'deki kaynakla aynı, internetten akış).
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerSub;
  int? _loaded; // çalar listesine yüklü duanın sırası
  bool _playing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ReadingPrefs.get().then((p) {
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _fs = p.fontScale(_fsKey);
      });
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _go(int i) {
    _player?.stop();
    setState(() {
      _index = i;
      _playing = false;
      _busy = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _toggleListen(Dua d) async {
    final p = _player ??= AudioPlayer();
    _playerSub ??= p.playerStateStream.listen((s) {
      if (!mounted) return;
      final done = s.processingState == ProcessingState.completed;
      setState(() {
        _playing = s.playing && !done;
        _busy = s.playing &&
            (s.processingState == ProcessingState.loading || s.processingState == ProcessingState.buffering);
      });
      if (done) {
        p.pause();
        p.seek(Duration.zero, index: 0);
      }
    }, onError: (Object _, StackTrace __) => _audioFailed());
    if (_playing) {
      await p.pause();
      return;
    }
    setState(() => _busy = true);
    try {
      if (_loaded != _index) {
        await p.setAudioSources([for (final u in duaAudioUrls(d.audio)) AudioSource.uri(u)]);
        _loaded = _index;
      }
      unawaited(p.play());
    } catch (e) {
      _audioFailed(e);
    }
  }

  void _audioFailed([Object? e]) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _playing = false;
      _loaded = null;
    });
    showNote(
        context,
        e is MissingPluginException
            ? 'Bu cihazda ses çalınamıyor.'
            : 'Ses yüklenemedi. İnternet bağlantınızı kontrol edip tekrar deneyin.');
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.duas[_index];
    final fav = _prefs?.favorites(kDuaFavKey).contains(d.title) ?? false;
    final last = widget.duas.length - 1;

    return PageShell(
      title: 'Dualar',
      background: _pal.background,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        ReadingHero(
          lines: [
            Opacity(
              opacity: 0.85,
              child: Text(kDuaGroupNames[d.group] ?? '', style: const TextStyle(fontSize: 12)),
            ),
            Text(d.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            Opacity(opacity: 0.85, child: Text(d.source, style: const TextStyle(fontSize: 12))),
          ],
          tools: [
            HeroTool(
              label: 'Okunuş',
              active: _showReading,
              onTap: () => setState(() => _showReading = !_showReading),
            ),
            HeroTool(
              label: 'Favori',
              icon: fav ? Icons.favorite : Icons.favorite_border,
              active: fav,
              onTap: () {
                final on = _prefs?.toggleFavorite(kDuaFavKey, d.title) ?? false;
                setState(() {});
                showNote(context, on ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı');
              },
            ),
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
        if (d.hasAudio || d.videos.isNotEmpty) ...[const SizedBox(height: 10), _listenRow(d)],
        const SizedBox(height: 10),
        _article(d),
        const SizedBox(height: 10),
        ActionStrip(
          radius: BorderRadius.circular(14),
          border: Border.all(color: RC.gold(0.6), width: 1.5),
          items: [
            ActionItem(Icons.copy_outlined, 'Kopyala', () => copyToClipboard(context, d.shareText)),
            ActionItem(Icons.ios_share, 'Paylaş', () => shareText(context, d.shareText)),
            ActionItem(
              Icons.touch_app_outlined,
              'Zikret',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DhikrScreen())),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PrevNextRow(
          prevLabel: '‹ Önceki dua',
          nextLabel: 'Sonraki dua ›',
          onPrev: _index > 0 ? () => _go(_index - 1) : null,
          onNext: _index < last ? () => _go(_index + 1) : null,
        ),
      ],
    );
  }

  /// Sesli dinleme (Kur'an duaları) ve Diyanet'in okunuş videosu.
  Widget _listenRow(Dua d) {
    final buttons = <Widget>[
      if (d.hasAudio)
        DarkButton(
          label: _playing ? 'Durdur' : (_busy ? 'Yükleniyor…' : 'Sesli Dinle'),
          onTap: () => _toggleListen(d),
        ),
      if (d.videos.isNotEmpty)
        DarkButton(
          label: 'Videolu Dinle',
          onTap: () {
            _player?.pause();
            final list =
                videosFor('dualar').any((v) => v.id == d.videos.first) ? videosFor('dualar') : gunlukDuaVideolari;
            final i = list.indexWhere((v) => v.id == d.videos.first);
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => VideoScreen(videos: list, index: i < 0 ? 0 : i)));
          },
        ),
    ];
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  Widget _article(Dua d) {
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(t,
              style: TextStyle(color: _pal.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        );
    return PaperBox(
      pal: _pal,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              d.arabic,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: kQuranFont, fontSize: 24 * _fs, height: 2.3, color: _pal.ink),
            ),
          ),
          if (_showReading) ...[
            label('OKUNUŞU'),
            const SizedBox(height: 6),
            Text(d.reading,
                style: TextStyle(fontSize: 14 * _fs, height: 1.6, fontStyle: FontStyle.italic, color: _pal.ink2)),
          ],
          label('ANLAMI'),
          const SizedBox(height: 4),
          Text(d.meaning, style: TextStyle(fontSize: 15 * _fs, height: 1.6, color: _pal.ink)),
          const SizedBox(height: 10),
          DashedLine(color: _pal.line),
          const SizedBox(height: 8),
          Text(
            [
              d.fromMeal
                  ? 'Anlam, ayetin mealidir (Ruvvâd Tercüme Merkezi, QuranEnc.com). Kaynak: ${d.source}'
                  : 'Kaynak: ${d.source}',
              if (d.hasAudio) 'Ses: ${kQuranReciter.name} (murattal); ayetin tamamı okunur.',
            ].join('\n'),
            style: TextStyle(fontSize: 12, color: _pal.ink2),
          ),
        ],
      ),
    );
  }
}
