import 'dart:convert';

import 'package:flutter/services.dart';

/// Hadisler: Diyanet İşleri Başkanlığı, "Hadislerle İslâm" (hadislerleislam.diyanet.gov.tr) eserinde
/// Hz. Peygamber'in sözü olarak tırnak içinde verilen ve dipnotta Kütüb-i Sitte'ye (Buhârî, Müslim,
/// Ebû Dâvûd, Tirmizî, Nesâî, İbn Mâce) dayandırılan hadisler; eserdeki konu başlıklarına göre.
/// Liste: assets/data/hadisler.json ([metin, kaynak, cilt, sayfa, konu]). Metin değiştirilmez (yalnız
/// sitedeki " işareti kesme işaretine ’ çevrildi); eksik ya da bağlamsız cümleler alınmadı.
class Hadith {
  final String id;
  final String text;
  final String attribution; // eserdeki dipnot: kitap, bölüm, bab
  final int cilt;
  final int sayfa;
  final String topic; // eserdeki konu başlığı

  const Hadith(
      {required this.id,
      required this.text,
      required this.attribution,
      required this.cilt,
      required this.sayfa,
      required this.topic});

  /// Listede başlık olarak hadisin kendisi gösterilir.
  String get title => text;

  String get book => 'Hadislerle İslâm, $cilt/$sayfa';

  String get url => 'https://hadislerleislam.diyanet.gov.tr/sayfa.php?CILT=$cilt&SAYFA=$sayfa';

  String get shareText => '“$text”\n\n($attribution)\nKaynak: Diyanet İşleri Başkanlığı, $book – $url';
}

const kHadithFavKey = 'hadis_fav';

class HadithStore {
  const HadithStore();

  static Future<List<Hadith>>? _all;

  /// Bir kez yüklenir. Kimlik "cilt-sayfa-sıra": liste büyüse de favoriler korunur.
  static Future<List<Hadith>> all() => _all ??= _load();

  static Future<List<Hadith>> _load() async {
    final rows = jsonDecode(await rootBundle.loadString('assets/data/hadisler.json')) as List;
    final seen = <String, int>{};
    return [
      for (final r in rows.cast<List>())
        () {
          final base = '${r[2]}-${r[3]}';
          final n = seen[base] = (seen[base] ?? 0) + 1;
          return Hadith(
              id: '$base-$n',
              text: r[0] as String,
              attribution: r[1] as String,
              cilt: r[2] as int,
              sayfa: r[3] as int,
              topic: r[4] as String);
        }(),
    ];
  }

  Future<List<Hadith>> cached() => all();

  Future<List<Hadith>> load({bool force = false}) => all();
}
