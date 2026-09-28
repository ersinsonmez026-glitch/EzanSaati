import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'location_store.dart';
import 'prayer_calc.dart';
import 'takvim.dart';

/// Ezan bildirimi ayarları (Namaz Vakitleri > Bildirimler).
class EzanSettings {
  bool enabled;
  bool sound; // false: sessiz (yalnız görünür bildirim)
  bool vibrate;
  int before; // vakitten kaç dakika önce ayrıca hatırlat (0 = kapalı)
  List<bool> vakit; // İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı
  bool religiousDays; // kandil, bayram ve diğer dinî günlerde sabah hatırlatması

  EzanSettings({
    this.enabled = false,
    this.sound = true,
    this.vibrate = true,
    this.before = 0,
    List<bool>? vakit,
    this.religiousDays = true,
  }) : vakit = vakit ?? [true, false, true, true, true, true];

  static const beforeOptions = [0, 5, 10, 15, 30, 45];

  Map<String, dynamic> toJson() => {
        'on': enabled,
        'ses': sound,
        'vib': vibrate,
        'once': before,
        'v': vakit,
        'dini': religiousDays,
      };

  factory EzanSettings.fromJson(Map<String, dynamic> j) => EzanSettings(
        enabled: j['on'] as bool? ?? false,
        sound: j['ses'] as bool? ?? true,
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

  const PlannedNotification(this.id, this.at, this.title, this.body);

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

  /// Tüm bildirimleri silip ayarlara göre yeniden kurar.
  Future<void> reschedule() async {
    if (!_supported) return;
    await _init();
    await _plugin.cancelAll();
    final loc = LocationStore.instance.current;
    if (!settings.enabled || loc == null) return;
    exactAllowed = await _android?.canScheduleExactNotifications() ?? true;
    List<ReligiousDay> religious = const [];
    try {
      religious = (await TakvimData.load()).religious;
    } catch (_) {}
    final plan = planNotifications(s: settings, loc: loc, now: DateTime.now(), religious: religious);
    final s = settings;
    final channel = 'ezan_${s.sound ? 'ses' : 'sessiz'}_${s.vibrate ? 'titresim' : 'titresimsiz'}';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        'Ezan vakitleri${s.sound ? '' : ' (sessiz)'}${s.vibrate ? '' : ' (titreşimsiz)'}',
        channelDescription: 'Namaz vakitleri ve dinî gün hatırlatmaları',
        importance: Importance.high,
        priority: Priority.high,
        playSound: s.sound,
        enableVibration: s.vibrate,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    final mode = exactAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final n in plan) {
      try {
        await _plugin.zonedSchedule(
          id: n.id,
          scheduledDate: tz.TZDateTime.from(n.at, tz.local),
          notificationDetails: details,
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
}
