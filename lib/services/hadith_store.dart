import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Hadisler: metinler HadeethEnc.com'dan (Hadis Tercümeleri Ansiklopedisi) değiştirilmeden alınır.
/// Kullanım şartı: metin değiştirilmeden, kaynak (HadeethEnc.com) belirtilerek. Resmî API:
/// https://hadeethenc.com/api/v1/hadeeths/one/?language=tr&id=ID
/// İndirilen metinler telefonda saklanır; internet yokken de açılır, haftada bir yenilenir.
class Hadith {
  final String id;
  final String title;
  final String text; // Türkçe tercüme (HadeethEnc "hadeeth")
  final String arabic;
  final String attribution; // kaynak kitap
  final String grade; // sıhhat derecesi
  final String explanation;

  const Hadith({
    required this.id,
    required this.title,
    required this.text,
    required this.arabic,
    required this.attribution,
    required this.grade,
    required this.explanation,
  });

  factory Hadith.fromApi(Map<String, dynamic> j) => Hadith(
        id: '${j['id']}',
        title: (j['title'] as String? ?? '').trim(),
        text: (j['hadeeth'] as String? ?? '').trim(),
        arabic: (j['hadeeth_ar'] as String? ?? '').trim(),
        attribution: (j['attribution'] as String? ?? '').trim(),
        grade: (j['grade'] as String? ?? '').trim(),
        explanation: (j['explanation'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toApi() => {
        'id': id,
        'title': title,
        'hadeeth': text,
        'hadeeth_ar': arabic,
        'attribution': attribution,
        'grade': grade,
        'explanation': explanation,
      };

  /// HadeethEnc'teki sayfası.
  String get url => 'https://hadeethenc.com/tr/browse/hadith/$id';

  String get shareText => '$text\n\n($attribution · $grade)\nKaynak: HadeethEnc.com – $url';
}

/// Uygulamada gösterilen hadisler (KONTROL_LISTESI.md 4. bölüm; din görevlisi kontrolü bekliyor).
const kHadithIds = [
  '5803', '66511', '4709', '4555', '5437', '8289', '5435', '5348', //
  '3852', '66255', '5516', '5478', '3074', '5493', '3779',
];

const kHadithFavKey = 'hadis_fav';

typedef HadithFetcher = Future<Map<String, dynamic>> Function(String id);

class HadithStore {
  static const _cacheKey = 'hadis_cache_v1';
  static const refreshAfter = Duration(days: 7);

  final HadithFetcher _fetch;
  final DateTime Function() _now;

  HadithStore({HadithFetcher? fetch, DateTime Function()? now})
      : _fetch = fetch ?? _httpFetch,
        _now = now ?? DateTime.now;

  static Future<Map<String, dynamic>> _httpFetch(String id) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse('https://hadeethenc.com/api/v1/hadeeths/one/?language=tr&id=$id'));
      req.headers.set(HttpHeaders.userAgentHeader, 'EzanSaati/1.0');
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw HttpException('HadeethEnc ${res.statusCode}');
      final body = await res.transform(utf8.decoder).join();
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  /// Saklanan hadisler (sıra: [kHadithIds]); hiç indirilmemişse boş liste.
  Future<List<Hadith>> cached() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey);
    if (raw == null) return const [];
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final items = (j['items'] as Map).cast<String, dynamic>();
      return [
        for (final id in kHadithIds)
          if (items[id] != null) Hadith.fromApi((items[id] as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<DateTime?> lastFetch() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return DateTime.tryParse((jsonDecode(raw) as Map)['at'] as String);
    } catch (_) {
      return null;
    }
  }

  /// Eksik ya da eskimişse HadeethEnc'ten yeniler. Başarısız olursa saklananlar döner;
  /// hiç yoksa hata fırlatır.
  Future<List<Hadith>> load({bool force = false}) async {
    final have = await cached();
    final at = await lastFetch();
    final fresh = at != null && _now().difference(at) < refreshAfter && have.length == kHadithIds.length;
    if (fresh && !force) return have;
    try {
      final items = <String, dynamic>{};
      for (final id in kHadithIds) {
        final h = Hadith.fromApi(await _fetch(id));
        if (h.text.isEmpty) throw const FormatException('Boş hadis metni');
        items[id] = h.toApi();
      }
      final p = await SharedPreferences.getInstance();
      await p.setString(_cacheKey, jsonEncode({'at': _now().toIso8601String(), 'items': items}));
      return [for (final id in kHadithIds) Hadith.fromApi((items[id] as Map).cast<String, dynamic>())];
    } catch (e) {
      if (have.isNotEmpty) return have;
      rethrow;
    }
  }
}
