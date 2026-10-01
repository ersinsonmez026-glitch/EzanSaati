import '../data/gunun_sozu.dart';

/// Hadisler: Diyanet İşleri Başkanlığı, "Hadislerle İslâm" (hadislerleislam.diyanet.gov.tr) eserinde
/// Hz. Peygamber'in sözü olarak verilen ve dipnotta Kütüb-i Sitte'ye dayandırılan kısa hadisler
/// (liste: lib/data/gunun_sozu.dart). Metinler değiştirilmez; uygulamanın içindedir, internet gerekmez.
class Hadith {
  final String id;
  final String text;
  final String attribution; // eserdeki dipnot: kitap, bölüm, bab
  final String book; // Hadislerle İslâm, cilt/sayfa
  final String url;

  const Hadith({required this.id, required this.text, required this.attribution, required this.book, required this.url});

  factory Hadith.of(int i, DailyHadith d) =>
      Hadith(id: 'dy${i + 1}', text: d.text, attribution: d.source, book: d.book, url: d.url);

  /// Listede başlık olarak hadisin kendisi gösterilir (hepsi kısa).
  String get title => text;

  String get shareText => '“$text”\n\n($attribution)\nKaynak: Diyanet İşleri Başkanlığı, $book – $url';
}

const kHadithFavKey = 'hadis_fav';

final List<Hadith> kHadiths = [for (var i = 0; i < kDailyHadiths.length; i++) Hadith.of(i, kDailyHadiths[i])];

class HadithStore {
  const HadithStore();

  Future<List<Hadith>> cached() async => kHadiths;

  Future<List<Hadith>> load({bool force = false}) async => kHadiths;
}
