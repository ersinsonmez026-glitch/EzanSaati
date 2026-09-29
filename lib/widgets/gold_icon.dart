import 'package:flutter/material.dart';

/// Uygulamanın ortak premium simgesi: açık altından koyu altına geçişli dolgu,
/// koyu zeminde hafif altın ışıltı. Krem zeminde [light] ile daha koyu altın kullanılır
/// (okunaklılık için ışıltı yok).
class GoldIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final bool light;
  final bool glow;
  final String? semanticLabel;

  const GoldIcon(this.icon, {super.key, this.size, this.light = false, this.glow = true, this.semanticLabel});

  static const _onDark = [Color(0xFFF6E6BE), Color(0xFFE3C07A), Color(0xFFB8914A)];
  static const _onLight = [Color(0xFFDDA530), Color(0xFFB8820F), Color(0xFF7A5208)];

  @override
  Widget build(BuildContext context) {
    final s = size ?? IconTheme.of(context).size ?? 24;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: light ? _onLight : _onDark,
        stops: const [0, 0.5, 1],
      ).createShader(r),
      child: Icon(
        icon,
        size: s,
        color: Colors.white,
        semanticLabel: semanticLabel,
        shadows: glow && !light ? [Shadow(color: const Color(0x80F0C75E), blurRadius: s * 0.35)] : null,
      ),
    );
  }
}

/// Hazır altın simge görseli (assets/images/ikon). Yaklaşık 26 pikselden büyük yerlerde kullanılır;
/// küçük araç simgelerinde [GoldIcon] daha net kalır.
class ArtIcon extends StatelessWidget {
  final String name;
  final double size;
  final String? semanticLabel;

  const ArtIcon(this.name, {super.key, this.size = 32, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/ikon/$name.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}

/// Altı vaktin simgeleri (İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı) — [ArtIcon] adları.
const kVakitIkonlari = ['imsak', 'gunes', 'cami', 'ikindi', 'aksam', 'yatsi'];

/// Yazının zemini: koyu yeşil, krem ya da fotoğraf.
enum GoldTone { onDark, onLight, onPhoto }

/// Simgelerle uyumlu, onlardan daha sakin altın yazı: hafif geçişli dolgu ve yumuşak gölge (ışıltı yok).
/// Tek satırlık başlık ve tuş adları için.
class GoldText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final GoldTone tone;
  final TextAlign? textAlign;
  final int? maxLines;

  const GoldText(this.text,
      {super.key, required this.style, this.tone = GoldTone.onDark, this.textAlign, this.maxLines});

  static const _colors = {
    GoldTone.onDark: [Color(0xFFF8EACB), Color(0xFFE8C88A), Color(0xFFC9A05A)],
    GoldTone.onLight: [Color(0xFFB07F10), Color(0xFF8A5E08), Color(0xFF654203)],
    GoldTone.onPhoto: [Color(0xFFFBF1D6), Color(0xFFEDD198), Color(0xFFD4AE68)],
  };

  static const _shadows = {
    GoldTone.onDark: [
      Shadow(color: Color(0xB3000000), blurRadius: 2, offset: Offset(0, 1)),
      Shadow(color: Color(0x1FE8C88A), blurRadius: 6),
    ],
    GoldTone.onLight: [Shadow(color: Color(0xB3FFFFFF), blurRadius: 0, offset: Offset(0, 1))],
    GoldTone.onPhoto: [
      Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1)),
      Shadow(color: Color(0x40F0C75E), blurRadius: 8),
    ],
  };

  @override
  Widget build(BuildContext context) {
    // Dikey geçiş yalnız satır yüksekliğine bağlıdır; tek satırlık yazılar için yeterli.
    final h = (style.fontSize ?? 14) * (style.height ?? 1.25);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _colors[tone]!,
        stops: const [0.15, 0.55, 0.95],
      ).createShader(Rect.fromLTWH(0, 0, 1, h));
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      softWrap: maxLines != 1,
      style: style.copyWith(color: null, foreground: paint, shadows: _shadows[tone]),
    );
  }
}
