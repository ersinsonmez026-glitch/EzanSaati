import 'package:flutter/material.dart';

import '../theme.dart';

/// Krem kâğıt renkleri. Telefon karanlık moddaysa göz almasın diye biraz kısılır.
class Parchment {
  final Color paper;
  final Color paperLight;
  final Color ink;
  final Color inkSoft;
  final Color line;

  const Parchment._(this.paper, this.paperLight, this.ink, this.inkSoft, this.line);

  static const Parchment day = Parchment._(
    Color(0xFFF7ECD4),
    Color(0xFFFFF8E8),
    Color(0xFF2A1F10),
    Color(0xFF6B5638),
    Color(0xFFD4AF37),
  );

  /// Gece: eski kitap sayfası tonu
  static const Parchment night = Parchment._(
    Color(0xFFD9C7A0),
    Color(0xFFE3D3B0),
    Color(0xFF231A0C),
    Color(0xFF5C4A2E),
    Color(0xFFB8952C),
  );

  static Parchment of(BuildContext context) =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark ? night : day;
}

/// Okuma sayfalarında kullanılan, altın çerçeveli krem kâğıt kart.
class ParchmentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const ParchmentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 20, 18, 20),
  });

  @override
  Widget build(BuildContext context) {
    final p = Parchment.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.6, -0.8),
          radius: 1.3,
          colors: [p.paperLight, p.paper],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: CustomPaint(
        painter: _CornerPainter(p.line),
        child: Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: p.ink),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Kartın dört köşesindeki ince altın süs.
class _CornerPainter extends CustomPainter {
  final Color color;

  const _CornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final dot = Paint()..color = color;

    void corner(double sx, double sy, Offset origin) {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.scale(sx, sy);
      final path = Path()
        ..moveTo(6, 30)
        ..lineTo(6, 16)
        ..quadraticBezierTo(6, 6, 16, 6)
        ..lineTo(30, 6)
        ..moveTo(11, 30)
        ..lineTo(11, 19)
        ..quadraticBezierTo(11, 11, 19, 11)
        ..lineTo(30, 11);
      canvas.drawPath(path, paint);
      canvas.drawCircle(const Offset(16, 16), 2.2, dot);
      canvas.restore();
    }

    corner(1, 1, Offset.zero);
    corner(-1, 1, Offset(size.width, 0));
    corner(1, -1, Offset(0, size.height));
    corner(-1, -1, Offset(size.width, size.height));
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}

/// Araç sayfalarında kullanılan koyu yeşil kart.
class DarkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const DarkCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF053523), Color(0xFF01241A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}

/// Başlık altındaki küçük altın süs çizgisi.
class GoldDivider extends StatelessWidget {
  final Color? color;

  const GoldDivider({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.gold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 44, height: 1, color: c),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(width: 7, height: 7, color: c),
            ),
          ),
          Container(width: 44, height: 1, color: c),
        ],
      ),
    );
  }
}
