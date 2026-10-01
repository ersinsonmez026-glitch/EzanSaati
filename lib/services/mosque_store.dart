import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'location_store.dart';

/// Yakındaki cami (Google Haritalar ya da OpenStreetMap).
class Mosque {
  static const unnamed = 'Cami (adı kayıtlı değil)';

  final String name;
  final double lat;
  final double lng;
  final double km; // kuş uçuşu uzaklık
  final double bearing; // kuzeyden saat yönünde derece

  const Mosque(this.name, this.lat, this.lng, this.km, this.bearing);

  String get distanceText => km < 1 ? '${(km * 1000 / 10).round() * 10} m' : '${km.toStringAsFixed(1)} km';

  String get directionText => directionName(bearing);

  /// Yürüyüş yol tarifi (Google Haritalar ya da telefondaki harita uygulaması açar).
  Uri get directionsUri => Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking');
}

String directionName(double deg) {
  const names = ['Kuzey', 'Kuzeydoğu', 'Doğu', 'Güneydoğu', 'Güney', 'Güneybatı', 'Batı', 'Kuzeybatı'];
  return names[((deg % 360 + 22.5) % 360 ~/ 45)];
}

double bearingDeg(double lat1, double lng1, double lat2, double lng2) {
  double rad(double d) => d * math.pi / 180;
  final dl = rad(lng2 - lng1);
  final y = math.sin(dl) * math.cos(rad(lat2));
  final x = math.cos(rad(lat1)) * math.sin(rad(lat2)) - math.sin(rad(lat1)) * math.cos(rad(lat2)) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

typedef OverpassFetcher = Future<Map<String, dynamic>> Function(String query);

/// Camileri OpenStreetMap Overpass API'sinden bulur (ücretsiz, anahtarsız; günde 10.000 sorgu sınırı
/// uygulama başına değil kullanıcı başınadır). Bir sunucu yanıt vermezse sıradakine geçilir.
class MosqueStore {
  static const endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  final OverpassFetcher _fetch;

  MosqueStore({OverpassFetcher? fetch}) : _fetch = fetch ?? _httpFetch;

  static Future<Map<String, dynamic>> _httpFetch(String query) async {
    Object? last;
    for (final ep in endpoints) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final req = await client.postUrl(Uri.parse(ep));
        req.headers.set(HttpHeaders.userAgentHeader, 'EzanSaati/1.0');
        req.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
        req.write('data=${Uri.encodeQueryComponent(query)}');
        final res = await req.close().timeout(const Duration(seconds: 25));
        if (res.statusCode != 200) throw HttpException('Overpass ${res.statusCode}');
        return jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      } catch (e) {
        last = e;
      } finally {
        client.close(force: true);
      }
    }
    throw last ?? const SocketException('Overpass yanıt vermedi');
  }

  static String query(double lat, double lng, int radius) =>
      '[out:json][timeout:20];nwr["amenity"="place_of_worship"]["religion"="muslim"]'
      '(around:$radius,$lat,$lng);out center 60;';

  /// Yakındaki camiler, yakından uzağa. Az sonuç çıkarsa arama alanı genişletilir.
  Future<List<Mosque>> near(double lat, double lng) async {
    var list = <Mosque>[];
    for (final radius in const [1500, 4000, 10000]) {
      list = parse(await _fetch(query(lat, lng, radius)), lat, lng);
      if (list.length >= 5) break;
    }
    return list;
  }

  static List<Mosque> parse(Map<String, dynamic> j, double lat, double lng) {
    final out = <Mosque>[];
    for (final e in (j['elements'] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      final c = (m['center'] as Map<String, dynamic>?) ?? m;
      final la = (c['lat'] as num?)?.toDouble(), lo = (c['lon'] as num?)?.toDouble();
      if (la == null || lo == null) continue;
      final tags = (m['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      final name = ((tags['name:tr'] ?? tags['name']) as String?)?.trim();
      out.add(Mosque(
        name == null || name.isEmpty ? Mosque.unnamed : name,
        la,
        lo,
        LocationStore.distanceKm(lat, lng, la, lo),
        bearingDeg(lat, lng, la, lo),
      ));
    }
    out.sort((a, b) => a.km.compareTo(b.km));
    return out.take(40).toList();
  }
}

typedef PlacesFetcher = Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

/// En yakın camiler Google Haritalar'dan (Places API, Nearby Search). Anahtar derlemede verilir
/// (--dart-define=PLACES_KEY=…); yoksa ya da kişinin günlük arama hakkı bittiyse null döner ve
/// OpenStreetMap listesi kullanılır. Uygulama açıkken aynı yer için yeniden arama yapılmaz.
class GooglePlaces {
  static const key = String.fromEnvironment('PLACES_KEY');

  /// Kişi başı günlük arama hakkı (Google'ın ücretsiz kotasını korur).
  static const dailyLimit = 4;
  static const resultCount = 5;
  static const _dayKey = 'cami_google_gun', _countKey = 'cami_google_sayi';

  final String apiKey;
  final PlacesFetcher _fetch;

  GooglePlaces({String? apiKey, PlacesFetcher? fetch})
      : apiKey = apiKey ?? key,
        _fetch = fetch ?? _httpFetch(apiKey ?? key);

  bool get enabled => apiKey.isNotEmpty;

  static final _session = <String, List<Mosque>>{};

  // Testler için.
  static void clearSession() => _session.clear();

  static PlacesFetcher _httpFetch(String apiKey) => (body) async {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
        try {
          final req = await client.postUrl(Uri.parse('https://places.googleapis.com/v1/places:searchNearby'));
          req.headers.contentType = ContentType.json;
          req.headers.set('X-Goog-Api-Key', apiKey);
          req.headers.set('X-Goog-FieldMask', 'places.displayName,places.location');
          req.headers.set('X-Android-Package', 'com.ezansaati.app');
          req.write(jsonEncode(body));
          final res = await req.close().timeout(const Duration(seconds: 15));
          final text = await res.transform(utf8.decoder).join();
          if (res.statusCode != 200) throw HttpException('Places ${res.statusCode}');
          return jsonDecode(text) as Map<String, dynamic>;
        } finally {
          client.close(force: true);
        }
      };

  static Map<String, dynamic> request(double lat, double lng) => {
        'includedTypes': ['mosque'],
        'maxResultCount': resultCount,
        'rankPreference': 'DISTANCE',
        'languageCode': 'tr',
        'locationRestriction': {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': 10000.0,
          },
        },
      };

  /// En yakın camiler; Google kullanılamıyorsa null.
  Future<List<Mosque>?> near(double lat, double lng, {DateTime? now}) async {
    if (!enabled) return null;
    final place = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
    final cached = _session[place];
    if (cached != null) return cached;
    final p = await SharedPreferences.getInstance();
    final d = now ?? DateTime.now();
    final today = '${d.year}-${d.month}-${d.day}';
    final used = p.getString(_dayKey) == today ? (p.getInt(_countKey) ?? 0) : 0;
    if (used >= dailyLimit) return null;
    final Map<String, dynamic> j;
    try {
      j = await _fetch(request(lat, lng));
    } catch (_) {
      return null;
    }
    await p.setString(_dayKey, today);
    await p.setInt(_countKey, used + 1);
    final list = parse(j, lat, lng);
    _session[place] = list;
    return list;
  }

  static List<Mosque> parse(Map<String, dynamic> j, double lat, double lng) {
    final out = <Mosque>[];
    for (final e in (j['places'] as List? ?? const [])) {
      final m = e as Map<String, dynamic>;
      final loc = m['location'] as Map<String, dynamic>?;
      final la = (loc?['latitude'] as num?)?.toDouble(), lo = (loc?['longitude'] as num?)?.toDouble();
      if (la == null || lo == null) continue;
      final name = ((m['displayName'] as Map?)?['text'] as String?)?.trim();
      out.add(Mosque(name == null || name.isEmpty ? Mosque.unnamed : name, la, lo,
          LocationStore.distanceKm(lat, lng, la, lo), bearingDeg(lat, lng, la, lo)));
    }
    out.sort((a, b) => a.km.compareTo(b.km));
    return out;
  }
}
