import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'dhikr_screen.dart';

/// Tek bir duanın okunduğu sayfa: Arapça, okunuşu, anlamı ve kaynağı.
class PrayerReadScreen extends StatefulWidget {
  final List<Dua> duas;
  final int index;

  const PrayerReadScreen({super.key, required this.duas, required this.index});

  @override
  State<PrayerReadScreen> createState() => _PrayerReadScreenState();
}

class _PrayerReadScreenState extends State<PrayerReadScreen> {
  static const _fsKey = 'dua_fs';

  final _pal = PagePalette.current();
  final _scroll = ScrollController();
  late int _index = widget.index;
  ReadingPrefs? _prefs;
  bool _showReading = true;
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
    final d = widget.duas[_index];
    final fav = _prefs?.favorites(kDuaFavKey).contains(d.title) ?? false;
    final last = widget.duas.length - 1;

    return PageShell(
      title: 'Dualar',
      background: _pal.background,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        ReadingHero(
          lines: [
            Opacity(
              opacity: 0.85,
              child: Text(kDuaGroupNames[d.group] ?? '', style: const TextStyle(fontSize: 12)),
            ),
            Text(d.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            Opacity(opacity: 0.85, child: Text(d.source, style: const TextStyle(fontSize: 12))),
          ],
          tools: [
            HeroTool(
              label: 'Okunuş',
              active: _showReading,
              onTap: () => setState(() => _showReading = !_showReading),
            ),
            HeroTool(
              label: 'Favori',
              icon: fav ? Icons.favorite : Icons.favorite_border,
              active: fav,
              onTap: () {
                final on = _prefs?.toggleFavorite(kDuaFavKey, d.title) ?? false;
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
        _article(d),
        const SizedBox(height: 10),
        ActionStrip(
          radius: BorderRadius.circular(14),
          border: Border.all(color: RC.gold(0.6), width: 1.5),
          items: [
            ActionItem(Icons.volume_up, 'Dinle', () => showNote(context, 'Sesli okuma sonraki güncellemede eklenecek')),
            ActionItem(Icons.copy_outlined, 'Kopyala', () => copyToClipboard(context, d.shareText)),
            ActionItem(Icons.ios_share, 'Paylaş', () => shareText(context, d.shareText)),
            ActionItem(
              Icons.touch_app_outlined,
              'Zikret',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DhikrScreen())),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PrevNextRow(
          prevLabel: '‹ Önceki dua',
          nextLabel: 'Sonraki dua ›',
          onPrev: _index > 0 ? () => _go(_index - 1) : null,
          onNext: _index < last ? () => _go(_index + 1) : null,
        ),
      ],
    );
  }

  Widget _article(Dua d) {
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(t,
              style: TextStyle(color: _pal.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        );
    return PaperBox(
      pal: _pal,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              d.arabic,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: kQuranFont, fontSize: 24 * _fs, height: 2.3, color: _pal.ink),
            ),
          ),
          if (_showReading) ...[
            label('OKUNUŞU'),
            const SizedBox(height: 6),
            Text(d.reading,
                style: TextStyle(fontSize: 14 * _fs, height: 1.6, fontStyle: FontStyle.italic, color: _pal.ink2)),
          ],
          label('ANLAMI'),
          const SizedBox(height: 4),
          Text(d.meaning, style: TextStyle(fontSize: 15 * _fs, height: 1.6, color: _pal.ink)),
          const SizedBox(height: 10),
          DashedLine(color: _pal.line),
          const SizedBox(height: 8),
          Text(
            d.fromMeal
                ? 'Anlam, ayetin mealidir (Ruvvâd Tercüme Merkezi, QuranEnc.com). Kaynak: ${d.source}'
                : 'Kaynak: ${d.source}',
            style: TextStyle(fontSize: 12, color: _pal.ink2),
          ),
        ],
      ),
    );
  }
}
