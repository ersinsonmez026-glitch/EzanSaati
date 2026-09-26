import 'package:flutter/material.dart';

import '../data/cities.dart';
import '../services/location_store.dart';
import '../theme.dart';

/// 81 il arasından arama yaparak şehir seçme ekranı.
class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key});

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  String _query = '';
  bool _busy = false;

  // Türkçe karakterleri sadeleştirir: "İzmir" araması "izmir" ile de bulunsun.
  static String _norm(String s) {
    const from = 'çğıöşüÇĞİÖŞÜI';
    const to = 'cgiosucgiosui';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch.toLowerCase());
    }
    return b.toString();
  }

  Future<void> _useGps() async {
    setState(() => _busy = true);
    final error = await LocationStore.instance.updateFromGps();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _norm(_query.trim());
    final cities = q.isEmpty
        ? turkishCities
        : turkishCities.where((c) => _norm(c.name).contains(q)).toList();
    final currentName = LocationStore.instance.current?.name;

    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      appBar: goldAppBar('Şehir Seç'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              cursorColor: AppColors.gold,
              decoration: InputDecoration(
                hintText: 'Şehir ara...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                filled: true,
                fillColor: AppColors.green,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          ListTile(
            leading: _busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                  )
                : const Icon(Icons.my_location, color: AppColors.mint),
            title: const Text(
              'Konumumu otomatik bul',
              style: TextStyle(color: AppColors.mint, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Telefonun GPS\'i ile en doğru vakitler',
              style: TextStyle(color: Colors.white54),
            ),
            onTap: _busy ? null : _useGps,
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: cities.length,
              itemBuilder: (context, i) {
                final c = cities[i];
                final selected = c.name == currentName;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: selected ? AppColors.gold : AppColors.green,
                    child: Text(
                      _two(c.plate),
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.black : AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    c.name,
                    style: TextStyle(
                      color: selected ? AppColors.gold : Colors.white,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: selected ? const Icon(Icons.check, color: AppColors.gold) : null,
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await LocationStore.instance.setCity(c);
                    navigator.pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
