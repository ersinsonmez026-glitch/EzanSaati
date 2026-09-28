import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data/namaz_videolari.dart';
import '../widgets/gold_icon.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Diyanet'in resmî kanallarından namaz videoları: uygulama içinde oynatılır; oynatıcı açılmazsa
/// "YouTube'da aç" ile YouTube uygulamasında izlenir. İnternet gerekir.
class VideoScreen extends StatefulWidget {
  final List<NamazVideo> videos;
  final int index;

  const VideoScreen({super.key, required this.videos, this.index = 0});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  // Birim testlerinde WebView yoktur; oynatıcı yerine kapak gösterilir.
  static final _canPlay = !Platform.environment.containsKey('FLUTTER_TEST');

  final _pal = PagePalette.current();
  late int _index = widget.index;
  YoutubePlayerController? _player;

  NamazVideo get _video => widget.videos[_index];

  @override
  void initState() {
    super.initState();
    if (_canPlay) {
      _player = YoutubePlayerController.fromVideoId(
        videoId: _video.id,
        autoPlay: true,
        params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true),
      );
    }
  }

  @override
  void dispose() {
    _player?.close();
    super.dispose();
  }

  void _select(int i) {
    setState(() => _index = i);
    _player?.loadVideoById(videoId: widget.videos[i].id);
  }

  Future<void> _openYoutube() async {
    try {
      if (await launchUrl(Uri.parse(_video.url), mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) showNote(context, 'YouTube açılamadı.');
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    return PageShell(
      title: 'Videolu Anlatım',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: RC.gold(0.75), width: 1.5)),
            child: _player != null
                ? YoutubePlayer(controller: _player!, backgroundColor: Colors.black)
                : AspectRatio(aspectRatio: 16 / 9, child: _Thumb(video: v)),
          ),
        ),
        const SizedBox(height: 10),
        PaperBox(
          pal: _pal,
          radius: 14,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.title, style: TextStyle(color: _pal.ink, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${v.channel} · ${v.duration}', style: TextStyle(color: _pal.ink2, fontSize: 12.5)),
              const SizedBox(height: 10),
              DarkButton(label: "YouTube'da aç", onTap: _openYoutube),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionHead(pal: _pal, title: 'Diğer Videolar'),
        const SizedBox(height: 6),
        for (var i = 0; i < widget.videos.length; i++)
          if (i != _index)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VideoTile(pal: _pal, video: widget.videos[i], onTap: () => _select(i)),
            ),
        SourceNote(
          pal: _pal,
          text: "Videolar Diyanet İşleri Başkanlığı'nın resmî YouTube kanallarındandır (DiyanetTV, Diyanet Çocuk, "
              'Diyanet Dijital, TRT Diyanet Çocuk). İzlemek için internet gerekir.',
        ),
      ],
    );
  }
}

/// Video kapağı (internetten); yüklenemezse sade oynat simgesi.
class _Thumb extends StatelessWidget {
  final NamazVideo video;

  const _Thumb({required this.video});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          video.thumbnail,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const DecoratedBox(decoration: BoxDecoration(gradient: RC.darkPanel)),
        ),
        const Center(
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0x99000000)),
            child: Padding(padding: EdgeInsets.all(6), child: GoldIcon(Icons.play_arrow_rounded, size: 26)),
          ),
        ),
      ],
    );
  }
}

/// Liste satırı: kapak, başlık, kanal ve süre.
class VideoTile extends StatelessWidget {
  final PagePalette pal;
  final NamazVideo video;
  final VoidCallback onTap;

  const VideoTile({super.key, required this.pal, required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${video.title} videosu',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PaperBox(
          pal: pal,
          radius: 12,
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 112, height: 63, child: _Thumb(video: video)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: pal.ink, fontSize: 13, fontWeight: FontWeight.w700, height: 1.3)),
                    const SizedBox(height: 2),
                    Text('${video.channel} · ${video.duration}', style: TextStyle(color: pal.ink2, fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
