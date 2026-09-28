import 'package:flutter/material.dart';

import '../services/app_prefs.dart';
import '../services/ezan_notifications.dart';
import '../services/location_store.dart';
import '../widgets/group_card.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'about_screen.dart';
import 'city_picker_screen.dart';
import 'notifications_screen.dart';

/// Ayarlar: konum, ana ekran görünümü, hesaplama yöntemi, hakkında ve gizlilik.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _pal = PagePalette.current();
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
    setState(() => _busy = true);
    final error = await _location.updateFromGps();
    if (!mounted) return;
    setState(() => _busy = false);
    showNote(context, error ?? 'Konum güncellendi: ${_location.current?.name ?? ''}');
  }

  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final loc = _location.current;
    const gap = SizedBox(height: 10);
    return PageShell(
      title: 'Ayarlar',
      background: _pal.background,
      showSettings: false,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        GroupCard(
          pal: _pal,
          icon: Icons.place_outlined,
          title: 'Konum',
          children: [
            GroupItem(
              pal: _pal,
              icon: Icons.location_city,
              title: 'Şehir',
              subtitle: loc == null ? 'Seçilmedi' : '${loc.name}${loc.fromGps ? ' (GPS)' : ''}',
              onTap: () => _open(const CityPickerScreen()),
            ),
            GroupItem(
              pal: _pal,
              icon: Icons.my_location,
              title: 'Konumumu güncelle',
              subtitle: 'GPS ile bulunduğunuz yeri yeniden bulur',
              trailing: _busy
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _pal.gold))
                  : null,
              onTap: _busy ? null : _useGps,
            ),
          ],
        ),
        gap,
        GroupCard(
          pal: _pal,
          icon: Icons.grid_view,
          title: 'Görünüm',
          children: [
            GroupItem(
              pal: _pal,
              icon: Icons.dashboard_outlined,
              title: 'Ana ekran tuşları',
              subtitle: 'Resimli, krem ya da yeşil tuşlar',
              below: ChoiceRow<TileStyle>(
                pal: _pal,
                options: [for (final t in TileStyle.values) (t, t.label)],
                value: AppPrefs.instance.tileStyle,
                onChanged: (v) async {
                  await AppPrefs.instance.setTileStyle(v);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
        ),
        gap,
        GroupCard(
          pal: _pal,
          icon: Icons.notifications_active,
          title: 'Bildirimler',
          children: [
            GroupItem(
              pal: _pal,
              icon: Icons.notifications_none,
              title: 'Ezan bildirimleri',
              subtitle: EzanNotifications.instance.settings.enabled
                  ? '${EzanNotifications.instance.settings.activeCount} vakitte açık'
                  : 'Kapalı · açmak için dokunun',
              onTap: () => _open(const NotificationsScreen()),
            ),
          ],
        ),
        gap,
        GroupCard(
          pal: _pal,
          icon: Icons.calculate_outlined,
          title: 'Hesaplama',
          children: [
            GroupItem(
              pal: _pal,
              icon: Icons.schedule,
              title: 'Hesaplama yöntemi',
              subtitle: 'Diyanet İşleri Başkanlığı (Türkiye). Vakitler internetsiz hesaplanır.',
            ),
          ],
        ),
        gap,
        GroupCard(
          pal: _pal,
          icon: Icons.info_outline,
          title: 'Hakkında',
          children: [
            GroupItem(
              pal: _pal,
              icon: Icons.privacy_tip_outlined,
              title: 'Gizlilik ve kaynaklar',
              subtitle: 'Verileriniz nerede tutulur, içerikler nereden alınır',
              onTap: () => _open(const AboutScreen()),
            ),
            GroupItem(
              pal: _pal,
              icon: Icons.verified_outlined,
              title: 'Ezan Saati',
              subtitle: 'Sürüm ${AboutScreen.version}',
            ),
          ],
        ),
      ],
    );
  }
}
