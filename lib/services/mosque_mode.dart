import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location_store.dart';
import 'prayer_calc.dart';
import 'premium.dart';

/// Cami modu (Premium): seçilen vakitlerde telefon kendiliğinden sessize ya da titreşime geçer, süre
/// bitince eski hâline döner.
///
/// Sessiz kalınacak aralıklar ayar dosyasına yazılır (cami_araliklar); zamanlayıcıyı ve zil ayarını
/// Android tarafı (android/.../mosque/CamiMode.kt) kurar. Her aralık bitince Android bir sonrakini kendisi
/// kurar; uygulama açıldıkça ve arka plan görevinde liste yenilenir.
class MosqueMode extends ChangeNotifier {
  MosqueMode._();
  static final instance = MosqueMode._();

  static const _ch = MethodChannel('ezan_saati/cami');

  static const kOn = 'cami_acik';
  static const kSilent = 'cami_sessiz';
  static const kDelay = 'cami_gecikme';
  static const kMinutes = 'cami_sure';
  static const kFriday = 'cami_cuma';
  static const kPrayers = 'cami_vakitler';
  static const kWindows = 'cami_araliklar';

  /// Farz namazlar ve günün vakit listesindeki sıraları (Güneş namaz değildir).
  static const names = ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];
  static const slotIndex = [0, 2, 3, 4, 5];

  static const delays = [0, 5, 10, 15];
  static const durations = [15, 20, 30, 45];
  static const fridayDurations = [45, 60, 75];

  SharedPreferences? _p;
  bool on = false;
  bool silent = false; // false: titreşim
  int delay = 5; // ezandan kaç dakika sonra başlar
  int minutes = 20;
  int friday = 60; // cuma günü öğle vakti süresi
  List<bool> prayers = [false, true, true, true, true]; // sabah kapalı: camide sabah namazı ezandan epey sonra kılınır

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && !Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> load() async {
    _p ??= await SharedPreferences.getInstance();
    final p = _p!;
    on = p.getBool(kOn) ?? false;
    silent = p.getBool(kSilent) ?? false;
    delay = p.getInt(kDelay) ?? 5;
    minutes = p.getInt(kMinutes) ?? 20;
    friday = p.getInt(kFriday) ?? 60;
    final m = p.getInt(kPrayers);
    if (m != null) prayers = [for (var i = 0; i < 5; i++) m & (1 << i) != 0];
    notifyListeners();
  }

  Future<void> update({bool? on, bool? silent, int? delay, int? minutes, int? friday, int? toggle}) async {
    if (on != null) this.on = on;
    if (silent != null) this.silent = silent;
    if (delay != null) this.delay = delay;
    if (minutes != null) this.minutes = minutes;
    if (friday != null) this.friday = friday;
    if (toggle != null) prayers[toggle] = !prayers[toggle];
    notifyListeners();
    _p ??= await SharedPreferences.getInstance();
    final p = _p!;
    await p.setBool(kOn, this.on);
    await p.setBool(kSilent, this.silent);
    await p.setInt(kDelay, this.delay);
    await p.setInt(kMinutes, this.minutes);
    await p.setInt(kFriday, this.friday);
    await p.setInt(kPrayers, [for (var i = 0; i < 5; i++) if (prayers[i]) 1 << i].fold(0, (a, b) => a | b));
    await apply();
  }

  /// Önümüzdeki [days] günün sessiz aralıkları [başlangıç, bitiş] (ms).
  List<List<int>> windows(AppLocation loc, DateTime now, {int days = 14}) {
    final out = <List<int>>[];
    for (var d = 0; d < days; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final slots = PrayerCalc.forDay(loc, day).slots;
      for (var i = 0; i < 5; i++) {
        if (!prayers[i]) continue;
        final start = slots[slotIndex[i]].time.add(Duration(minutes: delay));
        final len = i == 1 && day.weekday == DateTime.friday ? friday : minutes;
        final end = start.add(Duration(minutes: len));
        if (end.isAfter(now)) out.add([start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);
      }
    }
    return out;
  }

  /// Aralıkları yazar ve Android'e kurdurur (kapalıysa ya da Premium yoksa kaldırır).
  Future<void> apply() async {
    final active = on && Premium.instance.active && prayers.contains(true);
    await writeWindows(active: active);
    if (!_android) return;
    try {
      await _ch.invokeMethod<void>(active ? 'schedule' : 'cancel');
    } catch (_) {}
  }

  /// Arka plan görevinden de çağrılır: liste güncel kalsın (Android sıradakini buradan okur).
  Future<void> writeWindows({bool? active}) async {
    _p ??= await SharedPreferences.getInstance();
    final p = _p!;
    final loc = LocationStore.instance.current;
    final act = active ?? ((p.getBool(kOn) ?? false) && Premium.instance.active);
    if (!act || loc == null) {
      await p.remove(kWindows);
      return;
    }
    await p.setString(kWindows, jsonEncode(windows(loc, DateTime.now())));
  }

  Future<bool> hasDndAccess() async {
    if (!_android) return true;
    try {
      return await _ch.invokeMethod<bool>('dndAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openDndSettings() async {
    if (!_android) return;
    try {
      await _ch.invokeMethod<void>('openDnd');
    } catch (_) {}
  }
}
