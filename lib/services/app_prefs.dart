import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ana ekran tuş görünümü: resimli, krem veya yeşil.
enum TileStyle { resimli, krem, yesil }

extension TileStyleName on TileStyle {
  String get label => switch (this) {
        TileStyle.resimli => 'Resimli',
        TileStyle.krem => 'Krem',
        TileStyle.yesil => 'Yeşil',
      };
}

/// Görünüm tercihlerini saklar. `AppPrefs.instance` ile her yerden ulaşılır.
class AppPrefs extends ChangeNotifier {
  AppPrefs._();
  static final AppPrefs instance = AppPrefs._();

  static const _kTile = 'tile_style';
  TileStyle _tileStyle = TileStyle.resimli;
  TileStyle get tileStyle => _tileStyle;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt(_kTile);
    if (i != null && i >= 0 && i < TileStyle.values.length) {
      _tileStyle = TileStyle.values[i];
      notifyListeners();
    }
  }

  Future<void> setTileStyle(TileStyle s) async {
    _tileStyle = s;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTile, s.index);
  }
}
