import 'package:flutter/material.dart';

import 'gold_icon.dart';
import 'reading_ui.dart';

/// Koyu başlıklı, kâğıt zeminli ayar/bilgi grubu (onizleme/02 "Bildirim Ayarları" kartı).
class GroupCard extends StatelessWidget {
  final PagePalette pal;
  final IconData? icon;
  final String? art;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  /// Verilirse kart açılır-kapanır olur: başlığa dokununca [onToggle] çağrılır, kapalıyken yalnız başlık
  /// ve [summary] (ör. seçili şehir) görünür.
  final bool? expanded;
  final VoidCallback? onToggle;
  final String? summary;

  const GroupCard({
    super.key,
    required this.pal,
    this.icon,
    this.art,
    required this.title,
    required this.children,
    this.trailing,
    this.expanded,
    this.onToggle,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final foldable = expanded != null;
    final open = expanded ?? true;
    Widget header = Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: foldable ? 10 : 6),
      decoration: BoxDecoration(
        gradient: RC.darkPanel,
        border: open ? Border(bottom: BorderSide(color: RC.gold(0.6), width: 1.5)) : null,
      ),
      child: Row(
        children: [
          art != null ? ArtIcon(art!, size: 26) : GoldIcon(icon!, size: 20),
          const SizedBox(width: 10),
          Expanded(
            flex: foldable ? 0 : 1,
            child: GoldText(title, maxLines: 1, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w600)),
          ),
          if (trailing != null) trailing!,
          if (foldable) const SizedBox(width: 8),
          if (foldable)
            Expanded(
              child: Text(open ? '' : summary ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: RC.creamSoft, fontSize: 13)),
            ),
          if (foldable) ...[
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more, color: RC.goldIcon, size: 24),
            ),
          ],
        ],
      ),
    );
    if (foldable) {
      header = Semantics(
        button: true,
        expanded: open,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onToggle, child: header),
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: pal.paperGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.line, width: pal.night ? 1 : 1.4),
        boxShadow: const [BoxShadow(color: Color(0x1F3C280A), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: open
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: withDividers(children, pal.line))
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Grup içindeki satır: solda simge kutusu, başlık ve açıklama, sağda anahtar/ok/değer.
class GroupItem extends StatelessWidget {
  final PagePalette pal;
  final IconData? icon;
  final String? art; // [icon] yerine hazır simge görseli (assets/images/ikon)
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? below; // satırın altına tam genişlikte eklenen içerik (ör. seçim düğmeleri)

  const GroupItem({
    super.key,
    required this.pal,
    this.icon,
    this.art,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.below,
  }) : assert(icon != null || art != null);

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: pal.pill, borderRadius: BorderRadius.circular(10)),
          child: Center(child: art != null ? ArtIcon(art!, size: 30) : GoldIcon(icon!, size: 18, light: !pal.night)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: pal.ink, fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.2)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(color: pal.ink2, fontSize: 12.5, height: 1.25)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (trailing == null && onTap != null) Icon(Icons.chevron_right, color: pal.gold),
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: below == null
              ? row
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [row, const SizedBox(height: 6), below!]),
        ),
      ),
    );
  }
}

/// Önizlemedeki yuvarlak anahtar: açıkken yeşil, kapalıyken gri.
class GoldSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  const GoldSwitch({super.key, required this.value, required this.onChanged, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 50,
          height: 28,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? const Color(0xFF16774D) : const Color(0xFFA9A08C),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yan yana seçim düğmeleri (seçili olan bronz).
class ChoiceRow<T> extends StatelessWidget {
  final PagePalette pal;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  const ChoiceRow({super.key, required this.pal, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: PillButton(
              pal: pal,
              selected: options[i].$1 == value,
              onTap: () => onChanged(options[i].$1),
              child: Text(
                options[i].$2,
                style: TextStyle(
                  color: options[i].$1 == value ? RC.bronzeText : pal.ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
