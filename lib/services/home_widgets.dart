import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_store.dart';
import 'location_store.dart';
import 'prayer_calc.dart';
import 'quran_audio.dart';

/// Ana ekran widget'ları (Android): Kur'an çalar (listeli ve tek satır), zikir sayacı, vakitler.
///
/// Widget'lar Android tarafında çizilir (android/app/src/main/kotlin/.../widget). Veriyi uygulamanın
/// ayar dosyasından (SharedPreferences) okurlar; burada yazılır:
/// * w_kari     — seçili kârî {id, rate, name}
/// * w_sureler  — [[sûre adı, ayet sayısı], ...] (114)
/// * w_fav_sure — favori sûre numaraları
/// * w_son      — en son okunan sûre (çalar ilk kez buradan başlar)
/// * w_dualar   — sesli dualar [{t: başlık, u: [ses adresleri]}]
/// * w_vakit    — {loc: konum adı, d: [[6 vaktin zamanı (ms)], ...]} dünden başlayarak 32 gün
/// Zikir widget'ı Zikir Sayacı'nın kaydını (zikir_v2) doğrudan kullanır; gündüz/gece day_mode'dan okunur.
class HomeWidgets {
  static const _ch = MethodChannel('ezan_saati/widget');

  static bool get _enabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && !Platform.environment.containsKey('FLUTTER_TEST');

  static Timer? _debounce;

  /// Bütün widget verisini yazar ve widget'ları yeniler (art arda çağrılar birleştirilir).
  static void syncSoon() {
    if (!_enabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => unawaited(sync()));
  }

  static Future<void> sync() async {
    if (!_enabled) return;
    try {
      final p = await SharedPreferences.getInstance();
      final r = currentReciter();
      await p.setString('w_kari', jsonEncode({'id': r.id, 'rate': r.bitrate, 'name': r.name}));
      final q = await QuranData.load();
      await p.setString('w_sureler', jsonEncode([for (final s in q.surahs) [s.name, s.ayahCount]]));
      final favs = (p.getStringList('sure_fav') ?? const <String>[])
          .map((id) => int.tryParse(id.replaceFirst('s', '')))
          .whereType<int>()
          .toList()
        ..sort();
      await p.setString('w_fav_sure', jsonEncode(favs));
      final last = (await ReadingPrefs.get()).lastRead;
      await p.setInt('w_son', last?.$1 ?? 1); // çalar ilk kez: en son okunan sûreden başlar
      final duas = await DuaData.all();
      await p.setString(
        'w_dualar',
        jsonEncode([
          for (final d in duas.where((d) => d.hasAudio))
            {
              't': d.title,
              'u': [for (final u in duaAudioUrls(d.audio, r)) '$u'],
            },
        ]),
      );
      await writeTimes(p);
      await refresh();
    } catch (_) {
      // Widget verisi yazılamazsa uygulama etkilenmez.
    }
  }

  /// Vakitleri yazar (arka plan görevinden de çağrılır; yenilemeyi widget kendi zamanlayıcısıyla yapar).
  static Future<void> writeTimes([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final loc = LocationStore.instance.current;
    if (loc == null) {
      await p.remove('w_vakit');
      return;
    }
    final now = DateTime.now();
    final days = [
      for (var i = -1; i <= 30; i++)
        [for (final s in PrayerCalc.forDay(loc, DateTime(now.year, now.month, now.day + i)).slots) s.time.millisecondsSinceEpoch],
    ];
    await p.setString('w_vakit', jsonEncode({'loc': loc.name, 'd': days}));
  }

  /// Widget'ları yeniden çizer.
  static Future<void> refresh() async {
    if (!_enabled) return;
    try {
      await _ch.invokeMethod<void>('update');
    } catch (_) {}
  }

  /// Uygulamada sûre dinlenmeye başlanınca widget çaları durur (iki ses üst üste binmesin).
  static Future<void> pausePlayer() async {
    if (!_enabled) return;
    try {
      await _ch.invokeMethod<void>('pausePlayer');
    } catch (_) {}
  }
}
