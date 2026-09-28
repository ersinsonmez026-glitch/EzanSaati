import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Kur'an: assets/data/kuran.json
// Arapça metin Tanzil Projesi, meal Ruvvâd Tercüme Merkezi (QuranEnc.com).
// Biçim: {"m": [[ad, arapça ad, mekkî(1/0), ayet sayısı], ...],
//         "v": [[[arapça, meal, dipnot], ...], ...]}
// ---------------------------------------------------------------------------

class Surah {
  final int no;
  final String name;
  final String arabic;
  final bool meccan;
  final int ayahCount;

  const Surah(this.no, this.name, this.arabic, this.meccan, this.ayahCount);

  String get kind => meccan ? 'Mekkî' : 'Medenî';
}

class Ayah {
  final String arabic;
  final String meal;
  final String note; // dipnot, yoksa boş

  const Ayah(this.arabic, this.meal, this.note);

  /// Günün ayeti gibi yerlerde "[1]" dipnot işaretleri olmadan.
  String get plainMeal => meal.replaceAll(RegExp(r'\[\d+\]'), '');
}

class QuranData {
  final List<Surah> surahs;
  final List<List<Ayah>> verses;

  const QuranData(this.surahs, this.verses);

  static Future<QuranData>? _loading;

  /// Bir kez yüklenir, sonra aynı veri kullanılır.
  static Future<QuranData> load() => _loading ??= _load();

  static Future<QuranData> _load() async {
    final raw = await rootBundle.loadString('assets/data/kuran.json');
    return compute(_parseQuran, raw);
  }
}

QuranData _parseQuran(String raw) {
  final j = jsonDecode(raw) as Map<String, dynamic>;
  final m = j['m'] as List<dynamic>;
  final v = j['v'] as List<dynamic>;
  final surahs = <Surah>[
    for (var i = 0; i < m.length; i++)
      Surah(
        i + 1,
        (m[i] as List)[0] as String,
        (m[i] as List)[1] as String,
        ((m[i] as List)[2] as num) == 1,
        ((m[i] as List)[3] as num).toInt(),
      ),
  ];
  final verses = <List<Ayah>>[
    for (final s in v)
      [
        for (final a in s as List)
          Ayah((a as List)[0] as String, a[1] as String, a.length > 2 ? a[2] as String : ''),
      ],
  ];
  return QuranData(surahs, verses);
}

// ---------------------------------------------------------------------------
// Dualar: assets/data/dualar.json (106 dua) ve assets/data/namaz_dualari.json
// ---------------------------------------------------------------------------

class Dua {
  final String group; // "namaz" ya da "diger"
  final String category;
  final String section; // Namaz dualarında alt başlık
  final String title;
  final String arabic;
  final String reading; // okunuşu
  final String meaning; // anlamı
  final String source;
  final bool fromMeal; // anlamı ayet meali mi

  const Dua({
    required this.group,
    required this.category,
    required this.section,
    required this.title,
    required this.arabic,
    required this.reading,
    required this.meaning,
    required this.source,
    required this.fromMeal,
  });

  factory Dua.fromJson(Map<String, dynamic> j) => Dua(
        group: (j['g'] as String?) ?? '',
        category: (j['c'] as String?) ?? '',
        section: (j['sec'] as String?) ?? '',
        title: j['t'] as String,
        arabic: j['ar'] as String,
        reading: j['ok'] as String,
        meaning: j['an'] as String,
        source: (j['src'] as String?) ?? '',
        fromMeal: j['n'] == 'meal',
      );

  /// Kopyalama ve paylaşma metni.
  String get shareText => '$title\n\n$arabic\n\n$reading\n\n$meaning\n($source)';
}

/// Dua favorilerinin saklandığı anahtar (dua başlıkları tutulur).
const kDuaFavKey = 'dua_fav';

/// Dua gruplarının görünen adları.
const kDuaGroupNames = {'namaz': 'Namaz Duaları', 'diger': 'Diğer Dualar'};

class DuaData {
  static Future<List<Dua>>? _all;
  static Future<Map<String, Dua>>? _namaz;

  /// Dualar sayfasının 106 duası (sırası korunur).
  static Future<List<Dua>> all() => _all ??= () async {
        final raw = await rootBundle.loadString('assets/data/dualar.json');
        final list = jsonDecode(raw) as List<dynamic>;
        return [for (final e in list) Dua.fromJson(e as Map<String, dynamic>)];
      }();

  /// Namaz Öğren'de adımların altında gösterilen dualar (başlığa göre).
  static Future<Map<String, Dua>> namaz() => _namaz ??= () async {
        final raw = await rootBundle.loadString('assets/data/namaz_dualari.json');
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return {
          for (final e in map.entries) e.key: Dua.fromJson({...e.value as Map<String, dynamic>, 'g': 'namaz'}),
        };
      }();
}

// ---------------------------------------------------------------------------
// Okuma tercihleri: favoriler, kaldığın yer, yazı boyutu
// ---------------------------------------------------------------------------

class ReadingPrefs {
  ReadingPrefs._(this._p);

  final SharedPreferences _p;

  static Future<ReadingPrefs>? _inst;
  static Future<ReadingPrefs> get() => _inst ??= SharedPreferences.getInstance().then(ReadingPrefs._);

  Set<String> favorites(String key) => (_p.getStringList(key) ?? const []).toSet();

  /// Favoriye ekler ya da çıkarır; yeni durumu döner.
  bool toggleFavorite(String key, String id) {
    final set = favorites(key);
    final on = !set.remove(id);
    if (on) set.add(id);
    _p.setStringList(key, set.toList());
    return on;
  }

  double fontScale(String key) => _p.getDouble(key) ?? 1.0;

  /// 0.8 ile 1.6 arasında, 0.1 adımla.
  double changeFontScale(String key, double delta) {
    final v = ((fontScale(key) + delta) * 10).round() / 10;
    final c = v.clamp(0.8, 1.6).toDouble();
    _p.setDouble(key, c);
    return c;
  }

  /// Sureler: en son okunan sure ve ayet.
  (int, int)? get lastRead {
    final s = _p.getString('sure_last');
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final a = int.tryParse(parts[0]), b = int.tryParse(parts[1]);
    return a == null || b == null ? null : (a, b);
  }

  void setLastRead(int surah, int ayah) => _p.setString('sure_last', '$surah:$ayah');

  String? getString(String key) => _p.getString(key);
  void setString(String key, String value) => _p.setString(key, value);
}

/// Yılın kaçıncı günü (0'dan başlar). Günün ayeti/duası seçimi için.
int dayOfYear(DateTime d) => DateTime(d.year, d.month, d.day).difference(DateTime(d.year, 1, 1)).inDays;
