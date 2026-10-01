import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../services/hadith_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Tek hadis: metin ve kaynağı (Diyanet, Hadislerle İslâm).
class HadithReadScreen extends StatefulWidget {
  final List<Hadith> items;
  final int index;

  const HadithReadScreen({super.key, required this.items, required this.index});

  @override
  State<HadithReadScreen> createState() => _HadithReadScreenState();
}

class _HadithReadScreenState extends State<HadithReadScreen> {
  static const _fsKey = 'hadis_fs';

  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  final _scroll = ScrollController();
  late int _index = widget.index;
  ReadingPrefs? _prefs;
  double _fs = 1;

  @override
  void initState() {
    super.initState();
    ReadingPrefs.get().then((p) {
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _fs = p.fontScale(_fsKey);
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _index = i);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.items[_index];
    final fav = _prefs?.favorites(kHadithFavKey).contains(h.id) ?? false;
    final last = widget.items.length - 1;
    return PageShell(
      title: 'Hadisler',
      background: _pal.background,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        ReadingHero(
          lines: [
            Opacity(opacity: 0.85, child: Text('${_index + 1}. hadis', style: const TextStyle(fontSize: 12))),
            Opacity(opacity: 0.85, child: Text(h.attribution, style: const TextStyle(fontSize: 12))),
          ],
          tools: [
            HeroTool(
              label: 'Favori',
              icon: fav ? Icons.favorite : Icons.favorite_border,
              active: fav,
              onTap: () {
                final on = _prefs?.toggleFavorite(kHadithFavKey, h.id) ?? false;
                setState(() {});
                showNote(context, on ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı');
              },
            ),
            HeroTool(
              label: 'A−',
              semanticLabel: 'Yazıyı küçült',
              onTap: () => setState(() => _fs = _prefs?.changeFontScale(_fsKey, -0.1) ?? _fs),
            ),
            HeroTool(
              label: 'A+',
              semanticLabel: 'Yazıyı büyüt',
              onTap: () => setState(() => _fs = _prefs?.changeFontScale(_fsKey, 0.1) ?? _fs),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _article(h),
        const SizedBox(height: 10),
        ActionStrip(
          radius: BorderRadius.circular(14),
          border: Border.all(color: RC.gold(0.6), width: 1.5),
          items: [
            ActionItem(Icons.copy_outlined, 'Kopyala', () => copyToClipboard(context, h.shareText)),
            ActionItem(Icons.ios_share, 'Paylaş', () => shareText(context, h.shareText)),
          ],
        ),
        const SizedBox(height: 10),
        PrevNextRow(
          prevLabel: '‹ Önceki hadis',
          nextLabel: 'Sonraki hadis ›',
          onPrev: _index > 0 ? () => _go(_index - 1) : null,
          onNext: _index < last ? () => _go(_index + 1) : null,
        ),
        const SizedBox(height: 10),
        SourceNote(pal: _pal, text: 'Kaynak: Diyanet İşleri Başkanlığı, ${h.book} (${h.url})'),
      ],
    );
  }

  Widget _article(Hadith h) {
    return PaperBox(
      pal: _pal,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“${h.text}”', style: TextStyle(fontSize: 17 * _fs, height: 1.6, color: _pal.ink, fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in [h.attribution, h.book])
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _pal.pill,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: _pal.line),
                  ),
                  child: Text(t, style: TextStyle(color: _pal.ink, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
