import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/gunun_sozu.dart';


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
  final List<(int, int, int)> audio; // Kur'an duası ise okunacak ayetler: (sûre, ilk ayet, son ayet)

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
    this.audio = const [],
  });

  bool get hasAudio => audio.isNotEmpty;

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
        audio: [
          for (final r in (j['au'] as List? ?? const [])) ((r as List)[0] as int, r[1] as int, r[2] as int),
        ],
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
// Esmâü'l-Hüsnâ: assets/data/esma.json (99 isim)
// Liste ve sıra Tirmizî, Deavât 82 (sunnah.com, Tirmizî 3507) rivayetine göredir. Anlamlar TDV İslâm
// Ansiklopedisi'nin ilgili maddelerinden kısaltılmıştır; KONTROL_LISTESI.md'ye göre hoca kontrolü bekler.
// ---------------------------------------------------------------------------

class EsmaName {
  final String arabic;
  final String reading;
  final String meaning;

  const EsmaName(this.arabic, this.reading, this.meaning);

  static Future<List<EsmaName>>? _all;

  static Future<List<EsmaName>> all() => _all ??= () async {
        final list = jsonDecode(await rootBundle.loadString('assets/data/esma.json')) as List<dynamic>;
        return [
          for (final e in list)
            EsmaName((e as Map)['ar'] as String, e['ok'] as String, e['an'] as String),
        ];
      }();
}

// ---------------------------------------------------------------------------
// Dini Mesajlar: ayet ve hadis kartları; yazısız arka plan (assets/images/mesaj/*.webp) üstüne metin,
// kaynak ve logo uygulamada yazılır (MessageCardPainter).
// ---------------------------------------------------------------------------

class MessageCardImage {
  final String id; // favori anahtarı: "a3" (3. ayet), "h12" (12. hadis)
  final String text; // ayet meali ya da hadis metni (gunun_sozu.dart; değiştirilmez)
  final String ref; // kartın altındaki kaynak: "İnşirâh, 5" ya da "Hadis-i Şerif · Buhârî, Edeb, 33"
  final int background; // assets/images/mesaj/mNN.webp (1–40)

  const MessageCardImage(this.id, this.text, this.ref, this.background);

  String get asset => 'assets/images/mesaj/m${background.toString().padLeft(2, '0')}.webp';

  /// Yazının arkasındaki karartmanın en koyu değeri (görselin üst yarısının aydınlığına göre).
  double get shade => kMessageBackgroundShade[background - 1];
}

/// Arka planların (yazısız manzara fotoğrafları) üst yarısı için karartma oranı.
const kMessageBackgroundShade = <double>[0.7, 0.74, 0.74, 0.62, 0.68, 0.56, 0.72, 0.46, 0.63, 0.7, 0.49, 0.63, 0.36, 0.68, 0.82, 0.82, 0.6, 0.74, 0.57, 0.68, 0.55, 0.6, 0.66, 0.61, 0.67, 0.47, 0.57, 0.55, 0.58, 0.39, 0.68, 0.67, 0.57, 0.52, 0.56, 0.64, 0.61, 0.78, 0.75, 0.63];

/// Kartlar: günün ayetleri ve hadisleri (lib/data/gunun_sozu.dart), sırayla arka planlarla eşleşir.
final List<MessageCardImage> kMessageCards = () {
  final out = <MessageCardImage>[];
  final n = kDailyAyahs.length > kDailyHadiths.length ? kDailyAyahs.length : kDailyHadiths.length;
  for (var i = 0; i < n; i++) {
    if (i < kDailyAyahs.length) {
      final a = kDailyAyahs[i];
      out.add(MessageCardImage('a${i + 1}', a.meal, a.source, out.length % kMessageBackgroundShade.length + 1));
    }
    if (i < kDailyHadiths.length) {
      final h = kDailyHadiths[i];
      out.add(MessageCardImage(
          'h${i + 1}', h.text, 'Hadis-i Şerif · ${h.source}', out.length % kMessageBackgroundShade.length + 1));
    }
  }
  return out;
}();

const kMessageFavKey = 'mesaj_kart_fav2'; // kartlar değişti, eski favoriler karışmasın

