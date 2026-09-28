import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../services/quran_audio.dart';
import 'reading_ui.dart';
import 'gold_icon.dart';

/// Sûre okuma sayfasının altındaki sesli okuma çubuğu. Sûre ayet ayet çalınır (her ayet
/// ayrı dosya), böylece okunan ayet kesin bilinir ve sayfaya bildirilir. Ses internetten akar;
/// sayfa kaydırılıp okunmaya devam edilirken çalmayı sürdürür.
class SurahAudioBar extends StatefulWidget {
  final int surah;
  final String surahName;

  /// Çalmanın başlayacağı ayet (1 ise besmele de okunur).
  final int startAyah;

  /// Aynı sûrede başka ayetten başlatmak için artırılır (sayfadaki "bu ayetten dinle").
  final int startToken;
  final VoidCallback? onPrevSurah;
  final VoidCallback? onNextSurah;
  final VoidCallback onClose;

  /// Okunan ayet değişince çağrılır; 0 = besmele.
  final ValueChanged<int>? onAyahChanged;

  /// Sûrenin son ayeti bitince çağrılır (sonraki sûreye geçmek için). Boşsa çalma durur.
  final VoidCallback? onSurahFinished;

  /// Testlerde oynatıcı yerine sahte bir örnek verilebilir.
  final AudioPlayer Function()? playerFactory;

  const SurahAudioBar({
    super.key,
    required this.surah,
    required this.surahName,
    required this.onClose,
    this.startAyah = 1,
    this.startToken = 0,
    this.onPrevSurah,
    this.onNextSurah,
    this.onAyahChanged,
    this.onSurahFinished,
    this.playerFactory,
  });

  static const height = 132.0;

  @override
  State<SurahAudioBar> createState() => _SurahAudioBarState();
}

class _SurahAudioBarState extends State<SurahAudioBar> {
  AudioPlayer? _player;
  final _subs = <StreamSubscription<dynamic>>[];
  Duration _pos = Duration.zero;
  Duration? _dur; // çalan ayetin süresi
  bool _playing = false;
  bool _busy = false; // yükleniyor / tamponluyor
  String? _error;
  int? _loaded; // çalma listesi yüklü sûre
  int _index = 0; // çalma listesindeki sıra
  bool _finished = false; // sûre sonu bir kez işlensin
  double? _drag; // ilerleme çubuğu sürüklenirken

  SurahPlaylist get _list => SurahPlaylist(widget.surah);

  /// Okunan ayet (0 = besmele).
  int get _currentAyah => _list.ayahAt(_index);

  @override
  void initState() {
    super.initState();
    _index = _list.indexOf(widget.startAyah);
    _play(ayah: widget.startAyah);
  }

  @override
  void didUpdateWidget(covariant SurahAudioBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Başka sûreye geçilince ses de o sûrenin başından (ya da istenen ayetinden) başlar.
    if (oldWidget.surah != widget.surah) {
      _loaded = null;
      setState(() {
        _index = _list.indexOf(widget.startAyah);
        _pos = Duration.zero;
        _dur = null;
      });
      _play(ayah: widget.startAyah);
    } else if (oldWidget.startToken != widget.startToken) {
      _play(ayah: widget.startAyah);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  AudioPlayer _ensure() {
    final p = _player;
    if (p != null) return p;
    final n = (widget.playerFactory ?? AudioPlayer.new)();
    _subs
      ..add(n.positionStream.listen((d) {
        if (mounted) setState(() => _pos = d);
      }))
      ..add(n.durationStream.listen((d) {
        if (mounted) setState(() => _dur = d);
      }))
      ..add(n.currentIndexStream.listen((i) {
        // Yeni liste yüklenirken eski sûrenin sırası gelmesin.
        if (i == null || _loaded != widget.surah) return;
        _setIndex(i);
      }))
      ..add(n.playerStateStream.listen((s) {
        if (!mounted) return;
        final st = s.processingState;
        setState(() {
          _playing = s.playing && st != ProcessingState.completed;
          _busy = s.playing && (st == ProcessingState.loading || st == ProcessingState.buffering);
        });
        if (st == ProcessingState.completed && _loaded == widget.surah) _surahEnded();
      }, onError: (Object e, StackTrace _) => _fail(e)))
      ..add(n.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace _) => _fail(e)));
    return _player = n;
  }

  void _setIndex(int i) {
    if (!mounted) return;
    if (i == _index) return;
    setState(() => _index = i);
    widget.onAyahChanged?.call(_list.ayahAt(i));
  }

