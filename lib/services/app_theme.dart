import 'package:flutter/painting.dart';

/// Renk teması (Premium). Yalnız koyu yeşil zeminler değişir; altın süslemeler, krem yazılar, gündüz
/// (krem) görünümü ve fotoğraflar her temada aynı kalır.
enum AppTheme { zumrut, geceMavisi, bordo, kahve }

extension AppThemeName on AppTheme {
  String get label => switch (this) {
        AppTheme.zumrut => 'Zümrüt',
        AppTheme.geceMavisi => 'Gece mavisi',
        AppTheme.bordo => 'Bordo',
        AppTheme.kahve => 'Kahve',
      };

  /// Temaya göre boyanmış görsellerin dosya adı eki (levha, vakit kartları): levha_bordo.webp gibi.
  String get assetSuffix => switch (this) {
        AppTheme.zumrut => '',
        AppTheme.geceMavisi => '_mavi',
        AppTheme.bordo => '_bordo',
        AppTheme.kahve => '_kahve',
      };

  /// Temanın örnek zemin rengi (seçim düğmelerinde).
  Color get swatch => themedColor(0xFF0A3525, this);
}

/// Şu an kullanılan tema (Premium yoksa hep Zümrüt). [AppPrefs] günceller.
AppTheme activeTheme = AppTheme.zumrut;

const _hue = {AppTheme.geceMavisi: 220.0, AppTheme.bordo: 353.0, AppTheme.kahve: 25.0};
const _sat = {AppTheme.geceMavisi: 0.95, AppTheme.bordo: 0.9, AppTheme.kahve: 0.8};
final _cache = <(int, AppTheme), Color>{};

/// Yeşil zeminli görselin seçili temadaki hâli: 'assets/images/levha.webp' → '…/levha_bordo.webp'.
String themedAsset(String path) {
  final i = path.lastIndexOf('.');
  return '${path.substring(0, i)}${activeTheme.assetSuffix}${path.substring(i)}';
}

/// Uygulamanın yeşil rengini seçili temaya çevirir (Zümrüt'te aynen döner).
Color tc(int argb) => themedColor(argb, activeTheme);

Color themedColor(int argb, AppTheme theme) {
  final c = Color(argb);
  if (theme == AppTheme.zumrut) return c;
  return _cache.putIfAbsent((argb, theme), () {
    final hsv = HSVColor.fromColor(c);
    // Yalnız yeşil tonlar (altın, krem, beyaz dokunulmaz).
    if (hsv.hue < 108 || hsv.hue > 188 || hsv.saturation < 0.2) return c;
    return hsv.withHue(_hue[theme]!).withSaturation((hsv.saturation * _sat[theme]!).clamp(0.0, 1.0)).toColor();
  });
}
