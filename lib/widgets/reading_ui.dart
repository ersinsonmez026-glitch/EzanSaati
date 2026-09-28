import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'page_shell.dart';

/// Sureler, Dualar ve Namaz Öğren sayfalarının renkleri (TASARIM_KURALLARI.md v2).
/// Gündüz krem kâğıt, akşamdan imsaka kadar koyu yeşil görünüm kullanılır.
class PagePalette {
  final bool night;
  final Color page;
  final Color paper;
  final Color paper2;
  final Color line;
  final Color ink;
  final Color ink2;
  final Color gold;
  final Color chip;
  final Color pill;
  final List<Color> verseCard; // Günün ayeti/duası kâğıt alanı

  const PagePalette._({
    required this.night,
    required this.page,
    required this.paper,
    required this.paper2,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.gold,
    required this.chip,
    required this.pill,
    required this.verseCard,
  });

  static const krem = PagePalette._(
    night: false,
    page: Color(0xFFEFE4C9),
    paper: Color(0xFFF8EFDA),
    paper2: Color(0xFFF1E5C8),
    line: Color(0x59966E1E),
    ink: Color(0xFF2A1F10),
    ink2: Color(0xFF6F5A3A),
    gold: Color(0xFFB8892A),
    chip: Color(0xFFF3E8CF),
    pill: Color(0xFFEADCB9),
    verseCard: [Color(0xFFFBF3E0), Color(0xFFF1E4C5)],
  );

  static const yesil = PagePalette._(
    night: true,
    page: Color(0xFF000E09),
    paper: Color(0xFF021A12),
    paper2: Color(0xFF00120C),
    line: Color(0x73D4AF37),
    ink: Color(0xFFF3ECD9),
    ink2: Color(0xFFA9BFB3),
    gold: Color(0xFFD4AF37),
    chip: Color(0xFF00140E),
    pill: Color(0xFF021A12),
    verseCard: [Color(0xFFE9DCBC), Color(0xFFDCCB9F)],
  );

  /// Başlık manzarasıyla aynı kural: imsak-akşam arası krem, sonrası yeşil.
  static PagePalette current() => isDaytime() ? krem : yesil;

  /// Sayfa zemini. Yeşilde ortası hafif aydınlık radyal geçiş.
  Decoration get background => night
      ? const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.68),
            radius: 1.0,
            colors: [Color(0xFF06281C), Color(0xFF011810), Color(0xFF000A06)],
            stops: [0, 0.45, 1],
          ),
        )
      : BoxDecoration(color: page);

  LinearGradient get paperGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [paper, paper2],
      );
}

/// Ortak sabit renkler ve geçişler.
class RC {
  static const cream = Color(0xFFF3ECD9);
  static const creamSoft = Color(0xFFB9CDC2);
  static const goldText = Color(0xFFF3DC97);
  static const goldIcon = Color(0xFFE2C26E);
  static const goldBorder = Color(0xFFD4AF37);
  static const verseInk = Color(0xFF2A1F10);
  static const verseInk2 = Color(0xFF6F5A3A);
  static const verseGold = Color(0xFFB8892A);

  /// Kart / tuş zemini: yukarıdan aşağı koyu yeşil.
  static const darkPanel = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A3525), Color(0xFF01170F), Color(0xFF000C07)],
    stops: [0, 0.55, 1],
  );

  /// Seçili durum: bronz.
  static const bronze = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF6E5114), Color(0xFF4A3508), Color(0xFF2A1C03)],
  );
  static const bronzeBorder = Color(0xFFF0C75E);
  static const bronzeText = Color(0xFFFFE08A);
  static const bronzeGlow = [BoxShadow(color: Color(0x73F0C75E), blurRadius: 12)];

  static Color gold(double opacity) => goldBorder.withValues(alpha: opacity);
}

/// Arapça yazı tipleri (assets/fonts, SIL OFL).
const kQuranFont = 'AmiriQuran';
const kArabicFont = 'Amiri';

/// Türkçe'ye uygun büyük harf (i → İ, ı → I).
String trUpper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Aramada Türkçe ve şapkalı harfleri sadeleştirir: "Yâsîn" → "yasin".
String trSearchKey(String s, {bool dropSpaces = false}) {
  final lower = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    switch (ch) {
      case 'â':
      case 'à':
        b.write('a');
      case 'î':
      case 'ı':
        b.write('i');
      case 'û':
      case 'ü':
        b.write('u');
      case 'ö':
        b.write('o');
      case 'ç':
        b.write('c');
      case 'ş':
        b.write('s');
      case 'ğ':
        b.write('g');
      case "'":
      case '’':
      case '-':
        break;
      case ' ':
        if (!dropSpaces) b.write(ch);
      default:
        b.write(ch);
    }
  }
  return b.toString();
}

/// Kısa bilgi mesajı.
void showNote(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2400)));
}

Future<void> copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showNote(context, 'Kopyalandı');
}

Future<void> shareText(BuildContext context, String text) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text));
  } catch (_) {
    if (context.mounted) showNote(context, 'Paylaşılamadı');
  }
}

