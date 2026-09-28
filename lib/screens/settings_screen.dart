import 'package:flutter/material.dart';

import '../services/app_prefs.dart';
import '../services/location_store.dart';
import '../theme.dart';
import 'city_picker_screen.dart';
import '../widgets/gold_icon.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _location = LocationStore.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _location.addListener(_onChange);
  }

  @override
  void dispose() {
    _location.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _useGps() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final error = await _location.updateFromGps();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Konum güncellendi: ${_location.current?.name ?? ''}'),
    ));
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          title,
          style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final loc = _location.current;
    const titleStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
    const subStyle = TextStyle(color: Colors.white54);

    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      appBar: goldAppBar('Ayarlar'),
      body: ListView(
        children: [
          _section('KONUM'),
          ListTile(
            leading: const GoldIcon(Icons.location_city),
            title: const Text('Şehir', style: titleStyle),
            subtitle: Text(
              loc == null ? 'Seçilmedi' : '${loc.name}${loc.fromGps ? ' (GPS)' : ''}',
              style: subStyle,
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CityPickerScreen()),
            ),
          ),
          ListTile(
            leading: _busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                  )
                : const GoldIcon(Icons.my_location),
            title: const Text('Konumumu güncelle', style: titleStyle),
            subtitle: const Text('GPS ile bulunduğunuz yeri yeniden bulur', style: subStyle),
            onTap: _busy ? null : _useGps,
          ),
          _section('GÖRÜNÜM'),
          ListTile(
            leading: const GoldIcon(Icons.grid_view),
            title: const Text('Ana ekran tuşları', style: titleStyle),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<TileStyle>(
                segments: [
                  for (final t in TileStyle.values) ButtonSegment(value: t, label: Text(t.label)),
                ],
                selected: {AppPrefs.instance.tileStyle},
                showSelectedIcon: false,
                onSelectionChanged: (v) async {
                  await AppPrefs.instance.setTileStyle(v.first);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
          _section('HESAPLAMA'),
          const ListTile(
            leading: GoldIcon(Icons.calculate),
            title: Text('Hesaplama yöntemi', style: titleStyle),
            subtitle: Text('Diyanet İşleri Başkanlığı (Türkiye)', style: subStyle),
          ),
          _section('BİLDİRİMLER'),
          const ListTile(
            leading: GoldIcon(Icons.notifications_active),
            title: Text('Ezan bildirimleri', style: titleStyle),
            subtitle: Text('Bir sonraki güncellemede eklenecek', style: subStyle),
          ),
          _section('HAKKINDA'),
          const ListTile(
            leading: GoldIcon(Icons.info_outline),
            title: Text('Ezan Saati', style: titleStyle),
            subtitle: Text('Sürüm 1.0.0', style: subStyle),
          ),
        ],
      ),
    );
  }
}
