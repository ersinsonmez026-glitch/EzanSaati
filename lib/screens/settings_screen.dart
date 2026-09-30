import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_prefs.dart';
import '../services/ezan_notifications.dart';
import '../services/location_store.dart';
import '../services/mosque_mode.dart';
import '../services/premium.dart';
import '../services/quran_audio.dart';
import '../widgets/group_card.dart';
import '../widgets/page_shell.dart';
import '../widgets/premium_ui.dart';
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
        const PremiumBanner(),
        gap,
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
            for (final r in kQuranReciters)
              GroupItem(
                pal: _pal,
                art: 'ses',
                title: r.name,
                subtitle: [kReciterInfo[r.id] ?? '', if (r == kQuranReciters.first) 'varsayılan'].where((x) => x.isNotEmpty).join(' · '),
                trailing: Icon(
                  currentReciter().id == r.id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _pal.gold,
                  size: 22,
                ),
                onTap: () async {
                  await AppPrefs.instance.setReciter(r.id);
                  if (mounted) setState(() {});
                },
              ),
          ],
        ),
        gap,
        ListenableBuilder(
          listenable: Listenable.merge([MosqueMode.instance, Premium.instance]),
          builder: (context, _) => _mosqueCard(),
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

  // ---------------------------------------------------------------- cami modu

  /// Cami modu açılırken tam vakit alarm izni de istenir (yoksa Android sessizliği geç kaldırabilir).
  Future<void> _setMosque(bool on) async {
    await MosqueMode.instance.update(on: on);
    if (on) await EzanNotifications.instance.ensureExactAlarms();
  }

  Widget _mosqueCard() {
    final m = MosqueMode.instance;
    final premium = Premium.instance.active;
    final open = _section == 'Cami Modu';
    if (open && premium && m.silent && m.dnd == null) unawaited(m.refreshDnd());
    return GroupCard(
      pal: _pal,
      art: 'cami',
      title: 'Cami Modu',
      expanded: open,
      onToggle: () => _toggle('Cami Modu'),
      summary: !premium ? 'Premium' : (m.on ? 'Açık · ${m.silent ? 'Sessiz' : 'Titreşim'}' : 'Kapalı'),
      children: !premium
          ? [
              GroupItem(
                pal: _pal,
                art: 'cami',
                title: 'Vakitte telefon sessize geçsin',
                subtitle: 'Seçtiğiniz vakitlerde telefon kendiliğinden sessize ya da titreşime geçer, '
                    'süre bitince eski hâline döner.',
                trailing: const PremiumChip(lock: true),
                onTap: () => openPremium(context),
              ),
            ]
          : [
              GroupItem(
                pal: _pal,
                art: 'cami',
                title: 'Cami modu',
                subtitle: m.on
                    ? 'Seçili vakitlerde ${m.delay == 0 ? 'ezanla birlikte' : 'ezandan ${m.delay} dk sonra'} '
                        '${m.minutes} dakika ${m.silent ? 'sessiz' : 'titreşimde'}'
                    : 'Kapalı · açmak için dokunun',
                trailing: Switch(
                  value: m.on,
                  activeThumbColor: RC.bronzeText,
                  activeTrackColor: const Color(0xFF6E5114),
                  onChanged: _setMosque,
                ),
                onTap: () => _setMosque(!m.on),
              ),
              GroupItem(
                pal: _pal,
                art: 'ses',
                title: 'Telefon',
                subtitle: 'Titreşimde aramalar sessiz gelir, telefon titrer',
                below: ChoiceRow<bool>(
                  pal: _pal,
                  options: const [(false, 'Titreşim'), (true, 'Sessiz')],
                  value: m.silent,
                  onChanged: (v) async {
                    await m.update(silent: v);
                    if (v) await m.refreshDnd();
                  },
                ),
              ),
              if (m.silent && m.dnd == false)
                GroupItem(
                  pal: _pal,
                  icon: Icons.do_not_disturb_on_outlined,
                  title: 'İzin gerekli',
                  subtitle: 'Tam sessiz için telefonun "Rahatsız Etmeyin erişimi" ayarında Ezan Saati\'ne izin verin. '
                      'İzin yokken telefon titreşime alınır.',
                  trailing: Text('İzin ver', style: TextStyle(color: _pal.gold, fontWeight: FontWeight.w700)),
                  onTap: m.openDndSettings, // dönünce (uygulama öne gelince) izin yeniden okunur
                ),
              GroupItem(
                pal: _pal,
                art: 'fener',
                title: 'Ne zaman başlasın?',
                subtitle: 'Ezan vaktinden kaç dakika sonra',
                below: ChoiceRow<int>(
                  pal: _pal,
                  options: [for (final d in MosqueMode.delays) (d, d == 0 ? 'Ezanla' : '$d dk')],
                  value: m.delay,
                  onChanged: (v) => m.update(delay: v),
                ),
              ),
              GroupItem(
                pal: _pal,
                art: 'takvim',
                title: 'Ne kadar sürsün?',
                subtitle: 'Süre bitince telefon eski hâline döner',
                below: ChoiceRow<int>(
                  pal: _pal,
                  options: [for (final d in MosqueMode.durations) (d, '$d dk')],
                  value: m.minutes,
                  onChanged: (v) => m.update(minutes: v),
                ),
              ),
              GroupItem(
                pal: _pal,
                art: 'cami_bulucu',
                title: 'Cuma namazı',
                subtitle: 'Cuma günü öğle vaktindeki süre (hutbe dahil)',
                below: ChoiceRow<int>(
                  pal: _pal,
                  options: [for (final d in MosqueMode.fridayDurations) (d, '$d dk')],
                  value: m.friday,
                  onChanged: (v) => m.update(friday: v),
                ),
              ),
              GroupItem(
                pal: _pal,
                art: 'namaz_vakitleri',
                title: 'Vakitler',
                subtitle: 'Cami modunun çalışacağı vakitler',
                below: Row(children: [
                  for (var i = 0; i < 5; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: PillButton(
                        pal: _pal,
                        selected: m.prayers[i],
                        padding: EdgeInsets.zero,
                        onTap: () => m.update(toggle: i),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(MosqueMode.names[i], style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
    );
  }
}
