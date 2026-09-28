import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../services/content_store.dart';
import '../widgets/message_card.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Mesajı büyük gösterir; görsel (1080 x 1080) olarak paylaşır ya da metnini kopyalar.
/// Mesaj metinleri değiştirilemez.
class MessageShareScreen extends StatefulWidget {
  final List<ReligiousMessage> messages;
  final int index;

  const MessageShareScreen({super.key, required this.messages, required this.index});

  @override
  State<MessageShareScreen> createState() => _MessageShareScreenState();
}

class _MessageShareScreenState extends State<MessageShareScreen> {
  final _pal = PagePalette.current();
  final _cardKey = GlobalKey();
  final _scroll = ScrollController();
  late int _index = widget.index;
  ReadingPrefs? _prefs;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    ReadingPrefs.get().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  ReligiousMessage get _m => widget.messages[_index];

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('görsel üretilemedi');
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'ezan-saati-mesaj.png')],
        fileNameOverrides: const ['ezan-saati-mesaj.png'],
      ));
    } catch (_) {
      if (mounted) showNote(context, 'Görsel paylaşılamadı');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _go(int i) {
    setState(() => _index = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final fav = _prefs?.favorites(kMessageFavKey).contains('${m.index}') ?? false;
    final last = widget.messages.length - 1;

    return PageShell(
      title: 'Mesajı Paylaş',
      background: _pal.background,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RC.gold(0.7), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x40281905), blurRadius: 14, offset: Offset(0, 4))],
          ),
          child: RepaintBoundary(
            key: _cardKey,
            child: AspectRatio(aspectRatio: 1, child: MessageCard(message: m)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _button(
                label: _sharing ? 'Hazırlanıyor...' : 'Paylaş',
                icon: Icons.ios_share,
                primary: true,
                onTap: _shareImage,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _button(
                label: 'Favori',
                icon: fav ? Icons.favorite : Icons.favorite_border,
                onTap: () {
                  final on = _prefs?.toggleFavorite(kMessageFavKey, '${m.index}') ?? false;
                  setState(() {});
                  showNote(context, on ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı');
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _button(
                label: 'Kopyala',
                icon: Icons.copy_outlined,
                onTap: () => copyToClipboard(context, m.shareText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PaperBox(
          pal: _pal,
          radius: 14,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('BAŞLIK'),
              Text(m.title, style: TextStyle(color: _pal.ink, fontSize: 15, fontWeight: FontWeight.w700)),
              _label(m.hasVerse ? 'AYET' : 'MESAJ'),
              Text(
                m.hasVerse ? '“${m.verse}”' : (m.body ?? ''),
                style: TextStyle(
                  color: _pal.ink,
                  fontSize: 14.5,
                  height: 1.5,
                  fontStyle: m.hasVerse ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              if (m.hasVerse) ...[
                const SizedBox(height: 8),
                DashedLine(color: _pal.line),
                const SizedBox(height: 8),
                Text('${m.verseRef} · Meal: Ruvvâd Tercüme Merkezi, QuranEnc.com',
                    style: TextStyle(color: _pal.ink2, fontSize: 12)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        PrevNextRow(
          prevLabel: '‹ Önceki mesaj',
          nextLabel: 'Sonraki mesaj ›',
          onPrev: _index > 0 ? () => _go(_index - 1) : null,
          onNext: _index < last ? () => _go(_index + 1) : null,
        ),
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Text(t,
            style: TextStyle(color: _pal.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );

  Widget _button({required String label, required IconData icon, required VoidCallback onTap, bool primary = false}) {
    final fg = primary ? const Color(0xFF1D1406) : _pal.ink;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE6C35A), Color(0xFFC29A2C)],
                  )
                : null,
            color: primary ? null : _pal.chip,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary ? const Color(0xFF8A6414) : _pal.line),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(color: fg, fontSize: primary ? 14.5 : 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
