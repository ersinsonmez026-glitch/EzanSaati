import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../firebase_options.dart';
import 'ezan_notifications.dart';
import 'home_widgets.dart';
import 'location_store.dart';
import 'mosque_mode.dart';
import 'premium.dart';

/// Uygulama kapalıyken Dua Zinciri'ni kontrol eder: telefon yaklaşık 30 dakikada bir (Android izin
/// verdikçe) katıldığı zincirlerden tamamlanan var mı diye bakar, varsa bir kez bildirim gösterir.
/// Hiç zincire katılmamışsa sunucuya bağlanmaz.
class InviteWatch {
  static const _task = 'davet_kontrol';
  static const _notifiedKey = 'zincir_tamam_bildirilenler';

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

  /// Arka plandaki kontrol: katıldığım zincirlerden tamamlananlar için (her zincire bir kez) bildirim.
  static Future<void> check() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString('cember_ad') ?? '').isEmpty) return; // Dua Zinciri hiç kullanılmamış
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Dua Zinciri hiç açılmamış
    final notified = (prefs.getStringList(_notifiedKey) ?? const <String>[]).toSet();
    final db = FirebaseFirestore.instance;
    // Yalnız sunucudan okunur: çevrimdışı önbellekten eksik sonuç gelirse tamamlanan zincir kaçmasın.
    const server = GetOptions(source: Source.server);
    final chains = await db.collection('chains').where('memberUids', arrayContains: user.uid).get(server);
    final since = DateTime.now().subtract(const Duration(days: 2));
    final fresh = <(String, String)>[]; // (zincir kimliği, bildirim metni)
    for (final c in chains.docs) {
      final m = c.data();
      if (notified.contains(c.id)) continue;
      final deadline = m['deadline'];
      if (deadline is Timestamp && deadline.toDate().isBefore(since)) continue; // eski zincirler okunmaz
      final total = (m['total'] as num?)?.toInt() ?? 0;
      var done = 0;
      if (m['type'] == 'hatim') {
        done = (await c.reference.collection('slots').where('done', isEqualTo: true).get(server)).docs.length;
      } else {
        for (final x in (await c.reference.collection('claims').get(server)).docs) {
          final amount = (x.data()['amount'] as num?)?.toInt() ?? 0;
          done += ((x.data()['done'] as num?)?.toInt() ?? 0).clamp(0, amount);
        }
      }
      if (total > 0 && done >= total) {
        fresh.add((c.id, '"${m['name'] ?? 'Dua'}" zinciri tamamlandı. Allah kabul etsin.'));
      }
    }
    // Sorgular başarıyla bitti: bildirilenler ancak şimdi kaydedilir.
    final keep = [...notified, for (final (id, _) in fresh) id];
    await prefs.setStringList(_notifiedKey, keep.length > 200 ? keep.sublist(keep.length - 200) : keep);
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
            channelDescription: 'Katıldığınız dua zincirleri tamamlanınca',
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
      await MosqueMode.instance.load(); // kullanıcının seçtiği vakit ve süreler
      await MosqueMode.instance.writeWindows();
    } catch (_) {}
    try {
      // Uygulama uzun süre açılmasa da ezan ve hatim bildirimleri kurulu kalsın.
      await EzanNotifications.instance.refreshInBackground();
    } catch (_) {}
    try {
      await InviteWatch.check();
    } catch (_) {
      // Bağlantı yoksa bir sonraki kontrolde tekrar denenir.
    }
    return true;
  });
}
