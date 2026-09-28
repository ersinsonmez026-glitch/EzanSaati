/// Sûrelerin sesli okunuşu: internetten akış (uygulamaya ses dosyası gömülmez).
///
/// Kaynak: Islamic Network / Al Quran Cloud ses CDN'i (https://alquran.cloud/cdn).
/// Kullanım şartları (https://alquran.cloud/terms-and-conditions, 14 Haziran 2026):
/// "Recitations are licensed to us by the reciters or their estates for free,
/// non-commercial redistribution at the bitrates we publish. You may stream, embed
/// and download them for personal and educational use." Telif kârîye aittir.
/// 114 sûrenin tamamı erişilebilir olarak doğrulandı (128 kbps).
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
}

const kQuranReciter = QuranReciter('ar.alafasy', 'Mişari Râşid el-Afâsî', 'Murattal', 128);

const kQuranAudioSource = 'Ses: Mişari Râşid el-Afâsî (murattal) · Islamic Network / alquran.cloud — '
    'kişisel ve eğitim amaçlı akış izni; telif kârîye aittir.';
