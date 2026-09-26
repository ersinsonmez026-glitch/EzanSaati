import 'package:flutter/material.dart';

/// Uygulamanın ortak renkleri. Bir rengi değiştirmek için sadece burayı düzenle.
class AppColors {
  static const Color cream = Color(0xFFF3E6C8);
  static const Color darkGreen = Color(0xFF002215);
  static const Color green = Color(0xFF003B25);
  static const Color greenSurface = Color(0xFF002B1B);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF5DE96);
  static const Color mint = Color(0xFF00FFB2);
}

/// Koyu yeşil sayfaların ortak üst çubuğu.
PreferredSizeWidget goldAppBar(String title, {List<Widget>? actions}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: AppColors.gold,
    centerTitle: true,
    title: Text(
      title,
      style: const TextStyle(
        color: AppColors.gold,
        fontFamily: 'serif',
        fontWeight: FontWeight.w700,
      ),
    ),
    actions: actions,
  );
}
