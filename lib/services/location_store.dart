import 'dart:math' as math;
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' show Geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cities.dart';

/// Uygulamanın kullandığı konum (seçilen il ya da GPS konumu).
class AppLocation {
  final String name;
  final double lat;
  final double lng;
  final bool fromGps;

  /// GPS ile bulunduysa ilçe ya da mahalle adı (telefonun adres çözümleyicisinden); yoksa boş.
  final String district;

  const AppLocation({
    required this.name,
    required this.lat,
    required this.lng,
    this.fromGps = false,
    this.district = '',
  });
}

/// Konumu saklar ve değiştiğinde ekranlara haber verir.
/// Her yerden `LocationStore.instance` ile ulaşılır.
class LocationStore extends ChangeNotifier {
  LocationStore._();
  static final LocationStore instance = LocationStore._();

  static const _kName = 'loc_name';
  static const _kLat = 'loc_lat';
  static const _kLng = 'loc_lng';
  static const _kGps = 'loc_gps';
  static const _kDistrict = 'loc_ilce';

  AppLocation? _current;

  /// Henüz konum seçilmediyse null döner.
  AppLocation? get current => _current;

  /// Uygulama açılışında kayıtlı konumu yükler.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName);
    final lat = prefs.getDouble(_kLat);
    final lng = prefs.getDouble(_kLng);
    if (name != null && lat != null && lng != null) {
      _current = AppLocation(
        name: name,
        lat: lat,
        lng: lng,
        fromGps: prefs.getBool(_kGps) ?? false,
        district: prefs.getString(_kDistrict) ?? '',
      );
      notifyListeners();
    }
  }

  Future<void> _save(AppLocation loc) async {
    _current = loc;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, loc.name);
    await prefs.setDouble(_kLat, loc.lat);
    await prefs.setDouble(_kLng, loc.lng);
    await prefs.setBool(_kGps, loc.fromGps);
    await prefs.setString(_kDistrict, loc.district);
  }

  /// Listeden il seçildiğinde çağrılır.
  Future<void> setCity(City city) {
    return _save(AppLocation(name: city.name, lat: city.lat, lng: city.lng));
  }

  /// Telefonun GPS'inden konum alır.
  /// Başarılıysa null, hata olursa kullanıcıya gösterilecek mesajı döner.
  Future<String?> updateFromGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Telefonun konum servisi kapalı. Lütfen konumu açıp tekrar deneyin.';
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return 'Konum izni verilmedi. Şehrinizi listeden seçebilirsiniz.';
      }
      if (permission == LocationPermission.deniedForever) {
        return 'Konum izni kalıcı olarak kapatılmış. Ayarlardan izin verebilir '
            'ya da şehrinizi listeden seçebilirsiniz.';
      }

      // Namaz vakti için ilçe düzeyi yeterli: SIM'siz, yalnız Wi-Fi'lı telefonda da konum bulunsun diye
      // önce ağ (Wi-Fi) konumu, olmazsa telefonun bildiği son konum, en son uydu (GPS) denenir.
      Position? pos;
      for (final (acc, sec) in const [(LocationAccuracy.low, 15), (LocationAccuracy.medium, 25)]) {
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: LocationSettings(accuracy: acc, timeLimit: Duration(seconds: sec)),
          );
          break;
        } catch (e) {
          debugPrint('Konum denemesi ($acc): $e');
          pos ??= await Geolocator.getLastKnownPosition();
          if (pos != null) break;
        }
      }
      if (pos == null) throw StateError('konum yok');

      final nearest = nearestCity(pos.latitude, pos.longitude);
      final km = distanceKm(pos.latitude, pos.longitude, nearest.lat, nearest.lng);
      await _save(AppLocation(
        name: km < 150 ? nearest.name : 'Konumum',
        lat: pos.latitude,
        lng: pos.longitude,
        fromGps: true,
        district: await _district(pos.latitude, pos.longitude),
      ));
      return null;
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
      return 'Konum alınamadı. Telefonun Ayarlar › Konum bölümünde "Google Konum Doğruluğu" (Wi-Fi ile konum) '
          'açıkken tekrar deneyin ya da şehrinizi listeden seçin.';
    }
  }

  /// Konumun ilçe adı, yoksa mahalle adı (telefonun kendi adres çözümleyicisi; internet gerekir, ücretsiz).
  /// Bulunamazsa boş: ana ekranda yalnız il adı görünür.
  static Future<String> _district(double lat, double lng) async {
    try {
      final places = await Geocoding(locale: const Locale('tr', 'TR'))
          .placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 8));
      for (final p in places) {
        for (final n in [p.subAdministrativeArea, p.subLocality, p.locality]) {
          final t = (n ?? '').trim();
          if (t.isNotEmpty && !RegExp(r'^\d').hasMatch(t)) return t;
        }
      }
    } catch (e) {
      debugPrint('İlçe adı alınamadı: $e');
    }
    return '';
  }

  /// Verilen koordinata en yakın il.
  static City nearestCity(double lat, double lng) {
    City best = turkishCities.first;
    double bestKm = double.infinity;
    for (final c in turkishCities) {
      final d = distanceKm(lat, lng, c.lat, c.lng);
      if (d < bestKm) {
        bestKm = d;
        best = c;
      }
    }
    return best;
  }

  /// İki nokta arası kuş uçuşu mesafe (km).
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }
}
