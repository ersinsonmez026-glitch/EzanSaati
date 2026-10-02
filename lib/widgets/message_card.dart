import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/content_store.dart';

/// Mesaj kartı: yazısız arka plan, üstte yumuşak karartma, ortalanmış ayet/hadis metni, altın kaynak satırı
/// ve sağ altta Ezan Saati logosu. Ekranda da paylaşılan resimde de aynı çizim kullanılır (3:4).
class MessageCardPainter {
  static const double aspect = 3 / 4;
  static const _logoAsset = 'assets/images/logo_ezan_saati.webp';
  static final _cache = <String, Future<ui.Image>>{};

  static Future<ui.Image> _image(String asset) => _cache[asset] ??= () async {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      }();

  /// Kartın çizimi için arka plan ve logo.
  static Future<(ui.Image, ui.Image)> load(MessageCardImage c) async =>
      (await _image(c.asset), await _image(_logoAsset));

  /// [size] boyutunda kartı çizer.
  static void paint(Canvas canvas, Size size, MessageCardImage c, ui.Image bg, ui.Image logo) {
    final w = size.width, h = size.height, u = w / 360; // 360 genişlik esas
    // Arka plan: kartı tamamen kaplar, üstten hizalı
    final s = (w / bg.width) > (h / bg.height) ? w / bg.width : h / bg.height;
    final src = Rect.fromLTWH(
        (bg.width - w / s) / 2, 0, w / s, h / s);
    canvas.drawImageRect(bg, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
    // Yazının arkası: üstten aşağı açılan karartma
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
          Color.fromRGBO(3, 12, 9, c.shade),
          Color.fromRGBO(3, 12, 9, c.shade * 0.85),
          const Color.fromRGBO(3, 12, 9, 0),
          const Color.fromRGBO(3, 12, 9, 0.25),
        ], const [0, 0.42, 0.68, 1]),
    );
    // Metin: üst %60'lık alana sığacak en büyük boyut
    final maxW = w - 44 * u, maxH = h * 0.56;
    TextPainter quote(double fs) => TextPainter(
          text: TextSpan(
            text: '“${c.text}”',
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: fs,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFFFAEE),
              shadows: [Shadow(color: const Color(0xCC000000), blurRadius: 6 * u, offset: Offset(0, 1.5 * u))],
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxW);
    var fs = 25 * u;
    var tp = quote(fs);
    while (tp.height > maxH && fs > 12 * u) {
      fs -= 1 * u;
      tp = quote(fs);
    }
    final ref = TextPainter(
      text: TextSpan(
        text: c.ref,
        style: TextStyle(
          fontFamily: 'Lora',
          fontSize: 13.5 * u,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE8C88A),
          shadows: [Shadow(color: const Color(0xCC000000), blurRadius: 5 * u, offset: Offset(0, 1 * u))],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxW);
    final blockH = tp.height + 12 * u + ref.height;
    final top = 30 * u + (maxH - tp.height) * 0.35;
    tp.paint(canvas, Offset((w - tp.width) / 2, top));
    ref.paint(canvas, Offset((w - ref.width) / 2, top + blockH - ref.height));
    // Logo sağ altta, hafif gölgeli
    final lw = 78 * u, lh = lw * logo.height / logo.width;
    final dst = Rect.fromLTWH(w - lw - 14 * u, h - lh - 14 * u, lw, lh);
    final lsrc = Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble());
    canvas.drawImageRect(
        logo,
        lsrc,
        dst.shift(Offset(1.5 * u, 2 * u)),
        Paint()
          ..colorFilter = const ColorFilter.mode(Color(0x99000000), BlendMode.srcIn)
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 3 * u, sigmaY: 3 * u));
    canvas.drawImageRect(logo, lsrc, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  /// Paylaşmak için kartın PNG resmi (1080 × 1440).
  static Future<Uint8List> png(MessageCardImage c) async {
    final (bg, logo) = await load(c);
    const size = Size(1080, 1440);
    final rec = ui.PictureRecorder();
    paint(Canvas(rec), size, c, bg, logo);
    final img = await rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    if (data == null) throw StateError('kart resmi üretilemedi');
    return data.buffer.asUint8List();
  }
}

/// Ekranda mesaj kartı (3:4); resimler yüklenene kadar koyu zemin.
class MessageCard extends StatefulWidget {
  final MessageCardImage card;

  const MessageCard({super.key, required this.card});

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  (ui.Image, ui.Image)? _imgs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MessageCard old) {
    super.didUpdateWidget(old);
    if (old.card.id != widget.card.id) _load();
  }

  void _load() {
    final id = widget.card.id;
    unawaited(MessageCardPainter.load(widget.card).then((v) {
      if (mounted && widget.card.id == id) setState(() => _imgs = v);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final imgs = _imgs;
    return AspectRatio(
      aspectRatio: MessageCardPainter.aspect,
      child: imgs == null
          ? const ColoredBox(color: Color(0xFF0B1A14))
          : CustomPaint(painter: _Painter(widget.card, imgs.$1, imgs.$2)),
    );
  }
}

class _Painter extends CustomPainter {
  final MessageCardImage card;
  final ui.Image bg, logo;

  _Painter(this.card, this.bg, this.logo);

  @override
  void paint(Canvas canvas, Size size) => MessageCardPainter.paint(canvas, size, card, bg, logo);

  @override
  bool shouldRepaint(_Painter old) => old.card.id != card.id || old.bg != bg;
}
