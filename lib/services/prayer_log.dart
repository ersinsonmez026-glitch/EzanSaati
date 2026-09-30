import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Namaz takibi: hangi gün hangi farz namazın kılındığı, özel gün (ara) günleri ve kaza borcu.
/// Yalnız bu telefonda tutulur.
class PrayerLog extends ChangeNotifier {
  PrayerLog._();
  static final instance = PrayerLog._();

  static const _key = 'namaz_takip';

  /// Takip edilen farz namazlar ve Namaz Vakitleri satırlarındaki sıraları (Güneş namaz değildir).
  static const names = ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];
  static const slotIndex = [0, 2, 3, 4, 5];

  SharedPreferences? _p;
  final Map<String, int> _days = {}; // 'yyyy-mm-dd' → kılınanlar (bit 0 sabah … bit 4 yatsı)
  final Set<String> _pause = {}; // özel gün: seri bozulmaz
  List<int> kaza = List.filled(5, 0);

  /// Kaza orucu borcu (gün).
  int kazaOruc = 0;

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> load() async {
    _p ??= await SharedPreferences.getInstance();
    final raw = _p!.getString(_key);
    _days.clear();
    _pause.clear();
    kaza = List.filled(5, 0);
    kazaOruc = 0;
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        (j['d'] as Map? ?? const {}).forEach((k, v) => _days[k as String] = (v as num).toInt());
        _pause.addAll([for (final x in (j['a'] as List? ?? const [])) x as String]);
        final k = [for (final x in (j['k'] as List? ?? const [])) (x as num).toInt()];
        if (k.length == 5) kaza = k;
        kazaOruc = (j['ko'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
    notifyListeners();
  }

  void _save() {
    _p?.setString(_key, jsonEncode({'d': _days, 'a': _pause.toList(), 'k': kaza, 'ko': kazaOruc}));
    notifyListeners();
  }

  @visibleForTesting
  void replace({Map<String, int> days = const {}, Set<String> pause = const {}, List<int>? kazaDebt, int fastDebt = 0}) {
    kazaOruc = fastDebt;
    _days
      ..clear()
      ..addAll(days);
    _pause
      ..clear()
      ..addAll(pause);
    kaza = kazaDebt ?? List.filled(5, 0);
    notifyListeners();
  }

  int mask(DateTime d) => _days[dayKey(d)] ?? 0;
  bool prayed(DateTime d, int p) => mask(d) & (1 << p) != 0;
  int count(DateTime d) => [for (var p = 0; p < 5; p++) if (prayed(d, p)) 1].length;
  bool paused(DateTime d) => _pause.contains(dayKey(d));

  void toggle(DateTime d, int p) {
    final k = dayKey(d);
    final m = (_days[k] ?? 0) ^ (1 << p);
    m == 0 ? _days.remove(k) : _days[k] = m;
    _save();
  }

  void setPaused(DateTime d, bool on) {
    on ? _pause.add(dayKey(d)) : _pause.remove(dayKey(d));
    _save();
  }

  /// Beşini de kılınan (ya da ara verilen) art arda günler; bugün henüz bitmediyse dünden sayılır.
  int streak(DateTime today) {
    var d = DateTime(today.year, today.month, today.day);
    if (count(d) < 5 && !paused(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (count(d) == 5 || paused(d)) {
      if (!paused(d)) n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// [from] ile [to] arası (dahil) kılınan / kılınması gereken (ara günleri hariç).
  (int, int) range(DateTime from, DateTime to) {
    var done = 0, total = 0;
    for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
      if (paused(d)) continue;
      done += count(d);
      total += 5;
    }
    return (done, total);
  }

  void setKaza(int p, int v) {
    kaza[p] = v < 0 ? 0 : v;
    _save();
  }

  int get kazaTotal => kaza.fold(0, (a, b) => a + b);

  void setKazaOruc(int v) {
    kazaOruc = v < 0 ? 0 : v;
    _save();
  }
}
