import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/content_store.dart';

/// Dini mesaj kartı (1080 x 1080 tasarım birimi, bulunduğu kutuya ölçeklenir).
/// Çizim onizleme/09-dini-mesajlar.html'deki kart tasarımının aynısıdır:
/// fotoğraf, kemer, gece, kâğıt ve bölünmüş zeminler; altta Ezan Saati imzası.
class MessageCard extends StatelessWidget {
  final ReligiousMessage message;

  const MessageCard({super.key, required this.message});

  static const double _s = 1080;
  static const double _band = 128;

  static const _palettes = {
    'emerald': [Color(0xFF0E4A33), Color(0xFF04200F)],
    'navy': [Color(0xFF15305C), Color(0xFF060F26)],
    'burgundy': [Color(0xFF6B1A2C), Color(0xFF2A0710)],
    'teal': [Color(0xFF0F5558), Color(0xFF04262A)],
    'purple': [Color(0xFF43235C), Color(0xFF150A24)],
    'cream': [Color(0xFFF8EFD8), Color(0xFFE6D3A6)],
    'sand': [Color(0xFFEFE0BF), Color(0xFFD9C08C)],
  };

  List<Color> get _pal => _palettes[message.palette] ?? _palettes['emerald']!;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _s,
        height: _s,
        child: Stack(children: [..._background(), _text(), _watermark(), _footer()]),
      ),
    );
  }

  bool get _paper => message.background == 'paper';

  // ------------------------------------------------------------------ zemin

  List<Widget> _background() {
    final m = message;
    switch (m.background) {
      case 'photo':
        return [
          Positioned.fill(child: _photo()),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x5904140E), Color(0x9904140E), Color(0xD904140E)],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _FramePainter(34, 3, Color(0xCCE2C26E)))),
        ];
      case 'arch':
        return [
          Positioned.fill(child: DecoratedBox(decoration: _gradient())),
          const Positioned.fill(child: CustomPaint(painter: _PatternPainter(Color(0x17E2C26E)))),
          const Positioned.fill(child: CustomPaint(painter: _ArchPainter())),
        ];
      case 'night':
        return [
          Positioned.fill(child: DecoratedBox(decoration: _gradient())),
          Positioned.fill(child: CustomPaint(painter: _NightPainter(m.title.length * 7 + 3))),
          const Positioned.fill(child: CustomPaint(painter: _FramePainter(40, 2, Color(0x8CE2C26E)))),
        ];
      case 'paper':
        return [
          Positioned.fill(child: DecoratedBox(decoration: _gradient())),
          const Positioned.fill(child: CustomPaint(painter: _PatternPainter(Color(0x14966E1E)))),
          const Positioned.fill(child: CustomPaint(painter: _PaperFramePainter())),
        ];
      case 'split':
      default:
        return [
          Positioned(left: 0, right: 0, top: 0, height: 540, child: _photo()),
          Positioned(
            left: 0,
            right: 0,
            top: 540,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _pal),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _SplitPainter(_pal[0]))),
        ];
    }
  }

  Widget _photo() => Image.asset('assets/images/mesaj/${message.image ?? message.category}.jpg', fit: BoxFit.cover);

  BoxDecoration _gradient() => BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: const Alignment(-0.4, 1), colors: _pal),
      );

  // ------------------------------------------------------------------ yazı

  Widget _text() {
    final m = message;
    var top = 110.0, bottom = _s - _band - 40, maxW = _s - 220;
    if (m.background == 'arch') {
      top = 250;
      bottom = _s - _band - 70;
      maxW = _s - 380;
    } else if (m.background == 'night') {
      top = 250;
    } else if (m.background == 'split') {
      top = 580;
      bottom = _s - _band - 20;
    }

    final cTitle = _paper ? const Color(0xFF0B3F2B) : const Color(0xFFF3D27A);
    final cBody = _paper ? const Color(0xFF3A2C14) : const Color(0xFFFBF5E6);
    final cRef = _paper ? const Color(0xFF8A6414) : const Color(0xFFE2C26E);
    final shadows = _paper ? null : const [Shadow(color: Color(0x80000000), blurRadius: 8)];

    TextStyle st(double size, Color c, FontWeight w, double lh, {bool italic = false}) => TextStyle(
          fontFamily: 'Lora',
          fontSize: size,
          fontWeight: w,
          color: c,
          height: lh / size,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          shadows: shadows,
        );

    final divider = SizedBox(
      height: 50,
      child: Center(child: Container(width: 120, height: 3, color: cRef)),
    );

    final blocks = m.hasVerse
        ? <Widget>[
            Text('“${m.verse}”', textAlign: TextAlign.center, style: st(42, cBody, FontWeight.w500, 60, italic: true)),
            const SizedBox(height: 6),
            Text(m.verseRef ?? '', textAlign: TextAlign.center, style: st(26, cRef, FontWeight.w600, 40)),
            divider,
            Text(m.title, textAlign: TextAlign.center, style: st(66, cTitle, FontWeight.w700, 80)),
          ]
        : <Widget>[
            Text(m.title, textAlign: TextAlign.center, style: st(72, cTitle, FontWeight.w700, 86)),
            divider,
            if (m.body != null) Text(m.body!, textAlign: TextAlign.center, style: st(46, cBody, FontWeight.w500, 64)),
          ];

    return Positioned(
      left: (_s - maxW) / 2,
      width: maxW,
      top: top,
      height: bottom - top,
      child: Center(
        // Uzun metin alana sığmazsa küçültülür.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: maxW,
            child: Column(mainAxisSize: MainAxisSize.min, children: blocks),
          ),
        ),
      ),
    );
  }

  Widget _watermark() {
    final top = message.background == 'split' ? 70.0 : (_paper ? 88.0 : 72.0);
    final color = _paper ? const Color(0xFF6B4F12) : const Color(0xFFF3E6C0);
    return Positioned(
      right: 70,
      top: top,
      child: Opacity(
        opacity: 0.6,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nightlight_round, size: 24, color: color),
            const SizedBox(width: 6),
            Text('Ezan Saati',
                style: TextStyle(fontFamily: 'Lora', fontSize: 24, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: _band,
      child: Container(
        decoration: BoxDecoration(
          color: _paper ? const Color(0xFF0B3F2B) : const Color(0xD103140D),
          border: const Border(top: BorderSide(color: Color(0xFFD9B457), width: 2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/mesaj/logo_kart.png', width: 82, height: 82),
            const SizedBox(width: 18),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ezan Saati',
                    style: TextStyle(
                        fontFamily: 'Lora', fontSize: 42, fontWeight: FontWeight.w700, color: Color(0xFFF3D27A))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ çizimler

/// Sekiz köşeli yıldız yolu.
Path _star8(double x, double y, double r) {
  final p = Path();
  for (var i = 0; i < 16; i++) {
    final a = i * math.pi / 8;
    final rr = i.isOdd ? r * 0.45 : r;
    final pt = Offset(x + math.cos(a) * rr, y + math.sin(a) * rr);
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// Zemindeki yıldız deseni.
class _PatternPainter extends CustomPainter {
  final Color color;

  const _PatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (double y = 60; y < size.height; y += 120) {
      for (double x = 120; x < size.width; x += 120) {
        canvas.drawPath(_star8(x, y, 26), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) => old.color != color;
}

/// İçeriden çizilmiş ince çerçeve.
class _FramePainter extends CustomPainter {
  final double inset;
  final double width;
  final Color color;

  const _FramePainter(this.inset, this.width, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => false;
}

/// Kemer (mihrap) çerçevesi.
class _ArchPainter extends CustomPainter {
  const _ArchPainter();

  Path _arch(double x0, double x1, double top, double bot) {
    final cx = (x0 + x1) / 2;
    const sh = 150.0;
    return Path()
      ..moveTo(x0, bot)
      ..lineTo(x0, top + sh)
      ..quadraticBezierTo(x0, top + sh * 0.25, cx, top)
      ..quadraticBezierTo(x1, top + sh * 0.25, x1, top + sh)
      ..lineTo(x1, bot)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    const band = MessageCard._band;
    final outer = _arch(150, s - 150, 90, s - band - 30);
    canvas.drawPath(outer, Paint()..color = const Color(0x38000000));
    canvas.drawPath(
      outer,
      Paint()
        ..color = const Color(0xFFD9B457)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawPath(
      _arch(168, s - 168, 112, s - band - 48),
      Paint()
        ..color = const Color(0x73D9B457)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ArchPainter old) => false;
}

/// Gece zemini: yıldızlar ve hilal.
class _NightPainter extends CustomPainter {
  final int seed;

  const _NightPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    var state = seed;
    double rnd() {
      state = (state * 9301 + 49297) % 233280;
      return state / 233280;
    }

    final starPaint = Paint()..color = const Color(0xCCFFF4D2);
    for (var i = 0; i < 46; i++) {
      final sx = rnd() * s, sy = rnd() * s * 0.8, sr = rnd() * 2.2 + 0.8;
      canvas.drawCircle(Offset(sx, sy), sr, starPaint);
    }
    final c = Offset(s - 230, 210);
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: 92)),
      Path()..addOval(Rect.fromCircle(center: c + const Offset(36, -26), radius: 80)),
    );
    canvas.drawPath(
      moon,
      Paint()
        ..color = const Color(0x59F0CF73)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
    canvas.drawPath(moon, Paint()..color = const Color(0xFFF0CF73));
  }

  @override
  bool shouldRepaint(covariant _NightPainter old) => old.seed != seed;
}

/// Kâğıt zeminin çift çerçevesi ve köşe baklavaları.
class _PaperFramePainter extends CustomPainter {
  const _PaperFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    const gold = Color(0xFFA67C1E);
    final stroke = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTRB(46, 46, s - 46, s - 46), stroke..strokeWidth = 4);
    canvas.drawRect(Rect.fromLTRB(62, 62, s - 62, s - 62), stroke..strokeWidth = 1.5);
    final bottom = s - MessageCard._band;
    for (final c in [const Offset(62, 62), Offset(s - 62, 62), Offset(62, bottom), Offset(s - 62, bottom)]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(math.pi / 4);
      canvas.drawRect(const Rect.fromLTWH(-11, -11, 22, 22), Paint()..color = gold);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PaperFramePainter old) => false;
}

/// Bölünmüş zeminde fotoğraf ile renk arasındaki altın çizgi ve baklava.
class _SplitPainter extends CustomPainter {
  final Color fill;

  const _SplitPainter(this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    const ph = 540.0;
    const gold = Color(0xFFD9B457);
    canvas.drawRect(Rect.fromLTWH(0, ph - 3, size.width, 6), Paint()..color = gold);
    canvas.save();
    canvas.translate(size.width / 2, ph);
    canvas.rotate(math.pi / 4);
    const r = Rect.fromLTWH(-22, -22, 44, 44);
    canvas.drawRect(r, Paint()..color = fill);
    canvas.drawRect(
      r,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SplitPainter old) => old.fill != fill;
}
