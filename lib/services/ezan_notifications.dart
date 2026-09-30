import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'content_store.dart';
import 'hatim_plan.dart';
import 'location_store.dart';
import 'quran_audio.dart';
import 'prayer_calc.dart';
import 'takvim.dart';

/// Ezan bildirimi ayarları (Namaz Vakitleri > Bildirimler).
class EzanSettings {
  bool enabled;
  bool sound; // false: sessiz (yalnız görünür bildirim)
  String ezanVoice; // hangi ezan kaydı: ezanVoiceOptions anahtarlarından biri
  String ezanSound; // vakit girince: 'kisa' ezanın ilk bölümü, 'tam' ezanın tamamı, 'telefon' telefonun bildirim sesi
  bool vibrate;
  int before; // vakitten kaç dakika önce ayrıca hatırlat (0 = kapalı)
  List<bool> vakit; // İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı
  bool religiousDays; // kandil, bayram ve diğer dinî günlerde sabah hatırlatması

  EzanSettings({
    this.enabled = false,
    this.sound = true,
    this.ezanVoice = defaultVoice,
    this.ezanSound = 'kisa',
    this.vibrate = true,
    this.before = 0,
    List<bool>? vakit,
    this.religiousDays = true,
  }) : vakit = vakit ?? [true, false, true, true, true, true];

  static const beforeOptions = [0, 5, 10, 15, 30, 45];
  static const ezanSoundOptions = {'kisa': 'Kısa ezan', 'tam': 'Tam ezan', 'telefon': 'Telefon sesi'};

  /// Ezan kayıtları (res/raw içinde <anahtar>_kisa ve <anahtar>_tam). Kaynakları Hakkında sayfasında.
  static const ezanVoiceOptions = {'ezan1': 'Ses 1', 'ezan2': 'Ses 2', 'ezan3': 'Ses 3', 'ezan4': 'Ses 4'};
  static const defaultVoice = 'ezan3';

  /// Seçili kaydın ve sürenin ses dosyası adı; telefon sesi seçiliyse null.
  String? get ezanFile => ezanSound == 'telefon' ? null : '${ezanVoice}_$ezanSound';

  Map<String, dynamic> toJson() => {
        'on': enabled,
        'ses': sound,
        'ezanSes': ezanVoice,
        'ezan': ezanSound,
        'vib': vibrate,
        'once': before,
        'v': vakit,
        'dini': religiousDays,
      };

  factory EzanSettings.fromJson(Map<String, dynamic> j) => EzanSettings(
        enabled: j['on'] as bool? ?? false,
        sound: j['ses'] as bool? ?? true,
        ezanVoice: ezanVoiceOptions.containsKey(j['ezanSes']) ? j['ezanSes'] as String : defaultVoice,
        ezanSound: ezanSoundOptions.containsKey(j['ezan']) ? j['ezan'] as String : 'kisa',
        vibrate: j['vib'] as bool? ?? true,
        before: (j['once'] as num?)?.toInt() ?? 0,
        vakit: (j['v'] as List?)?.map((e) => e == true).toList(),
        religiousDays: j['dini'] as bool? ?? true,
      );

  int get activeCount => enabled ? vakit.where((v) => v).length : 0;
}

/// Zamanlanacak tek bildirim.
class PlannedNotification {
  final int id;
  final DateTime at;
  final String title;
  final String body;
  final bool ezan; // namaz vakti girdi: ezan sesiyle çalar

  const PlannedNotification(this.id, this.at, this.title, this.body, {this.ezan = false});

  @override
  String toString() => '$id $at $title';
}

