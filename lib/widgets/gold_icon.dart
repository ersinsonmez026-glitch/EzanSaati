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

  static const _onDark = [Color(0xFFFFF1C4), Color(0xFFE6C35A), Color(0xFFB78A26)];
  static const _onLight = [Color(0xFFD9A93F), Color(0xFFB8892A), Color(0xFF7A5510)];

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
    GoldTone.onDark: [Color(0xFFF4E2AE), Color(0xFFDDBD6A), Color(0xFFBF9A45)],
    GoldTone.onLight: [Color(0xFF8E6A22), Color(0xFF6E4F14), Color(0xFF55390A)],
    GoldTone.onPhoto: [Color(0xFFFFF3D2), Color(0xFFF0D48C), Color(0xFFD9B461)],
  };

  static const _shadows = {
    GoldTone.onDark: [Shadow(color: Color(0x99000000), blurRadius: 2, offset: Offset(0, 1))],
    GoldTone.onLight: [Shadow(color: Color(0x99FFFFFF), blurRadius: 0, offset: Offset(0, 1))],
    GoldTone.onPhoto: [Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1))],
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
