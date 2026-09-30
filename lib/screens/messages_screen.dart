import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/content_store.dart';
import '../widgets/gold_icon.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Dini Mesajlar: bu cumanın kartı, favoriler ve hazır "Hayırlı Cumalar" kartları.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  ReadingPrefs? _prefs;
  bool _onlyFav = false;
  final int _week = weeklyMessageIndex(DateTime.now());

  @override
  void initState() {
    super.initState();
    ReadingPrefs.get().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  Set<String> get _favs => _prefs?.favorites(kMessageFavKey) ?? const {};

  void _toggleFav(MessageCardImage c) {
    final on = _prefs?.toggleFavorite(kMessageFavKey, c.id) ?? false;
    setState(() {});
    showNote(context, on ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı');
  }

  Future<void> _open(List<MessageCardImage> list, int i) async {
    await Navigator.of(context).push(AppRoute(builder: (_) => MessageViewerScreen(cards: list, index: i)));
    if (mounted) setState(() {}); // favoriler değişmiş olabilir
  }

  @override
  Widget build(BuildContext context) {
    final favs = _favs;
    final list = _onlyFav ? [for (final c in kMessageCards) if (favs.contains(c.id)) c] : kMessageCards;
    return PageShell(
      title: 'Dini Mesajlar',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _weekly(),
        const SizedBox(height: 12),
        Row(children: [
          _chip('Tümü', kMessageCards.length, !_onlyFav, () => setState(() => _onlyFav = false)),
          const SizedBox(width: 6),
          _chip('Favoriler', favs.length, _onlyFav, () => setState(() => _onlyFav = true), icon: Icons.favorite),
        ]),
        const SizedBox(height: 10),
        if (list.isEmpty)
          PaperBox(
            pal: _pal,
            padding: const EdgeInsets.all(22),
            child: Text(
              'Henüz favori kartınız yok. Kartların üzerindeki kalbe dokunarak ekleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _pal.ink2, fontSize: 13.5),
            ),
          )
        else
          _grid(list, favs),
        const SizedBox(height: 10),
        SourceNote(
          pal: _pal,
          text: 'Karta dokunup büyütebilir, telefonunuzun paylaş menüsüyle gönderebilirsiniz. '
              'Kartlardaki ayet mealleri ve ayet numaraları tek tek kontrol edilmiştir.',
        ),
      ],
    );
  }

  Widget _weekly() {
    final c = kMessageCards[_week];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3325), Color(0xFF03170F)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.gold(0.75), width: 1.2),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        GestureDetector(
          onTap: () => _open(kMessageCards, _week),
          child: _CardImage(card: c, width: 132, radius: 12),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('BU CUMANIN KARTI',
                style: TextStyle(color: RC.bronzeText, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 4),
            const Text('Hayırlı Cumalar',
                style: TextStyle(color: Color(0xFFF3E4C0), fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(c.ref, style: const TextStyle(color: Color(0xFFDCC697), fontSize: 13)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _GoldButton(label: 'Paylaş', icon: Icons.ios_share, onTap: () => shareMessageCard(context, c)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: _GhostButton(label: 'Büyüt', icon: Icons.open_in_full, onTap: () => _open(kMessageCards, _week)),
              ),
              const SizedBox(width: 6),
              _GhostButton(
                icon: _favs.contains(c.id) ? Icons.favorite : Icons.favorite_border,
                onTap: () => _toggleFav(c),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String label, int n, bool selected, VoidCallback onTap, {IconData? icon}) => PillButton(
        pal: _pal,
        selected: selected,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 4)],
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Opacity(opacity: 0.7, child: Text('$n', style: const TextStyle(fontSize: 11.5))),
        ]),
      );

  Widget _grid(List<MessageCardImage> list, Set<String> favs) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.75,
        ),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final c = list[i];
          final fav = favs.contains(c.id);
          return Semantics(
            button: true,
            label: 'Hayırlı Cumalar, ${c.ref}',
            child: GestureDetector(
              onTap: () => _open(list, i),
              child: Stack(children: [
                Positioned.fill(child: _CardImage(card: c, radius: 14)),
                Positioned(
                  right: 5,
                  top: 5,
                  child: Semantics(
                    button: true,
                    toggled: fav,
                    label: '${c.ref} favori',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggleFav(c),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x8C000000),
                          border: Border.all(color: RC.gold(0.5)),
                        ),
                        child: fav
                            ? const GoldIcon(Icons.favorite, size: 16)
                            : const Icon(Icons.favorite_border, size: 16, color: Color(0xFFF3E4C0)),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      );
}

/// Kartı telefonun paylaş menüsüyle görsel (PNG) olarak gönderir.
Future<void> shareMessageCard(BuildContext context, MessageCardImage c) async {
  try {
    final data = await rootBundle.load(c.asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    if (png == null) throw StateError('görsel üretilemedi');
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png', name: 'hayirli-cumalar.png')],
      fileNameOverrides: const ['hayirli-cumalar.png'],
    ));
  } catch (_) {
    if (context.mounted) showNote(context, 'Kart paylaşılamadı');
  }
}

/// Kartı tam ekran gösterir; yana kaydırınca sıradaki kart gelir.
class MessageViewerScreen extends StatefulWidget {
  final List<MessageCardImage> cards;
  final int index;

  const MessageViewerScreen({super.key, required this.cards, required this.index});

  @override
  State<MessageViewerScreen> createState() => _MessageViewerScreenState();
}

class _MessageViewerScreenState extends State<MessageViewerScreen> {
  late final _pager = PageController(initialPage: widget.index);
  late int _i = widget.index;
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
    _pager.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    await shareMessageCard(context, widget.cards[_i]);
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cards[_i];
    final fav = _prefs?.favorites(kMessageFavKey).contains(c.id) ?? false;
    const cream = Color(0xFFF3E4C0);
    return Scaffold(
      backgroundColor: const Color(0xFF020F0A),
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 52,
            child: Row(children: [
              IconButton(
                tooltip: 'Geri',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: cream),
              ),
              Expanded(
                child: Text('${_i + 1} / ${widget.cards.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: RC.bronzeText, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: fav ? 'Favorilerden çıkar' : 'Favorilere ekle',
                onPressed: () {
                  final on = _prefs?.toggleFavorite(kMessageFavKey, c.id) ?? false;
                  setState(() {});
                  showNote(context, on ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı');
                },
                icon: fav ? const GoldIcon(Icons.favorite, size: 24) : const Icon(Icons.favorite_border, color: cream),
              ),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pager,
              itemCount: widget.cards.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Center(child: _CardImage(card: widget.cards[i], radius: 16, fit: BoxFit.contain)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: _GoldButton(
              label: _sharing ? 'Hazırlanıyor…' : 'Paylaş',
              icon: Icons.ios_share,
              height: 50,
              onTap: _share,
            ),
          ),
        ]),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  final MessageCardImage card;
  final double? width;
  final double radius;
  final BoxFit fit;

  const _CardImage({required this.card, this.width, this.radius = 14, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      card.asset,
      fit: fit,
      width: width,
      height: width == null ? null : width! * 4 / 3,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.medium,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF03170F),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: RC.gold(0.6)),
      ),
      child: img,
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double height;

  const _GoldButton({required this.label, required this.icon, required this.onTap, this.height = 40});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE6C35A), Color(0xFFC29A2C)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8A6414)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: const Color(0xFF1D1406)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Color(0xFF1D1406), fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _GhostButton extends StatelessWidget {
  final String? label;
  final IconData icon;
  final VoidCallback onTap;

  const _GhostButton({this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 36,
            width: label == null ? 40 : null,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RC.gold(0.6)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: RC.bronzeText),
              if (label != null) ...[
                const SizedBox(width: 5),
                Text(label!,
                    style: const TextStyle(color: Color(0xFFF3E4C0), fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ),
      );
}
