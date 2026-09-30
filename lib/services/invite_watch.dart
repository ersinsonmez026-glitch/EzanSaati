import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../firebase_options.dart';
import 'home_widgets.dart';
import 'location_store.dart';
import 'mosque_mode.dart';
import 'premium.dart';

/// Uygulama kapalıyken Dua Zinciri gruplarını kontrol eder: telefon yaklaşık 30 dakikada bir
/// (Android izin verdikçe) üye olduğu gruplarda başkasının başlattığı yeni zincir var mı diye bakar,
/// varsa bildirim gösterir. Hiç gruba katılmamışsa sunucuya bağlanmaz.
class InviteWatch {
  static const _task = 'davet_kontrol';
  static const _lastKey = 'zincir_son_kontrol';

  /// Bildirime dokununca açılacak yer (Dua Zinciri).
  static const payload = 'davet';

  /// Uygulama açılışında bir kez çağrılır; görev zaten kuruluysa aynen kalır.
  static Future<void> schedule() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Workmanager().initialize(inviteWatchDispatcher);
      await Workmanager().registerPeriodicTask(
        _task,
        _task,
        frequency: const Duration(minutes: 30),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {
      // Arka plan görevi kurulamazsa zincirler yine uygulama açılınca görünür.
    }
  }

  /// Arka plandaki kontrol: son kontrolden sonra gruplarımda başlatılan zincirler için bildirim.
  static Future<void> check() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString('cember_ad') ?? '').isEmpty) return; // hiç gruba katılmamış
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Dua Zinciri hiç açılmamış
    final now = DateTime.now();
    final lastMs = prefs.getInt(_lastKey);
    await prefs.setInt(_lastKey, now.millisecondsSinceEpoch);
    if (lastMs == null) return; // ilk kontrol: yalnız başlangıç zamanını kaydet
    final since = Timestamp.fromMillisecondsSinceEpoch(lastMs);
    final db = FirebaseFirestore.instance;
    final groups = await db.collection('groups').where('memberUids', arrayContains: user.uid).get();
    final fresh = <(String, String)>[]; // (zincir kimliği, bildirim metni)
    for (final g in groups.docs) {
      final gname = g.data()['name'] as String? ?? '';
      final chains = await g.reference.collection('chains').where('created', isGreaterThan: since).get();
      for (final c in chains.docs) {
        final m = c.data();
        if (m['creatorUid'] == user.uid) continue;
        final who = (m['creatorName'] as String? ?? '').trim();
        fresh.add((c.id, '${who.isEmpty ? 'Bir üye' : who} "$gname" grubunda ${m['name'] ?? 'yeni bir'} zinciri başlattı.'));
      }
    }
    if (fresh.isEmpty) return;
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    for (final (id, text) in fresh) {
      await plugin.show(
        id: id.hashCode & 0x3fffffff,
        title: 'Dua Zinciri',
        body: text,
        payload: payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'dua_zinciri_davet',
            'Dua Zinciri',
            channelDescription: 'Gruplarınızda başlatılan yeni dua zincirleri',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  /// Android 13+ bildirim izni (ad kaydedilince istenir).
  static Future<void> requestPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }
}

/// Arka plan görevinin giriş noktası (Android ayrı bir Dart ortamında çağırır).
@pragma('vm:entry-point')
void inviteWatchDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      // Ana ekran vakit widget'ının vakitleri (uygulama uzun süre açılmasa da güncel kalsın).
      await LocationStore.instance.load();
      await HomeWidgets.writeTimes();
      // Cami modu aralıkları (Android sıradaki sessizliği bu listeden kurar).
      await Premium.instance.load();
      await MosqueMode.instance.writeWindows();
    } catch (_) {}
    try {
      await InviteWatch.check();
    } catch (_) {
      // Bağlantı yoksa bir sonraki kontrolde tekrar denenir.
    }
    return true;
  });
}