/// Hangi bildirimin ne zaman çalacağını hesaplar (platformdan bağımsız, test edilebilir).
List<PlannedNotification> planNotifications({
  required EzanSettings s,
  required AppLocation loc,
  required DateTime now,
  int days = EzanNotifications.horizonDays,
  List<ReligiousDay> religious = const [],
}) {
  if (!s.enabled) return const [];
  final out = <PlannedNotification>[];
  final today = DateTime(now.year, now.month, now.day);
  for (var d = 0; d < days; d++) {
    final date = DateTime(today.year, today.month, today.day + d);
    final slots = PrayerCalc.forDay(loc, date).slots;
    for (var i = 0; i < 6; i++) {
      if (!s.vakit[i]) continue;
      final t = slots[i].time;
      final name = slots[i].name;
      if (t.isAfter(now)) {
        out.add(PlannedNotification(
          d * 100 + i * 2,
          t,
          i == 1 ? 'Güneş doğuyor' : '$name vakti',
          i == 1 ? 'Güneş ${formatHm(t)} · ${loc.name}' : '$name vakti girdi · ${formatHm(t)} · ${loc.name}',
          ezan: i != 1,
        ));
      }
      // Güneş vaktinde ezan okunmaz; önceden hatırlatma yalnız namaz vakitleri için.
      if (s.before > 0 && i != 1) {
        final pre = t.subtract(Duration(minutes: s.before));
        if (pre.isAfter(now)) {
          out.add(PlannedNotification(
            d * 100 + i * 2 + 1,
            pre,
            '$name vaktine ${s.before} dakika',
            '$name ${formatHm(t)} · ${loc.name}',
          ));
        }
      }
    }
  }
  if (s.religiousDays) {
    final end = DateTime(today.year, today.month, today.day + days);
    for (var k = 0; k < religious.length; k++) {
      final e = religious[k];
      final at = DateTime(e.date.year, e.date.month, e.date.day, 9);
      if (at.isAfter(now) && at.isBefore(end)) {
        out.add(PlannedNotification(9000 + k, at, 'Bugün ${e.name}', e.hijri));
      }
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// Ayarları saklar ve bildirimleri telefona kurar (yalnız Android).
class EzanNotifications extends ChangeNotifier {
  EzanNotifications._();
  static final EzanNotifications instance = EzanNotifications._();

  static const _key = 'ezan_bildirim_v1';

  /// Kaç gün ilerisi kurulur. Uygulama her açıldığında ve ayar/konum değişince yenilenir.
  static const horizonDays = 10;

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Uygulama açıkken bildirime dokunulunca (ör. Dua Zinciri daveti) çağrılır; içerik [payload].
  static void Function(String? payload)? onTap;
  EzanSettings settings = EzanSettings();
  bool _ready = false;

  /// Tam vaktinde (saniyesinde) çalabilir mi; değilse Android birkaç dakika geciktirebilir.
  bool exactAllowed = true;

  bool get _supported => !kIsWeb && Platform.isAndroid && !Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw != null) {
      try {
        settings = EzanSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> save(EzanSettings s) async {
    settings = s;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(s.toJson()));
    await reschedule();
  }

  Future<void> _init() async {
    if (_ready || !_supported) return;
    tzdata.initializeTimeZones();
    try {
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Bildirim iznini (Android 13+) ve tam vakit iznini ister. İzin verilmezse false döner.
  Future<bool> requestPermissions() async {
    if (!_supported) return true;
    await _init();
    final granted = await _android?.requestNotificationsPermission() ?? true;
    if (!(await _android?.canScheduleExactNotifications() ?? true)) {
      await _android?.requestExactAlarmsPermission();
    }
    exactAllowed = await _android?.canScheduleExactNotifications() ?? true;
    notifyListeners();
    return granted;
  }

  static const _lastKey = 'bildirim_son_kurulum';

  /// Uygulamaya dönülünce: tam vakit izni bu arada verildiyse (ya da kaldırıldıysa) bildirimler yeniden kurulur.
  Future<void> onResume() async {
    if (!_supported || !_ready) return;
    final exact = await _android?.canScheduleExactNotifications() ?? true;
    if (exact != exactAllowed) await reschedule();
  }

  /// Tam vakit (alarm) izni yoksa ister (Cami modu açılırken de kullanılır).
  Future<void> ensureExactAlarms() async {
    if (!_supported) return;
    await _init();
    if (!(await _android?.canScheduleExactNotifications() ?? true)) {
      await _android?.requestExactAlarmsPermission();
    }
  }

  /// Arka plan görevinden çağrılır: son kurulumdan 12 saat geçtiyse yeniden kurar. Böylece uygulama
  /// uzun süre açılmasa da ([horizonDays] gün sonra) ezan bildirimleri kesilmez.
  Future<void> refreshInBackground() async {
    if (!_supported) return;
    final p = await SharedPreferences.getInstance();
    final last = p.getInt(_lastKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - last < const Duration(hours: 12).inMilliseconds) return;
    await load();
    await reschedule();
  }

  /// Kurulu (henüz gösterilmemiş) bildirimleri silip ayarlara göre yeniden kurar. Ekranda duran
  /// bildirimlere (ör. Dua Zinciri daveti) dokunulmaz.
  Future<void> reschedule() async {
    if (!_supported) return;
    await _init();
    await _plugin.cancelAllPendingNotifications();
    unawaited(SharedPreferences.getInstance().then((p) => p.setInt(_lastKey, DateTime.now().millisecondsSinceEpoch)));
    await _scheduleHatim();
    final loc = LocationStore.instance.current;
    if (!settings.enabled || loc == null) return;
    exactAllowed = await _android?.canScheduleExactNotifications() ?? true;
    List<ReligiousDay> religious = const [];
    try {
      religious = (await TakvimData.load()).religious;
    } catch (_) {}
    final plan = planNotifications(s: settings, loc: loc, now: DateTime.now(), religious: religious);
    final s = settings;
    // Android'de kanalın sesi sonradan değişmez; her ses/titreşim bileşimi ayrı kanaldır.
    final vib = s.vibrate ? 'titresim' : 'titresimsiz';
    final vibName = s.vibrate ? '' : ' (titreşimsiz)';
    final plain = NotificationDetails(
      android: AndroidNotificationDetails(
        'ezan_${s.sound ? 'ses' : 'sessiz'}_$vib',
        '${s.sound ? 'Hatırlatmalar' : 'Hatırlatmalar (sessiz)'}$vibName',
        channelDescription: 'Güneş, vakitten önce hatırlatma ve dinî günler',
        importance: Importance.high,
        priority: Priority.high,
        playSound: s.sound,
        enableVibration: s.vibrate,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    final ezanFile = s.ezanFile;
    if (ezanFile != null) {
      // Eski kanal ezanı alarm sesi olarak çalıyordu (telefon sessizdeyken bile); kaldırılır.
      try {
        await _android?.deleteNotificationChannel(channelId: '${ezanFile}_$vib');
      } catch (_) {}
    }
    final ezan = !s.sound || ezanFile == null
        ? plain
        : NotificationDetails(
            android: AndroidNotificationDetails(
              // Bildirim sesi olarak çalar: telefon sessiz/titreşimdeyken (Cami modu dahil) ezan çalmaz.
              '${ezanFile}_${vib}_bildirim',
              '${EzanSettings.ezanVoiceOptions[s.ezanVoice]}, ${EzanSettings.ezanSoundOptions[s.ezanSound]!.toLowerCase()} ile vakit bildirimi$vibName',
              channelDescription: 'Namaz vakti girince ezan sesiyle bildirim',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              sound: RawResourceAndroidNotificationSound(ezanFile),
              enableVibration: s.vibrate,
              category: AndroidNotificationCategory.reminder,
              audioAttributesUsage: AudioAttributesUsage.notification,
            ),
          );
    final mode = exactAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final n in plan) {
      try {
        await _plugin.zonedSchedule(
          id: n.id,
          scheduledDate: tz.TZDateTime.from(n.at, tz.local),
          notificationDetails: n.ezan ? ezan : plain,
          androidScheduleMode: mode,
          title: n.title,
          body: n.body,
        );
      } catch (e) {
        debugPrint('Bildirim kurulamadı: $e');
      }
    }
    notifyListeners();
  }

  /// Hatim planı hatırlatması: önümüzdeki 7 gün, seçilen saatte (ezan bildirimleri kapalı olsa da).
  Future<void> _scheduleHatim() async {
    final plan = HatimPlan.instance;
    await plan.load();
    final next = plan.next;
    if (!plan.active || !plan.remind || next == null) return;
    List<Surah> surahs = const [];
    try {
      surahs = (await QuranData.load()).surahs;
    } catch (_) {}
    final now = DateTime.now();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'hatim_plani',
        'Hatim planı',
        channelDescription: 'Günlük hatim bölümü hatırlatması',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    // Bugünün bölümü (ve öncesi) okunduysa bugün hatırlatılmaz.
    final todayDone = next > plan.dayIndex(now);
    var k = 0;
    for (var d = 0; d < 8 && k < 7; d++) {
      final at = DateTime(now.year, now.month, now.day + d, plan.remindHour, plan.remindMinute);
      if (!at.isAfter(now) || (d == 0 && todayDone)) continue;
      final part = next + k;
      if (part >= plan.days) break;
      final p = plan.portion(part);
      final (s1, a1) = ayahOfGlobal(p.$1);
      final (s2, a2) = ayahOfGlobal(p.$2);
      final range = surahs.length == 114 ? '${surahs[s1 - 1].name} $a1 – ${surahs[s2 - 1].name} $a2' : '';
      try {
        await _plugin.zonedSchedule(
          id: 880000 + k,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'Hatim planı',
          body: range.isEmpty ? 'Bugünkü bölümünüzü okumayı unutmayın.' : 'Bugünkü bölümünüz: $range',
        );
      } catch (e) {
        debugPrint('Hatim hatırlatması kurulamadı: $e');
      }
      k++;
    }
  }
}