/// İki dönük kareden oluşan sekizgen yıldız içinde sıra numarası.
class OctaBadge extends StatelessWidget {
  final int number;
  final double size;
  final Color color;
  final Color textColor;

  const OctaBadge({
    super.key,
    required this.number,
    required this.color,
    required this.textColor,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OctaPainter(color),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              color: textColor,
              fontSize: size * (number > 99 ? 0.27 : 0.32),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _OctaPainter extends CustomPainter {
  final Color color;

  const _OctaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 40;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(9 * s, 9 * s, 22 * s, 22 * s),
      Radius.circular(2 * s),
    );
    canvas.drawRRect(rect, paint);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(math.pi / 4);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OctaPainter old) => old.color != color;
}

/// Kesik çizgi (ayraç).
class DashedLine extends StatelessWidget {
  final Color color;

  const DashedLine({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashPainter(color)),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;

  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0.5), Offset(math.min(x + 3, size.width), 0.5), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

/// "✦" süsü, iki yanında incelen altın çizgi.
class OrnamentStar extends StatelessWidget {
  final Color color;
  final double lineWidth;

  const OrnamentStar({super.key, this.color = RC.verseGold, this.lineWidth = 50});

  @override
  Widget build(BuildContext context) {
    Widget line(bool flip) => Container(
          width: lineWidth,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: flip ? [color, color.withValues(alpha: 0)] : [color.withValues(alpha: 0), color],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          line(false),
          const SizedBox(width: 6),
          SizedBox(width: 9, height: 9, child: CustomPaint(painter: _StarPainter(color))),
          const SizedBox(width: 6),
          line(true),
        ],
      ),
    );
  }
}

/// Dört köşeli küçük yıldız (✦). Yazı tipinde bu işaret olmayabileceği için çizilir.
class _StarPainter extends CustomPainter {
  final Color color;

  const _StarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, cx = w / 2, cy = h / 2, k = w * 0.14;
    final path = Path()
      ..moveTo(cx, 0)
      ..quadraticBezierTo(cx + k, cy - k, w, cy)
      ..quadraticBezierTo(cx + k, cy + k, cx, h)
      ..quadraticBezierTo(cx - k, cy + k, 0, cy)
      ..quadraticBezierTo(cx - k, cy - k, cx, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.color != color;
}

/// Krem/yeşil kâğıt kutu.
class PaperBox extends StatelessWidget {
  final PagePalette pal;
  final Widget child;
  final double radius;
  final EdgeInsets? padding;

  const PaperBox({super.key, required this.pal, required this.child, this.radius = 16, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: pal.paperGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: pal.line),
      ),
      child: child,
    );
  }
}

/// Seçilebilir yuvarlak düğme (filtre, sekme). Seçiliyken bronz.
class PillButton extends StatelessWidget {
  final PagePalette pal;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double height;
  final double radius;
  final EdgeInsets padding;
  final Color? background; // seçili değilken zemin (varsayılan: chip rengi)
  final bool border;

