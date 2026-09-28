import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'baby_names_list_screen.dart';

/// Bebek İsimleri: iki ana kategori (Kur'an'da Geçen İsimler, İslami İsimler).
/// Veri: assets/data/bebek_isimleri.json
class BabyNamesScreen extends StatefulWidget {
  const BabyNamesScreen({super.key});

  @override
  State<BabyNamesScreen> createState() => _BabyNamesScreenState();
}

class _BabyNamesScreenState extends State<BabyNamesScreen> {
  final _pal = PagePalette.current();
  BabyNameData? _data;
  ReadingPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    Future.wait([BabyNameData.load(), ReadingPrefs.get()]).then((r) {
      if (!mounted) return;
      setState(() {
        _data = r[0] as BabyNameData;
        _prefs = r[1] as ReadingPrefs;
      });
    });
  }

  Future<void> _open(BabyNameCategory c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BabyNamesListScreen(category: c)));
    if (mounted) setState(() {}); // favori sayıları güncellensin
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return PageShell(
      title: 'Bebek İsimleri',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: d == null
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : [
              _categoryCard(d.quran, Icons.menu_book_outlined),
              const SizedBox(height: 10),
              _categoryCard(d.islamic, Icons.auto_awesome_outlined),
              const SizedBox(height: 12),
              SourceNote(
                pal: _pal,
                text: "Kur'an'da geçen isimlerin ayetleri uygulamadaki Kur'an metninden (Tanzil, Ruvvâd meali) "
                    'doğrulanmıştır. İsim anlamlarının kaynağı her ismin altında belirtilir.',
              ),
            ],
    );
  }

  Widget _categoryCard(BabyNameCategory c, IconData icon) {
    final girls = c.names.where((n) => n.girl).length;
    final boys = c.names.length - girls;
    final favs = _prefs?.favorites(kBabyNameFavKey).where((id) => id.startsWith('${c.key}:')).length ?? 0;
    return Semantics(
      button: true,
      label: c.title,
      child: GestureDetector(
        onTap: () => _open(c),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: RC.darkPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RC.gold(0.7), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x40281905), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x33000000),
                  border: Border.all(color: RC.goldBorder, width: 1.5),
                ),
                child: Icon(icon, color: RC.goldText, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        style: const TextStyle(color: RC.cream, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '$girls kız · $boys erkek ismi${favs > 0 ? ' · $favs favori' : ''}',
                      style: const TextStyle(color: RC.creamSoft, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: RC.goldBorder, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
