import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/ilahi_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// İlahiler (onizleme/12-ilahiler.html): solda numaralı liste, sağda oynatıcı.
/// Kayıtlar assets/data/ilahiler.json dosyasından gelir; her kaydın kaynağı ve
/// lisansı oynatıcının altında gösterilir.
class IlahilerScreen extends StatefulWidget {
  /// Testler için liste verilebilir; verilmezse veri dosyasından okunur.
  final List<Ilahi>? tracks;

  const IlahilerScreen({super.key, this.tracks});

  @override
  State<IlahilerScreen> createState() => _IlahilerScreenState();
}

class _IlahilerScreenState extends State<IlahilerScreen> {
  final _pal = PagePalette.current();
  List<Ilahi>? _tracks;
  int _cur = 0;

  AudioPlayer? _player; // ilk oynatmada oluşturulur
  final _subs = <StreamSubscription<dynamic>>[];
  Duration _pos = Duration.zero;
  Duration? _dur;
  bool _playing = false;
  bool _muted = false;
  bool _loading = false;
  String? _loadedAsset;

  @override
  void initState() {
    super.initState();
    final given = widget.tracks;
    if (given != null) {
      _tracks = given;
    } else {
      IlahiData.load().then((t) {
        if (mounted) setState(() => _tracks = t);
      }).catchError((_) {
        if (mounted) setState(() => _tracks = const []);
      });
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

  Ilahi? get _track {
    final t = _tracks;
    return t == null || t.isEmpty ? null : t[_cur];
  }

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    _subs
      ..add(p.positionStream.listen((d) {
        if (mounted) setState(() => _pos = d);
      }))
      ..add(p.durationStream.listen((d) {
        if (mounted) setState(() => _dur = d);
      }))
      ..add(p.playerStateStream.listen((s) {
        if (!mounted) return;
        setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
        if (s.processingState == ProcessingState.completed) _select(_cur + 1, autoplay: true);
      }));
    return _player = p;
  }

  Future<void> _play() async {
    final t = _track;
    if (t == null || _loading) return;
    final p = _ensurePlayer();
    try {
      if (_loadedAsset != t.asset) {
        setState(() => _loading = true);
        await p.setAsset(t.asset);
        _loadedAsset = t.asset;
      }
      await p.setVolume(_muted ? 0 : 1);
      unawaited(p.play());
    } catch (_) {
      if (mounted) showNote(context, 'Kayıt açılamadı.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player?.pause();
    } else {
      await _play();
    }
  }

  Future<void> _select(int i, {bool autoplay = false}) async {
    final t = _tracks;
    if (t == null || t.isEmpty) return;
    setState(() {
      _cur = (i % t.length + t.length) % t.length;
      _pos = Duration.zero;
      _dur = null;
    });
    await _player?.stop();
    _loadedAsset = null;
    if (autoplay) await _play();
  }

  Future<void> _skip(int seconds) async {
    final p = _player;
    if (p == null || _loadedAsset == null) return;
    final max = _dur ?? Duration(seconds: _track?.seconds ?? 0);
    var to = _pos + Duration(seconds: seconds);
    if (to < Duration.zero) to = Duration.zero;
    if (to > max) to = max;
    await p.seek(to);
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _player?.setVolume(_muted ? 0 : 1);
    if (mounted) showNote(context, _muted ? 'Ses kapatıldı' : 'Ses açıldı');
  }

  String _mmss(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _tracks;
    return PageShell(
      title: 'İlahiler',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
      children: tracks == null
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tracks.isNotEmpty) ...[
                    SizedBox(width: 138, child: _rail(tracks)),
                    const SizedBox(width: 7),
                  ],
                  Expanded(child: _playerPanel()),
                ],
              ),
              const SizedBox(height: 12),
              if (_track != null) ...[
                SourceNote(
                    pal: _pal, text: 'Kaynak: ${_track!.credit}${_track!.note.isEmpty ? '' : '\n${_track!.note}'}'),
                const SizedBox(height: 6),
              ],
              SourceNote(
                pal: _pal,
                text: 'Yalnızca kaynağı ve kullanım izni belirtilmiş kayıtlar eklenir. '
                    'Her kaydın kaynağı ve lisansı oynatıcının altında yazılıdır.',
              ),
            ],
    );
  }

  // ---------------- Liste ----------------

  Widget _rail(List<Ilahi> tracks) {
    return Column(
      children: [
        for (var i = 0; i < tracks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _RailItem(
              number: i + 1,
              title: tracks[i].title,
              selected: i == _cur,
              onTap: () => _select(i, autoplay: true),
            ),
          ),
      ],
    );
  }

  // ---------------- Oynatıcı ----------------

  Widget _playerPanel() {
    final t = _track;
    final total = _dur ?? Duration(seconds: t?.seconds ?? 0);
    final pos = _pos > total ? total : _pos;
    final enabled = t != null;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0B64A), width: 1.5),
        gradient: const RadialGradient(
          center: Alignment(0, -1),
          radius: 1.2,
          colors: [Color(0xFF0A3323), Color(0xFF021A11), Color(0xFF000C07)],
          stops: [0, 0.45, 1],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFF000806), spreadRadius: 3),
          BoxShadow(color: Color(0x8CE0B64A), spreadRadius: 4.5),
          BoxShadow(color: Color(0x99000000), blurRadius: 26, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cover(t),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 0),
              child: Column(
                children: [
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF1C4), Color(0xFFE6C35A), Color(0xFFB78A26)],
                      stops: [0, 0.55, 1],
                    ).createShader(r),
                    child: Text(
                      t?.title ?? 'Henüz kayıt yok',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, height: 1.2),
                    ),
                  ),
                  if (t != null && t.performer.isNotEmpty)
                    Text(t.performer,
                        textAlign: TextAlign.center, style: const TextStyle(color: RC.creamSoft, fontSize: 11.5)),
                  if (t == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Kullanım izni belirtilmiş kayıtlar eklendikçe burada dinlenebilecek.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: RC.creamSoft, fontSize: 11.5, height: 1.4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: const Color(0xFFE6C35A),
                  inactiveTrackColor: const Color(0x33FFFFFF),
                  thumbColor: const Color(0xFFE6C35A),
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: total.inMilliseconds == 0 ? 0 : pos.inMilliseconds / total.inMilliseconds,
                  onChanged: enabled && _loadedAsset != null && total.inMilliseconds > 0
                      ? (v) => _player?.seek(Duration(milliseconds: (v * total.inMilliseconds).round()))
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Text(_mmss(pos), style: const TextStyle(color: RC.creamSoft, fontSize: 10.5)),
                  const Spacer(),
                  Text(_mmss(total), style: const TextStyle(color: RC.creamSoft, fontSize: 10.5)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  _ctl(Icons.skip_previous, 'Önceki', enabled ? () => _select(_cur - 1, autoplay: _playing) : null),
                  _ctl(Icons.replay_10, '10 sn geri', enabled ? () => _skip(-10) : null),
                  _ctl(_playing ? Icons.pause : Icons.play_arrow, _playing ? 'Duraklat' : 'Oynat',
                      enabled ? _toggle : null,
                      gold: true),
                  _ctl(Icons.forward_10, '10 sn ileri', enabled ? () => _skip(10) : null),
                  _ctl(_muted ? Icons.volume_off : Icons.volume_up, _muted ? 'Sesi aç' : 'Sesi kapat',
                      enabled ? _toggleMute : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(Ilahi? t) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/tiles/ilahiler.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x0D000000), Color(0x73000000)],
              ),
            ),
          ),
          if (!_playing)
            Center(
              child: Semantics(
                button: true,
                label: 'Oynat',
                child: GestureDetector(
                  onTap: t == null ? null : _play,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x8C000000),
                      border: Border.all(color: RC.bronzeBorder, width: 2),
                      boxShadow: const [BoxShadow(color: Color(0x73F0C75E), blurRadius: 14)],
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(15),
                            child: CircularProgressIndicator(strokeWidth: 2, color: RC.bronzeText),
                          )
                        : Icon(Icons.play_arrow, size: 28, color: t == null ? RC.creamSoft : RC.bronzeText),
                  ),
                ),
              ),
            ),
          if (t != null)
            Positioned(
              left: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(6)),
                child: Text(t.source,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ctl(IconData icon, String label, VoidCallback? onTap, {bool gold = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: Opacity(
              opacity: onTap == null ? 0.4 : 1,
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  gradient: gold
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE6C35A), Color(0xFFC29A2C)],
                        )
                      : RC.darkPanel,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: gold ? const Color(0xFF8A6414) : RC.gold(0.7)),
                  boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Icon(icon, size: 17, color: gold ? const Color(0xFF1D1406) : const Color(0xFFE9C96A)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final int number;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({required this.number, required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? RC.bronzeText : RC.cream;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? RC.bronze
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF062A1D), Color(0xFF01170F), Color(0xFF000C07)],
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? RC.bronzeBorder : RC.gold(0.75), width: selected ? 1.5 : 1),
            boxShadow: selected
                ? RC.bronzeGlow
                : const [BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                child: Text('$number',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: selected ? RC.bronzeText : const Color(0xFFE9C96A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
