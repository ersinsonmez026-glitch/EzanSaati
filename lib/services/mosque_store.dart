import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'location_store.dart';

/// Yakındaki cami (OpenStreetMap).
class Mosque {
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
        name == null || name.isEmpty ? 'Cami (adı kayıtlı değil)' : name,
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
