import 'package:flutter/material.dart';

import '../services/ezan_notifications.dart';
import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../widgets/gold_icon.dart';
import '../widgets/group_card.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Ezan Bildirimleri (onizleme/02-namaz-vakitleri.html "Bildirimler" görünümü).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _pal = PagePalette.current();
  final _n = EzanNotifications.instance;

  @override
  void initState() {
    super.initState();
    _n.addListener(_refresh);
  }

  @override
  void dispose() {
    _n.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  EzanSettings get _s => _n.settings;

  Future<void> _update(void Function(EzanSettings s) change) async {
    final s = EzanSettings.fromJson(_s.toJson());
    change(s);
    await _n.save(s);
  }

  Future<void> _setEnabled(bool on) async {
    if (on) {
      final granted = await _n.requestPermissions();
      if (!granted) {
        if (mounted) showNote(context, 'Bildirim izni verilmedi. Telefon ayarlarından izin verebilirsiniz.');
        return;
      }
    }
    await _update((s) => s.enabled = on);
    if (mounted) showNote(context, on ? 'Ezan bildirimleri açıldı' : 'Ezan bildirimleri kapatıldı');
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final loc = LocationStore.instance.current;
    final today = loc == null ? null : PrayerCalc.forDay(loc, DateTime.now());
    const gap = SizedBox(height: 10);
    final desc = !s.enabled
        ? 'Bildirimler kapalı. Açmak için aşağıdaki ilk düğmeyi kullanın.'
        : '${s.activeCount} vakitte bildirim açık.${s.before > 0 ? ' Ezandan ${s.before} dakika önce de hatırlatılır.' : ''}';

    return PageShell(
      title: 'Ezan Bildirimleri',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _hero(desc),
        gap,
        GroupCard(
          pal: _pal,
          icon: Icons.notifications_active,
          title: 'Bildirim Ayarları',
          children: [
            GroupItem(
              pal: _pal,
              icon: Icons.notifications_none,
              title: 'Ezan bildirimleri',
              subtitle: 'Tümünü tek düğmeyle aç veya kapat',
              trailing: GoldSwitch(value: s.enabled, label: 'Ezan bildirimleri', onChanged: _setEnabled),
            ),
            GroupItem(
              pal: _pal,
              enabled: s.enabled,
              icon: Icons.volume_up_outlined,
              title: 'Bildirim sesi',
              subtitle: 'Telefonun bildirim sesi ya da sessiz',
              below: ChoiceRow<bool>(
                pal: _pal,
                options: const [(true, 'Sesli'), (false, 'Sessiz')],
                value: s.sound,
                onChanged: (v) => _update((x) => x.sound = v),
              ),
            ),
            GroupItem(
              pal: _pal,
              enabled: s.enabled,
              icon: Icons.vibration,
              title: 'Titreşim',
              subtitle: 'Bildirim gelince telefon titresin',
              trailing: GoldSwitch(
                value: s.vibrate,
                label: 'Titreşim',
                onChanged: s.enabled ? (v) => _update((x) => x.vibrate = v) : null,
              ),
            ),
            GroupItem(
              pal: _pal,
              enabled: s.enabled,
              icon: Icons.alarm,
              title: 'Vakit öncesi hatırlatma',
              subtitle: 'Ezandan önce ayrıca haber ver (dakika)',
              below: ChoiceRow<int>(
                pal: _pal,
                options: [for (final m in EzanSettings.beforeOptions) (m, m == 0 ? 'Yok' : '$m')],
                value: s.before,
                onChanged: (v) => _update((x) => x.before = v),
              ),
            ),
          ],
        ),
        gap,
        GroupCard(
          pal: _pal,
          icon: Icons.schedule,
          title: 'Vakitler',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tümü', style: TextStyle(color: RC.cream, fontSize: 12.5)),
              const SizedBox(width: 6),
              GoldSwitch(
                value: s.vakit.every((v) => v),
                label: 'Tüm vakitler',
                onChanged: s.enabled ? (v) => _update((x) => x.vakit = List.filled(6, v)) : null,
              ),
            ],
          ),
          children: [
            for (var i = 0; i < 6; i++)
              GroupItem(
                pal: _pal,
                enabled: s.enabled,
                icon: _icons[i],
                title: PrayerCalc.names[i],
                subtitle: !s.enabled || !s.vakit[i]
                    ? 'Kapalı'
                    : (i == 1
                        ? 'Sadece uyarı'
                        : (s.before > 0 ? '${s.before} dk önce de hatırlatılır' : 'Vakitte bildirim')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (today != null)
                      Text(formatHm(today.slots[i].time),
                          style: TextStyle(
                            color: _pal.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )),
                    const SizedBox(width: 10),
                    GoldSwitch(
                      value: s.vakit[i],
                      label: PrayerCalc.names[i],
                      onChanged: s.enabled ? (v) => _update((x) => x.vakit[i] = v) : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
        gap,
        GroupCard(
          pal: _pal,
          icon: Icons.nightlight_round,
          title: 'Özel günler',
          children: [
            GroupItem(
              pal: _pal,
              enabled: s.enabled,
              icon: Icons.light_outlined,
              title: 'Kandil ve bayramlar',
              subtitle: 'Dinî günlerde sabah 09:00\'da hatırlat (Diyanet takvimi)',
              trailing: GoldSwitch(
                value: s.religiousDays,
                label: 'Kandil ve bayramlar',
                onChanged: s.enabled ? (v) => _update((x) => x.religiousDays = v) : null,
              ),
            ),
          ],
        ),
        if (s.enabled && !_n.exactAllowed) ...[
          gap,
          GroupCard(
            pal: _pal,
            icon: Icons.timer_outlined,
            title: 'Tam vaktinde bildirim',
            children: [
              GroupItem(
                pal: _pal,
                icon: Icons.warning_amber,
                title: '"Alarmlar ve hatırlatıcılar" izni kapalı',
                subtitle: 'Android bildirimleri birkaç dakika geciktirebilir. İzin vermek için dokunun.',
                onTap: () => _n.requestPermissions().then((_) => _n.reschedule()),
              ),
            ],
          ),
        ],
        gap,
        SourceNote(
          pal: _pal,
          text: 'Güneş vaktinde ezan okunmaz; açarsanız sadece "güneş doğuyor" uyarısı gelir. Bildirimler '
              '${EzanNotifications.horizonDays} gün ileriye kurulur ve uygulama her açıldığında yenilenir.',
        ),
      ],
    );
  }

  static const _icons = [
    Icons.wb_twilight,
    Icons.wb_sunny,
    Icons.mosque,
    Icons.wb_cloudy,
    Icons.wb_twilight,
    Icons.nightlight_round,
  ];

  Widget _hero(String desc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF062A1C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.gold(0.75), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x40281905), blurRadius: 14, offset: Offset(0, 4))],
        image: const DecorationImage(
          image: AssetImage('assets/images/vakit_kapak.jpg'),
          fit: BoxFit.cover,
          alignment: Alignment(0.6, 0.2),
          opacity: 0.35,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x40000000),
              border: Border.all(color: RC.goldBorder, width: 1.5),
            ),
            child: const Center(child: GoldIcon(Icons.notifications_active, size: 28)),
          ),
          const SizedBox(height: 6),
          const Text('Bildirimler',
              style: TextStyle(color: Colors.white, fontSize: 26, height: 1.1, fontWeight: FontWeight.w800)),
          const Text('Ezan vakitlerini kaçırmayın', style: TextStyle(color: RC.goldText, fontSize: 13.5)),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12, height: 1.45)),
        ],
      ),
    );
  }
}
