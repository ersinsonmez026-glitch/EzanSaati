import 'package:flutter/material.dart';

import '../services/app_prefs.dart';
import '../services/ezan_notifications.dart';
import '../services/location_store.dart';
import '../services/quran_audio.dart';
import '../widgets/group_card.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'about_screen.dart';
import 'city_picker_screen.dart';
import 'notifications_screen.dart';

/// Ayarlar: konum, ana ekran görünümü, Kur'an sesi (kârî), bildirimler, hesaplama yöntemi, hakkında ve gizlilik.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  final _location = LocationStore.instance;
  bool _busy = false;

  /// Açık bölüm (aynı anda bir tane); hiçbiri açık değilse null.
  String? _section;

  void _toggle(String s) => setState(() => _section = _section == s ? null : s);

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

  void _open(Widget page) => Navigator.of(context).push(AppRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final loc = _location.current;
    const gap = SizedBox(height: 10);
    return PageShell(
      title: 'Ayarlar',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        GroupCard(
          pal: _pal,
          art: 'cami_bulucu',
          title: 'Konum',
          expanded: _section == 'Konum',
          onToggle: () => _toggle('Konum'),
          summary: loc?.name ?? 'Seçilmedi',
          children: [
            GroupItem(
              pal: _pal,
              art: 'konum',
              title: 'Şehir',
              subtitle: loc == null ? 'Seçilmedi' : '${loc.name}${loc.fromGps ? ' (GPS)' : ''}',
              onTap: () => _open(const CityPickerScreen()),
            ),
            GroupItem(
              pal: _pal,
              art: 'kible_bulucu',
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
          art: 'ayarlar',
          title: 'Görünüm',
          expanded: _section == 'Görünüm',
          onToggle: () => _toggle('Görünüm'),
          summary: '${AppPrefs.instance.tileStyle.label} · ${AppPrefs.instance.dayMode.label}',
          children: [
            GroupItem(
              pal: _pal,
              art: 'gorunum',
              title: 'Ana ekran tuşları',
              subtitle: 'Görselli, yeşil ya da krem tuşlar',
              below: ChoiceRow<TileStyle>(
                pal: _pal,
                options: [
                  for (final t in const [TileStyle.resimli, TileStyle.yesil, TileStyle.krem]) (t, t.label)
                ],
                value: AppPrefs.instance.tileStyle,
                onChanged: (v) async {
                  await AppPrefs.instance.setTileStyle(v);
                  if (mounted) setState(() {});
                },
              ),
            ),
            GroupItem(
              pal: _pal,
              art: 'imsak',
              title: 'Gündüz / gece görünümü',
              subtitle: 'Otomatik: imsakten akşama krem, akşamdan sonra yeşil görünüm ve gece manzarası',
              below: ChoiceRow<DayMode>(
                pal: _pal,
                options: [for (final m in DayMode.values) (m, m.label)],
                value: AppPrefs.instance.dayMode,
                onChanged: (v) async {
                  await AppPrefs.instance.setDayMode(v);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
        ),
        gap,
        GroupCard(
          pal: _pal,
          art: 'kuran',
          title: "Kur'an Sesi",
          expanded: _section == "Kur'an Sesi",
          onToggle: () => _toggle("Kur'an Sesi"),
          summary: currentReciter().name,
          children: [
            GroupItem(
              pal: _pal,
              art: 'ses',
              title: 'Kârî',
              subtitle: 'Sûreler, cüzler ve dualar bu kârînin sesiyle okunur',
              below: ChoiceRow<String>(
                pal: _pal,
                options: [for (final r in kQuranReciters) (r.id, r.name)],
                value: currentReciter().id,
                onChanged: (v) async {
                  await AppPrefs.instance.setReciter(v);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
        ),
        gap,
        GroupCard(
          pal: _pal,
          art: 'fener',
          title: 'Bildirimler',
          expanded: _section == 'Bildirimler',
          onToggle: () => _toggle('Bildirimler'),
          summary: EzanNotifications.instance.settings.enabled ? 'Açık' : 'Kapalı',
          children: [
            GroupItem(
              pal: _pal,
              art: 'ses',
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
          art: 'namaz_vakitleri',
          title: 'Hesaplama',
          expanded: _section == 'Hesaplama',
          onToggle: () => _toggle('Hesaplama'),
          summary: 'Diyanet',
          children: [
            GroupItem(
              pal: _pal,
              art: 'takvim',
              title: 'Hesaplama yöntemi',
              subtitle: 'Diyanet İşleri Başkanlığı (Türkiye). Vakitler internetsiz hesaplanır.',
            ),
          ],
        ),
        gap,
        GroupCard(
          pal: _pal,
          art: 'dini_mesajlar',
          title: 'Hakkında',
          expanded: _section == 'Hakkında',
          onToggle: () => _toggle('Hakkında'),
          summary: 'Sürüm ${AboutScreen.version}',
          children: [
            GroupItem(
              pal: _pal,
              art: 'hadisler',
              title: 'Gizlilik ve kaynaklar',
              subtitle: 'Verileriniz nerede tutulur, içerikler nereden alınır',
              onTap: () => _open(const AboutScreen()),
            ),
            GroupItem(
              pal: _pal,
              art: 'cami',
              title: 'Ezan Saati',
              subtitle: 'Sürüm ${AboutScreen.version}',
            ),
          ],
        ),
      ],
    );
  }
}
