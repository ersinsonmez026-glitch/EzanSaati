import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../firebase_options.dart';
import 'circle_sync.dart';

/// Uygulama kapalıyken Dua Zinciri davetlerini kontrol eder: telefon yaklaşık 30 dakikada bir
/// (Android izin verdikçe) kendi numarasına gelen yeni davet var mı diye bakar, varsa bildirim gösterir.
/// Numara kaydedilmemişse sunucuya hiç bağlanmaz. Uygulama açıkken davetler zaten anında görünür.
class InviteWatch {
  static const _task = 'davet_kontrol';
  static const _seenKey = 'cember_bildirilen_davetler';

  /// Bildirime dokununca açılacak yer (uygulama Davetler'i açar).
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
      // Arka plan görevi kurulamazsa davetler yine uygulama açıkken görünür.
    }
  }

  /// Arka plandaki kontrol: yeni (daha önce bildirilmemiş, süresi geçmemiş) davetler için bildirim.
  static Future<void> check() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = phoneHash(prefs.getString('cember_tel') ?? '');
    if (hash.isEmpty) return;
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Dua Zinciri hiç açılmamış
    final snap = await FirebaseFirestore.instance.collectionGroup('members').where('phoneHash', isEqualTo: hash).get();
    final seen = [...?prefs.getStringList(_seenKey)];
    final now = DateTime.now();
    final fresh = <(String, String)>[]; // (davet kodu, bildirim metni)
    for (final d in snap.docs) {
      final m = d.data();
      if (m['status'] != 'pending' || m['uid'] != null || m['ownerUid'] == user.uid) continue;
      final exp = (m['expiresAt'] as Timestamp?)?.toDate();
      if (exp != null && !exp.isAfter(now)) continue;
      if (seen.contains(d.id)) continue;
      final owner = (m['ownerName'] as String? ?? '').trim();
      final circle = (m['circleName'] as String? ?? '').trim();
      fresh.add((d.id, '${owner.isEmpty ? 'Bir yakınınız' : owner} sizi "$circle" dua zincirine davet etti.'));
    }
    if (fresh.isEmpty) return;
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    for (final (code, text) in fresh) {
      await plugin.show(
        id: code.hashCode & 0x3fffffff,
        title: 'Dua Zinciri daveti',
        body: text,
        payload: payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'dua_zinciri_davet',
            'Dua Zinciri davetleri',
            channelDescription: 'Size gelen dua zinciri davetleri',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      seen.add(code);
    }
    await prefs.setStringList(_seenKey, seen.length > 50 ? seen.sublist(seen.length - 50) : seen);
  }

  /// Android 13+ bildirim izni (numara kaydedilince istenir).
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
      await InviteWatch.check();
    } catch (_) {
      // Bağlantı yoksa bir sonraki kontrolde tekrar denenir.
    }
    return true;
  });
}
