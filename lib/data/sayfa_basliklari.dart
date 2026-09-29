/// Sayfa başlığındaki alt yazı ve sağdaki ayet. Ayet metinleri uygulamadaki Kur'an mealinden
/// (Ruvvâd Tercüme Merkezi, QuranEnc.com) birebir alınmıştır; atlanan yerler "…" ile gösterilir.
class PageHeading {
  final String subtitle;
  final String? verse;
  final String? source;

  const PageHeading(this.subtitle, [this.verse, this.source]);
}

const kSayfaBasliklari = <String, PageHeading>{
  'Namaz Vakitleri': PageHeading(
    'Vakitleri kaçırmayın',
    '…Namaz şüphesiz iman edenlere belirli vakitlerde farz kılınmıştır.',
    'Nisâ, 103',
  ),
  'Sureler': PageHeading(
    'Rahmet ve hidayet rehberiniz',
    'Kur’an’dan müminler için şifa ve rahmet olan şeyleri indiriyoruz…',
    'İsrâ, 82',
  ),
  'Dualar': PageHeading('Namaz ve günlük dualar', '“Bana dua edin, size icabet edeyim…”', "Mü'min, 60"),
  'Zikir Sayacı': PageHeading(
    'Tesbih ve zikirlerinizi sayın',
    '…Bilesiniz ki, kalpler ancak Allah’ı zikretmekle huzur bulur.',
    "Ra'd, 28",
  ),
  'Kıble': PageHeading(
    'Kıble yönünü bulun',
    '…Sizler nerede olursanız olun, (namazda) yüzünüzü ona doğru çevirin…',
    'Bakara, 144',
  ),
  'Cami Bulucu': PageHeading(
    'Yakınınızdaki camiler',
    'Allah’ın mescitlerini sadece Allah’a ve ahiret gününe iman eden… imar eder.',
    'Tevbe, 18',
  ),
  'Dua Zinciri': PageHeading(
    'Sevdiklerinizle birlikte okuyun',
    '…İyilik ve takva hususunda birbirinize yardımcı olun…',
    'Mâide, 2',
  ),
  'Hadisler': PageHeading(
    'Peygamberimizin sözleri',
    'Andolsun Allah’ın Rasûlünde… güzel bir örnek vardır.',
    'Ahzâb, 21',
  ),
  'Ramazan': PageHeading(
    'On bir ayın sultanı',
    'Ramazan ayı… Kur’an’ın indirildiği aydır…',
    'Bakara, 185',
  ),
  'Namaz Öğren': PageHeading(
    'Adım adım namaz',
    '…Bana ibadet et, beni anmak için namazı ikame et.',
    'Tâhâ, 14',
  ),
  'Dini Mesajlar': PageHeading(
    'Güzel sözlerle paylaşın',
    'Rabbinin yoluna hikmetle, güzel öğütle çağır…',
    'Nahl, 125',
  ),
  'Ayarlar': PageHeading('Uygulamayı kendinize göre ayarlayın'),
};
