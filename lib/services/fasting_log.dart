import 'package:shared_preferences/shared_preferences.dart';

/// Ramazan'da tutulan oruçlar: yıl başına, tutulan günlerin Ramazan gün numaraları (1..gün sayısı).
/// Yalnızca bu cihazda saklanır.
class FastingLog {
  FastingLog._(this._p);

  final SharedPreferences _p;

  static Future<FastingLog>? _inst;
  static Future<FastingLog> get() => _inst ??= SharedPreferences.getInstance().then(FastingLog._);

  static String _key(int year) => 'oruc_$year';

  Set<int> days(int year) => {for (final s in _p.getStringList(_key(year)) ?? const <String>[]) int.parse(s)};

  /// Günü işaretler ya da işareti kaldırır; yeni durumu döner (true: tutuldu).
  bool toggle(int year, int day) {
    final set = days(year);
    final on = !set.remove(day);
    if (on) set.add(day);
    _p.setStringList(_key(year), [for (final d in set.toList()..sort()) '$d']);
    return on;
  }
}
