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