/// Bu haftanın kartı: her hafta (cuma günü) sıradaki kart.
int weeklyMessageIndex(DateTime day) {
  final d = DateTime.utc(day.year, day.month, day.day);
  final friday = d.subtract(Duration(days: (d.weekday - DateTime.friday) % 7)); // son cuma (bugün dahil)
  final weeks = friday.difference(DateTime.utc(2026, 1, 2)).inDays ~/ 7; // 2 Ocak 2026 cuma
  return weeks % kMessageCards.length;
}

// ---------------------------------------------------------------------------
// Ramazan: assets/data/ramazan.json (Diyanet 2027 takvimi, onaylı önizleme metinleri)
// ---------------------------------------------------------------------------

class RamazanPrayer {
  final String title;
  final String arabic;
  final String reading;
  final String meaning;
  final String source; // yoksa boş

  const RamazanPrayer(this.title, this.arabic, this.reading, this.meaning, this.source);
}

/// Oruç Rehberi bölümü: maddeler ve Din İşleri Yüksek Kurulu "Oruç Sıkça Sorulanlar" soru numaraları.
class FastingSection {
  final String title;
  final String kind; // bozar, bozmaz, bilgi
  final List<(String, String)> items; // (metin, soru no)

  const FastingSection(this.title, this.kind, this.items);
}

class RamazanData {
  final int year;
  final DateTime start; // Ramazan'ın ilk günü
  final int days;
  final DateTime kadir; // Kadir Gecesi (bu günü sonraki güne bağlayan gece)
  final DateTime bayram; // bayramın ilk günü
  final String bayramLabel;
  final List<(String, String)> importantDays;
  final String niyetTitle;
  final String niyet;
  final String niyetNote;
  final List<RamazanPrayer> prayers;
  final List<FastingSection> fasting;

  const RamazanData({
    required this.year,
    required this.start,
    required this.days,
    required this.kadir,
    required this.bayram,
    required this.bayramLabel,
    required this.importantDays,
    required this.niyetTitle,
    required this.niyet,
    required this.niyetNote,
    required this.prayers,
    required this.fasting,
  });

  static Future<RamazanData>? _loading;

  static Future<RamazanData> load() => _loading ??= () async {
        final j = jsonDecode(await rootBundle.loadString('assets/data/ramazan.json')) as Map<String, dynamic>;
        DateTime day(String s) {
          final d = DateTime.parse(s);
          return DateTime(d.year, d.month, d.day);
        }

        final n = j['niyet'] as Map<String, dynamic>;
        final b = j['bayram'] as Map<String, dynamic>;
        return RamazanData(
          year: (j['yil'] as num).toInt(),
          start: day(j['baslangic'] as String),
          days: (j['gunSayisi'] as num).toInt(),
          kadir: day(j['kadirGecesi'] as String),
          bayram: day(b['ilk'] as String),
          bayramLabel: b['etiket'] as String,
          importantDays: [
            for (final e in j['onemliGunler'] as List) ((e as List)[0] as String, e[1] as String),
          ],
          niyetTitle: n['baslik'] as String,
          niyet: n['metin'] as String,
          niyetNote: n['not'] as String,
          prayers: [
            for (final d in j['dualar'] as List)
              RamazanPrayer(
                (d as Map)['baslik'] as String,
                d['ar'] as String,
                d['ok'] as String,
                d['an'] as String,
                (d['kaynak'] as String?) ?? '',
              ),
          ],
          fasting: [
            for (final o in j['oruc'] as List)
              FastingSection(
                (o as Map)['baslik'] as String,
                o['tur'] as String,
                [for (final m in o['maddeler'] as List) ((m as List)[0] as String, m[1] as String)],
              ),
          ],
        );
      }();

  /// Ramazan'ın kaçıncı günü (1..days); öncesinde 0 ve altı, sonrasında days'ten büyük.
  int dayNumber(DateTime now) =>
      (DateTime(now.year, now.month, now.day).difference(start).inHours / 24).round() + 1;

  DateTime dateOf(int dayNo) => DateTime(start.year, start.month, start.day + dayNo - 1);
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
