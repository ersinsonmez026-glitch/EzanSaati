import 'package:flutter/material.dart';

import '../data/cities.dart';
import '../services/location_store.dart';
import '../widgets/gold_icon.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// 81 il arasından arama yaparak ya da GPS ile şehir seçme ekranı.
class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key});

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  final _pal = PagePalette.current();
  String _query = '';
  bool _busy = false;

  Future<void> _useGps() async {
    setState(() => _busy = true);
    final error = await LocationStore.instance.updateFromGps();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      showNote(context, error);
    }
  }

  Future<void> _pick(City c) async {
    final navigator = Navigator.of(context);
    await LocationStore.instance.setCity(c);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final q = trSearchKey(_query.trim());
    final cities = q.isEmpty ? turkishCities : turkishCities.where((c) => trSearchKey(c.name).contains(q)).toList();
    final currentName = LocationStore.instance.current?.name;

    return PageShell(
      title: 'Şehir Seç',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        SearchBox(pal: _pal, hint: 'Şehir ara...', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: 'Konumumu otomatik bul',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _busy ? null : _useGps,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: RC.darkPanel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RC.gold(0.7), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, border: Border.all(color: RC.goldBorder, width: 1.5)),
                    child: Center(
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: RC.goldText))
                          : const GoldIcon(Icons.my_location, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Konumumu otomatik bul',
                            style: TextStyle(color: RC.cream, fontSize: 15, fontWeight: FontWeight.w700)),
                        Text("Telefonun GPS'i ile en doğru vakitler",
                            style: TextStyle(color: RC.creamSoft, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  const Text('›', style: TextStyle(color: RC.goldBorder, fontSize: 22)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (cities.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Şehir bulunamadı', textAlign: TextAlign.center, style: TextStyle(color: _pal.ink2)),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: _pal.paperGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _pal.line),
            ),
            child: Column(
              children: withDividers([
                for (final c in cities) _row(c, c.name == currentName),
              ], _pal.line),
            ),
          ),
      ],
    );
  }

  Widget _row(City c, bool selected) {
    return Semantics(
      button: true,
      selected: selected,
      label: c.name,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _pick(c),
        child: Container(
          color: selected ? RC.gold(0.14) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              OctaBadge(number: c.plate, size: 32, color: _pal.gold, textColor: _pal.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  c.name,
                  style: TextStyle(
                    color: _pal.ink,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected) GoldIcon(Icons.check_circle_rounded, size: 20, light: !_pal.night),
            ],
          ),
        ),
      ),
    );
  }
}