  /// Son ayet bitti: sonraki sûreye geç (Nâs'ta dur).
  void _surahEnded() {
    if (_finished) return;
    _finished = true;
    final next = widget.onSurahFinished;
    if (next != null && widget.surah < 114) {
      next();
    } else {
      _player?.pause();
      _player?.seek(Duration.zero, index: 0);
    }
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _playing = false;
      _loaded = null;
      _error = e is MissingPluginException
          ? 'Bu cihazda ses çalınamıyor.'
          : 'Ses yüklenemedi. İnternet bağlantınızı kontrol edip tekrar deneyin.';
    });
  }

  /// Çalmayı başlatır; [ayah] verilirse o ayetten (1 ise besmeleden) başlar.
  Future<void> _play({int? ayah}) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final p = _ensure();
      final list = _list;
      if (_loaded != widget.surah) {
        // Hata sonrası "Tekrar dene" kalınan ayetten sürer.
        final index = ayah != null ? list.indexOf(ayah) : _index;
        _finished = false;
        await p.setAudioSources(
          [for (final u in list.urls) AudioSource.uri(u)],
          initialIndex: index,
        );
        _loaded = widget.surah;
        final i = p.currentIndex ?? index;
        if (mounted) setState(() => _index = i);
        widget.onAyahChanged?.call(list.ayahAt(i));
      } else if (ayah != null) {
        _finished = false;
        await p.seek(Duration.zero, index: list.indexOf(ayah));
      }
      unawaited(p.play());
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted && _error == null) setState(() => _busy = _player?.processingState == ProcessingState.loading);
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player?.pause();
    } else {
      await _play();
    }
  }

  Future<void> _goTo(int index) async {
    final p = _player;
    if (p == null || _loaded == null) return;
    _finished = false;
    await p.seek(Duration.zero, index: index);
    if (!_playing) unawaited(p.play());
  }

  String _mmss(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = s ~/ 60, sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    // Sayfanın Scaffold'unun dışında (Stack üstünde) durduğu için kendi Material katmanı var.
    return Material(
      type: MaterialType.transparency,
      child: _bar(),
    );
  }

  Widget _bar() {
    final list = _list;
    final ready = _loaded != null;
    final total = _dur ?? Duration.zero;
    final pos = total > Duration.zero && _pos > total ? total : _pos;
    final within = total > Duration.zero ? pos.inMilliseconds / total.inMilliseconds : 0.0;
    final progress = ((_index + within) / list.length).clamp(0.0, 1.0);
    final ayah = _currentAyah;
    final label = ayah == 0 ? 'Besmele' : 'Ayet $ayah/${list.ayahCount}';
    return Container(
      height: SurahAudioBar.height,
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        gradient: RC.darkPanel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: RC.gold(0.8), width: 1.5)),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 14, offset: Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                const GoldIcon(Icons.graphic_eq, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${widget.surahName} Sûresi · ${kQuranReciter.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: RC.goldText, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Sesli okumayı kapat',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close, size: 18, color: RC.creamSoft),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Expanded(
                child: Row(
                  children: [
                    const GoldIcon(Icons.wifi_off, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: const TextStyle(color: RC.cream, fontSize: 12.5, height: 1.35)),
                    ),
                    TextButton(
                      onPressed: _play,
                      child:
                          const Text('Tekrar dene', style: TextStyle(color: RC.goldText, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              )
            else ...[
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: const Color(0xFFE6C35A),
                  inactiveTrackColor: const Color(0x33FFFFFF),
                  thumbColor: const Color(0xFFE6C35A),
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: SizedBox(
                  height: 22,
                  // Sûre boyunca ilerleme; bırakılan yerdeki ayete geçer.
                  child: Slider(
                    value: _drag ?? progress,
                    semanticFormatterCallback: (_) => label,
                    onChanged: ready ? (v) => setState(() => _drag = v) : null,
                    onChangeEnd: ready
                        ? (v) {
                            setState(() => _drag = null);
                            _goTo((v * list.length).floor().clamp(0, list.length - 1));
                          }
                        : null,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    _drag != null ? _dragLabel(list) : label,
                    style: const TextStyle(color: RC.creamSoft, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    ready && total > Duration.zero ? '${_mmss(pos)} / ${_mmss(total)}' : '--:--',
                    style: const TextStyle(color: RC.creamSoft, fontSize: 10.5),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _ctl(Icons.skip_previous, 'Önceki sûre', widget.onPrevSurah),
                  _ctl(Icons.fast_rewind, 'Önceki ayet', ready && _index > 0 ? () => _goTo(_index - 1) : null),
                  _playButton(),
                  _ctl(Icons.fast_forward, 'Sonraki ayet',
                      ready && _index < list.length - 1 ? () => _goTo(_index + 1) : null),
                  _ctl(Icons.skip_next, 'Sonraki sûre', widget.onNextSurah),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _dragLabel(SurahPlaylist list) {
    final a = list.ayahAt((_drag! * list.length).floor().clamp(0, list.length - 1));
    return a == 0 ? 'Besmele' : 'Ayet $a/${list.ayahCount}';
  }

  Widget _playButton() {
    return Expanded(
      child: Semantics(
        button: true,
        label: _playing ? 'Duraklat' : 'Oynat',
        child: GestureDetector(
          onTap: _toggle,
          child: Container(
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE6C35A), Color(0xFFC29A2C)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF8A6414)),
            ),
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D1406)))
                  : Icon(_playing ? Icons.pause : Icons.play_arrow, size: 22, color: const Color(0xFF1D1406)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ctl(IconData icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.4 : 1,
            child: Container(
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                gradient: RC.darkPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: RC.gold(0.7)),
              ),
              child: GoldIcon(icon, size: 19),
            ),
          ),
        ),
      ),
    );
  }
}
