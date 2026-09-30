import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ana ekran tuş görünümü: görselli, krem veya yeşil. (Sıra kayıtlı ayarla uyumlu kalsın diye değişmez.)
enum TileStyle { resimli, krem, yesil }

extension TileStyleName on TileStyle {
  String get label => switch (this) {
        TileStyle.resimli => 'Görsel',
        TileStyle.krem => 'Krem',
        TileStyle.yesil => 'Yeşil',
      };
}

/// Gündüz (krem) / gece (yeşil) görünümü: otomatik vakte göre ya da kullanıcının seçtiği.
enum DayMode { otomatik, gunduz, gece }

extension DayModeName on DayMode {
  String get label => switch (this) {
        DayMode.otomatik => 'Otomatik',
        DayMode.gunduz => 'Gündüz',
        DayMode.gece => 'Gece',
      };
}

/// Görünüm tercihlerini saklar. `AppPrefs.instance` ile her yerden ulaşılır.
class AppPrefs extends ChangeNotifier {
  AppPrefs._();
  static final AppPrefs instance = AppPrefs._();

  static const _kTile = 'tile_style';
  static const _kDay = 'day_mode';
  static const _kReciter = 'kari';
  static const defaultReciterId = 'ar.mahermuaiqly';
  String _reciterId = defaultReciterId;

  /// Kur'an sesinde seçili kârînin kimliği (bkz. kQuranReciters).
  String get reciterId => _reciterId;
  TileStyle _tileStyle = TileStyle.resimli;
  TileStyle get tileStyle => _tileStyle;
  DayMode _dayMode = DayMode.otomatik;
  DayMode get dayMode => _dayMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt(_kTile);
    if (i != null && i >= 0 && i < TileStyle.values.length) {
      _tileStyle = TileStyle.values[i];
      notifyListeners();
    }
    final r = prefs.getString(_kReciter);
    if (r != null && r.isNotEmpty) {
      _reciterId = r;
      notifyListeners();
    }
    final d = prefs.getInt(_kDay);
    if (d != null && d >= 0 && d < DayMode.values.length) {
      _dayMode = DayMode.values[d];
      notifyListeners();
    }
  }

  Future<void> setDayMode(DayMode m) async {
    _dayMode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDay, m.index);
  }

  Future<void> setTileStyle(TileStyle s) async {
    _tileStyle = s;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTile, s.index);
  }

  Future<void> setReciter(String id) async {
    _reciterId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReciter, id);
  }
}
