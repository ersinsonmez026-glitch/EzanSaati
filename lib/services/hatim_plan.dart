import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_audio.dart';

/// Kişisel hatim planı: Kur'an seçilen gün sayısına ayet sayısıyla eşit bölünür; her gün bir bölüm
/// okunur ve "Okudum" ile işaretlenir. Geride kalınan bölümler sırayla okunur. Yalnız bu telefonda tutulur.
class HatimPlan extends ChangeNotifier {
  HatimPlan._();
  static final instance = HatimPlan._();

  static const _key = 'hatim_plan';

  /// Seçilebilen süreler (gün).
  static const durations = [7, 15, 30, 60, 90, 180];

  SharedPreferences? _p;
  DateTime? start; // plan yoksa null
  int days = 30;
  final Set<int> done = {}; // okunan bölümler (0'dan)
  int completed = 0; // tamamlanan hatim sayısı
  bool remind = true;
  int remindHour = 21;
  int remindMinute = 0;

  bool get active => start != null;

  Future<void> load() async {
    _p ??= await SharedPreferences.getInstance();
    final raw = _p!.getString(_key);
    start = null;
    done.clear();
    completed = 0;
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final s = j['s'] as String?;
        start = s == null ? null : DateTime.parse(s);
        days = (j['n'] as num?)?.toInt() ?? 30;
        done.addAll([for (final x in (j['d'] as List? ?? const [])) (x as num).toInt()]);
        completed = (j['c'] as num?)?.toInt() ?? 0;
        remind = j['r'] as bool? ?? true;
        remindHour = (j['h'] as num?)?.toInt() ?? 21;
        remindMinute = (j['m'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
    notifyListeners();
  }

  void _save() {
    final s = start;
    _p?.setString(
      _key,
      jsonEncode({
        's': s == null ? null : '${s.year.toString().padLeft(4, '0')}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}',
        'n': days,
        'd': done.toList()..sort(),
        'c': completed,
        'r': remind,
        'h': remindHour,
        'm': remindMinute,
      }),
    );
    notifyListeners();
  }

  /// Yeni plan: bugünden başlar.
  void begin(int n, DateTime today) {
    start = DateTime(today.year, today.month, today.day);
    days = n;
    done.clear();
    _save();
  }

  void stop() {
    start = null;
    done.clear();
    _save();
  }

  void setReminder(bool on, {int? hour, int? minute}) {
    remind = on;
    if (hour != null) remindHour = hour;
    if (minute != null) remindMinute = minute;
    _save();
  }

  /// [i]. bölümün ilk ve son ayeti (Kur'an genelindeki sıra, 1–6236).
  (int, int) portion(int i) => portionOf(i, days);

  static (int, int) portionOf(int i, int n) =>
      ((i * kTotalAyahs / n).round() + 1, ((i + 1) * kTotalAyahs / n).round());

  /// Bugün planın kaçıncı günü (0'dan; plan süresiyle sınırlı).
  int dayIndex(DateTime now) {
    final s = start;
    if (s == null) return 0;
    final d = DateTime(now.year, now.month, now.day).difference(s).inHours ~/ 24;
    return d.clamp(0, days - 1);
  }

  /// Okunacak ilk bölüm (geride kalınan varsa o); hepsi okunduysa null.
  int? get next {
    for (var i = 0; i < days; i++) {
      if (!done.contains(i)) return i;
    }
    return null;
  }

  /// Bugüne kadar okunması gerekip okunmayan bölüm sayısı.
  int behind(DateTime now) => (dayIndex(now) + 1 - done.length).clamp(0, days);

  /// Bölümü okundu yapar; hepsi bitince hatim sayısı artar ve plan kapanır. Hatim bittiyse true.
  bool markRead(int i) {
    done.add(i);
    if (done.length >= days) {
      completed++;
      start = null;
      done.clear();
      _save();
      return true;
    }
    _save();
    return false;
  }

  void unmark(int i) {
    done.remove(i);
    _save();
  }

  @visibleForTesting
  void reset() {
    start = null;
    done.clear();
    completed = 0;
    days = 30;
    remind = true;
    _p = null;
  }
}