  const PillButton({
    super.key,
    required this.pal,
    required this.selected,
    required this.onTap,
    required this.child,
    this.height = 32,
    this.radius = 999,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.background,
    this.border = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? RC.bronzeText : pal.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? RC.bronze : null,
            color: selected ? null : (background ?? pal.chip),
            borderRadius: BorderRadius.circular(radius),
            border: selected
                ? Border.all(color: RC.bronzeBorder)
                : (border ? Border.all(color: pal.line) : null),
            boxShadow: selected
                ? RC.bronzeGlow
                : (pal.night && border
                    ? const [BoxShadow(color: Color(0x73000000), blurRadius: 6, offset: Offset(0, 2))]
                    : null),
          ),
          child: IconTheme(
            data: IconThemeData(color: fg, size: 14),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Yuvarlak arama kutusu.
class SearchBox extends StatelessWidget {
  final PagePalette pal;
  final String hint;
  final ValueChanged<String> onChanged;

  const SearchBox({super.key, required this.pal, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: pal.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: pal.line),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: pal.gold),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              cursorColor: pal.gold,
              style: TextStyle(color: pal.ink, fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: pal.ink2, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bölüm başlığı: solda başlık, sağda küçük yazı ya da düğme.
class SectionHead extends StatelessWidget {
  final PagePalette pal;
  final String title;
  final Widget? trailing;

  const SectionHead({super.key, required this.pal, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(title, style: TextStyle(color: pal.ink, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Sayfa altındaki küçük kaynak notu.
class SourceNote extends StatelessWidget {
  final PagePalette pal;
  final String text;

  const SourceNote({super.key, required this.pal, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: pal.ink2, fontSize: 10.5, height: 1.5),
      ),
    );
  }
}

/// Favori kalbi.
class HeartButton extends StatelessWidget {
  final PagePalette pal;
  final bool on;
  final String label;
  final VoidCallback onTap;

  const HeartButton({super.key, required this.pal, required this.on, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: '$label favori',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 36,
          child: Icon(
            on ? Icons.favorite : Icons.favorite_border,
            size: 21,
            color: on ? const Color(0xFFC0392B) : pal.ink2,
          ),
        ),
      ),
    );
  }
}

/// Koyu yeşil zeminde simge + yazılı düğmeler şeridi (Dinle, Kopyala, Paylaş ...).
class ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ActionItem(this.icon, this.label, this.onTap);
}

class ActionStrip extends StatelessWidget {
  final List<ActionItem> items;
  final BorderRadius? radius;
  final BoxBorder? border;

  const ActionStrip({super.key, required this.items, this.radius, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: RC.darkPanel,
        borderRadius: radius,
        border: border ?? Border(top: BorderSide(color: RC.gold(0.6), width: 1.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: true,
                label: items[i].label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: items[i].onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0x2E000000),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: RC.gold(0.45)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(items[i].icon, size: 20, color: RC.goldIcon),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            items[i].label,
                            style: const TextStyle(color: RC.cream, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Günün ayeti / duası kartı: koyu başlık, kâğıt gövde (oklarla gezinme), eylem şeridi.
class DailyCard extends StatelessWidget {
  final PagePalette pal;
  final String title;
  final String subtitle;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final List<Widget> body;
  final List<ActionItem> actions;

  const DailyCard({
    super.key,
    required this.pal,
    required this.title,
    required this.subtitle,
    required this.favorite,
    required this.onFavorite,
    required this.onPrev,
    required this.onNext,
    required this.body,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    Widget navButton(IconData icon, String label, VoidCallback onTap) => Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xB3FFFAEB),
                border: Border.all(color: const Color(0x80966E1E)),
              ),
              child: Icon(icon, size: 16, color: RC.verseInk2),
            ),
          ),
        );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.gold(0.75), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x38281905), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              gradient: RC.darkPanel,
              border: Border(bottom: BorderSide(color: RC.gold(0.6), width: 1.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(color: RC.goldText, fontSize: 21, fontWeight: FontWeight.w700)),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xE6F3ECD9), fontSize: 12.5)),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  toggled: favorite,
                  label: 'Favori',
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Column(
                      children: [
                        Icon(favorite ? Icons.favorite : Icons.favorite_border, size: 24,
                            color: favorite ? RC.goldIcon : RC.goldText),
                        const SizedBox(height: 2),
                        const Text('Favori',
                            style: TextStyle(color: RC.goldText, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: pal.verseCard,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(38, 14, 38, 12),
                  child: DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: RC.verseInk),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(child: navButton(Icons.chevron_left, 'Önceki', onPrev)),
                ),
                Positioned(
                  right: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(child: navButton(Icons.chevron_right, 'Sonraki', onNext)),
                ),
              ],
            ),
          ),
          ActionStrip(items: actions),
        ],
      ),
    );
  }
}

/// Okuma sayfasının üst kartı: soluk cami fotoğrafı, ortada başlıklar, altta araç düğmeleri.
class ReadingHero extends StatelessWidget {
  final List<Widget> lines;
  final List<Widget> tools;

  const ReadingHero({super.key, required this.lines, required this.tools});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF062A1C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.gold(0.75), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.55,
              child: Image.asset(
                'assets/images/okuma_kapak.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.1),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33062A1C), Color(0xE6062A1C)],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                child: DefaultTextStyle.merge(
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: RC.cream),
                  child: Column(children: lines),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: RC.gold(0.45)))),
                child: Row(
                  children: [
                    for (var i = 0; i < tools.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(child: tools[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ReadingHero içindeki araç düğmesi (Arapça, Meal, A−, A+ ...).
class HeroTool extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool active; // kapalıyken soluk görünür
  final String? semanticLabel;
  final IconData? icon;

  const HeroTool({
    super.key,
    required this.label,
    required this.onTap,
    this.active = true,
    this.semanticLabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: active ? 1 : 0.5,
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x40000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: RC.gold(0.45)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 14, color: RC.cream), const SizedBox(width: 4)],
                  Text(label, style: const TextStyle(color: RC.cream, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Koyu yeşil, altın çerçeveli geniş düğme (Önceki / Sonraki).
class DarkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;

  const DarkButton({super.key, required this.label, required this.onTap, this.height = 44, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.35 : 1,
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              gradient: RC.darkPanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RC.gold(0.6), width: 1.5),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: TextStyle(color: RC.cream, fontSize: fontSize, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Önceki / Sonraki düğme çifti.
class PrevNextRow extends StatelessWidget {
  final String prevLabel;
  final String nextLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final double height;
  final double fontSize;

  const PrevNextRow({
    super.key,
    required this.prevLabel,
    required this.nextLabel,
    required this.onPrev,
    required this.onNext,
    this.height = 44,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: DarkButton(label: prevLabel, onTap: onPrev, height: height, fontSize: fontSize)),
        const SizedBox(width: 8),
        Expanded(child: DarkButton(label: nextLabel, onTap: onNext, height: height, fontSize: fontSize)),
      ],
    );
  }
}

/// Liste satırları arasına ince çizgi koyar.
List<Widget> withDividers(List<Widget> rows, Color color) {
  final out = <Widget>[];
  for (var i = 0; i < rows.length; i++) {
    if (i > 0) out.add(Container(height: 1, color: color));
    out.add(rows[i]);
  }
  return out;
}
