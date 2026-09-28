import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../services/quran_audio.dart';
import 'reading_ui.dart';

/// Sûre okuma sayfasının altındaki sesli okuma çubuğu. Ses internetten akar;
/// sayfa kaydırılıp okunmaya devam edilirken çalmayı sürdürür.
class SurahAudioBar extends StatefulWidget {
  final int surah;
  final String surahName;
  final VoidCallback? onPrevSurah;
  final VoidCallback? onNextSurah;
  final VoidCallback onClose;

  /// Testlerde oynatıcı yerine sahte bir örnek verilebilir.
  final AudioPlayer Function()? playerFactory;

  const SurahAudioBar({
    super.key,
    required this.surah,
    required this.surahName,
    required this.onClose,
    this.onPrevSurah,
    this.onNextSurah,
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
  Duration? _dur;
  bool _playing = false;
  bool _busy = false; // yükleniyor / tamponluyor
  String? _error;
  int? _loaded; // yüklü sûre

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(covariant SurahAudioBar old) {
    super.didUpdateWidget(old);
    // Önceki/sonraki sûreye geçilince ses de o sûreye geçer.
    if (old.surah != widget.surah) {
      _loaded = null;
      setState(() {
        _pos = Duration.zero;
        _dur = null;
      });
      _play();
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
      ..add(n.playerStateStream.listen((s) {
        if (!mounted) return;
        final st = s.processingState;
        setState(() {
          _playing = s.playing && st != ProcessingState.completed;
          _busy = s.playing && (st == ProcessingState.loading || st == ProcessingState.buffering);
        });
        if (st == ProcessingState.completed) {
          n.pause();
          n.seek(Duration.zero);
        }
      }, onError: (Object e, StackTrace _) => _fail(e)))
      ..add(n.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace _) => _fail(e)));
    return _player = n;
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

  Future<void> _play() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final p = _ensure();
      if (_loaded != widget.surah) {
        await p.setUrl(kQuranReciter.surahUrl(widget.surah).toString());
        _loaded = widget.surah;
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

  Future<void> _skip(int seconds) async {
    final p = _player;
    if (p == null || _loaded == null) return;
    final max = _dur ?? Duration.zero;
    var to = _pos + Duration(seconds: seconds);
    if (to < Duration.zero) to = Duration.zero;
    if (max > Duration.zero && to > max) to = max;
    await p.seek(to);
  }

  String _mmss(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = (s % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final total = _dur ?? Duration.zero;
    final pos = total > Duration.zero && _pos > total ? total : _pos;
    final ready = _loaded != null && total > Duration.zero;
    // Sayfanın Scaffold'unun dışında (Stack üstünde) durduğu için kendi Material katmanı var.
    return Material(
      type: MaterialType.transparency,
      child: _bar(pos, total, ready),
    );
  }

  Widget _bar(Duration pos, Duration total, bool ready) {
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
                const Icon(Icons.graphic_eq, size: 18, color: RC.goldIcon),
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
                    const Icon(Icons.wifi_off, size: 18, color: RC.goldIcon),
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
                  child: Slider(
                    value: ready ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0) : 0,
                    onChanged:
                        ready ? (v) => _player?.seek(Duration(milliseconds: (v * total.inMilliseconds).round())) : null,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(_mmss(pos), style: const TextStyle(color: RC.creamSoft, fontSize: 10.5)),
                  const Spacer(),
                  Text(ready ? _mmss(total) : '--:--', style: const TextStyle(color: RC.creamSoft, fontSize: 10.5)),
                  const SizedBox(width: 6),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  _ctl(Icons.skip_previous, 'Önceki sûre', widget.onPrevSurah),
                  _ctl(Icons.replay_10, '10 saniye geri', ready ? () => _skip(-10) : null),
                  _playButton(),
                  _ctl(Icons.forward_10, '10 saniye ileri', ready ? () => _skip(10) : null),
                  _ctl(Icons.skip_next, 'Sonraki sûre', widget.onNextSurah),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
              child: Icon(icon, size: 19, color: const Color(0xFFE9C96A)),
            ),
          ),
        ),
      ),
    );
  }
}
