import 'dart:convert';

import 'package:flutter/services.dart';

/// İlahiler ekranındaki bir kayıt. Kaynak ve lisans bilgisi zorunludur
/// (bkz. docs/ILAHILER_LISANS.md).
class Ilahi {
  final String id;
  final String title;
  final String performer;
  final String asset; // assets/audio/ilahiler/... ses dosyası
  final int seconds;
  final String source; // ör. Freesound, Wikimedia Commons
  final String page; // kaynak sayfası
  final String license; // ör. CC BY 3.0
  final String licenseUrl;
  final String note; // telif durumuyla ilgili açıklama

  const Ilahi({
    required this.id,
    required this.title,
    required this.performer,
    required this.asset,
    required this.seconds,
    required this.source,
    required this.page,
    required this.license,
    this.licenseUrl = '',
    this.note = '',
  });

  factory Ilahi.fromJson(Map<String, dynamic> j) => Ilahi(
        id: j['id'] as String,
        title: j['baslik'] as String,
        performer: j['okuyan'] as String? ?? '',
        asset: j['dosya'] as String,
        seconds: (j['sure'] as num?)?.toInt() ?? 0,
        source: j['kaynak'] as String,
        page: j['sayfa'] as String,
        license: j['lisans'] as String,
        licenseUrl: j['lisans_url'] as String? ?? '',
        note: j['not'] as String? ?? '',
      );

  /// Ekranda gösterilen kaynak satırı.
  String get credit => [
        if (performer.isNotEmpty) performer,
        '$source · $license',
      ].join(' — ');
}

class IlahiData {
  static const path = 'assets/data/ilahiler.json';
  static Future<List<Ilahi>>? _cache;

  /// Kaynağı ya da lisansı eksik kayıtlar listeye alınmaz.
  static Future<List<Ilahi>> load() => _cache ??= rootBundle.loadString(path).then((s) {
        final list = (jsonDecode(s) as Map<String, dynamic>)['kayitlar'] as List;
        return [
          for (final j in list)
            if (_complete(j as Map<String, dynamic>)) Ilahi.fromJson(j),
        ];
      });

  static bool _complete(Map<String, dynamic> j) => ['id', 'baslik', 'dosya', 'kaynak', 'sayfa', 'lisans']
      .every((k) => (j[k] as String?)?.trim().isNotEmpty ?? false);
}
