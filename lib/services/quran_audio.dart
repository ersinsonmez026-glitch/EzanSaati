/// Sûrelerin sesli okunuşu: internetten akış (uygulamaya ses dosyası gömülmez).
///
/// Kaynak: Islamic Network / Al Quran Cloud ses CDN'i (https://alquran.cloud/cdn).
/// Kullanım şartları (https://alquran.cloud/terms-and-conditions, 14 Haziran 2026):
/// "Recitations are licensed to us by the reciters or their estates for free,
/// non-commercial redistribution at the bitrates we publish. You may stream, embed
/// and download them for personal and educational use." Telif kârîye aittir.
///
/// Sûreler ayet ayet çalınır (aynı kaynak, aynı kârî): her ayet ayrı dosya olduğundan
/// okunan ayet kesin bilinir ve metinde vurgulanır. API ayet zaman kodu vermiyor; sûre
/// dosyaları ise bazı sûrelerde ayet dosyalarından farklı bir kayıt (28 Eylül 2026 ölçümü).
/// 6236 ayet dosyasının her sûrenin ilk ve son ayetinde erişilebilir olduğu doğrulandı (128 kbps).
class QuranReciter {
  final String id; // CDN'deki sürüm kimliği
  final String name;
  final String style;
  final int bitrate;

  const QuranReciter(this.id, this.name, this.style, this.bitrate);

  /// Bir sûrenin tam ses dosyasının adresi (1–114).
  Uri surahUrl(int surah) {
    assert(surah >= 1 && surah <= 114);
    return Uri.parse('https://cdn.islamic.network/quran/audio-surah/$bitrate/$id/$surah.mp3');
  }

  /// Tek bir ayetin ses dosyası; [number] Kur'an genelindeki sıra numarasıdır (1–6236).
  Uri ayahUrl(int number) {
    assert(number >= 1 && number <= kTotalAyahs);
    return Uri.parse('https://cdn.islamic.network/quran/audio/$bitrate/$id/$number.mp3');
  }
}

const kQuranReciter = QuranReciter('ar.alafasy', 'Mişari Râşid el-Afâsî', 'Murattal', 128);

const kQuranAudioSource = 'Ses: Mişari Râşid el-Afâsî (murattal) · Islamic Network / alquran.cloud — '
    'kişisel ve eğitim amaçlı akış izni; telif kârîye aittir.';

/// Sûrelerin ayet sayıları (Hafs, Tanzil ile aynı; toplam 6236).
const kSurahAyahCounts = <int>[
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135, //
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, //
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, //
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, //
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, //
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
];

const kTotalAyahs = 6236;

final List<int> _firstAyah = () {
  final r = <int>[];
  var n = 1;
  for (final c in kSurahAyahCounts) {
    r.add(n);
    n += c;
  }
  return r;
}();

/// Ayetin Kur'an genelindeki sıra numarası (ör. 2:255 → 262).
int globalAyahNumber(int surah, int ayah) {
  assert(surah >= 1 && surah <= 114 && ayah >= 1 && ayah <= kSurahAyahCounts[surah - 1]);
  return _firstAyah[surah - 1] + ayah - 1;
}

/// Bir sûrenin ayet ayet çalma listesi. Fâtiha ve Tevbe dışındaki sûrelerde başa besmele
/// eklenir (ayet dosyalarında besmele yok; besmele kaydı Fâtiha'nın 1. ayetidir).
class SurahPlaylist {
  final int surah;
  final QuranReciter reciter;

  const SurahPlaylist(this.surah, [this.reciter = kQuranReciter]);

  bool get hasBasmala => surah != 1 && surah != 9;
  int get ayahCount => kSurahAyahCounts[surah - 1];
  int get length => ayahCount + (hasBasmala ? 1 : 0);

  List<Uri> get urls => [
        if (hasBasmala) reciter.ayahUrl(1),
        for (var a = 1; a <= ayahCount; a++) reciter.ayahUrl(globalAyahNumber(surah, a)),
      ];

  /// Listedeki sıradan ayet numarası; 0 = besmele.
  int ayahAt(int index) => hasBasmala ? index : index + 1;

  /// Ayetin listedeki sırası. 1. ayetten başlarken besmele de okunur.
  int indexOf(int ayah) => ayah <= 1 ? 0 : (hasBasmala ? ayah : ayah - 1);
}

/// Kur'an'dan bir duanın ses listesi: verilen ayet aralıkları sırayla. Sûrenin tamamı okunuyorsa
/// (zamm-ı sureler) başa besmele eklenir (Fâtiha ve Tevbe hariç).
List<Uri> duaAudioUrls(List<(int, int, int)> refs, [QuranReciter reciter = kQuranReciter]) => [
      for (final (s, a1, a2) in refs) ...[
        if (a1 == 1 && a2 == kSurahAyahCounts[s - 1] && s != 1 && s != 9) reciter.ayahUrl(1),
        for (var a = a1; a <= a2; a++) reciter.ayahUrl(globalAyahNumber(s, a)),
      ],
    ];
