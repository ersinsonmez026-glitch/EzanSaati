/// Namaz Öğren videoları: yalnızca Diyanet İşleri Başkanlığı'nın resmî YouTube kanallarından
/// (DiyanetTV, Diyanet Çocuk, Diyanet Dijital, TRT Diyanet Çocuk). Hepsinin gömülerek
/// oynatılabildiği YouTube oEmbed ile doğrulandı (28-29 Eylül 2026).
class NamazVideo {
  final String id; // YouTube video kimliği
  final String title;
  final String channel;
  final String duration;
  final String topic; // namaz_ogren.dart'taki namaz/konu anahtarı ya da 'bayram'

  const NamazVideo(this.id, this.title, this.channel, this.duration, this.topic);

  String get url => 'https://www.youtube.com/watch?v=$id';
  String get thumbnail => 'https://i.ytimg.com/vi/$id/mqdefault.jpg';
}

const kVideoTopics = {
  'abdest': 'Abdest',
  'sabah': 'Sabah Namazı',
  'ogle': 'Öğle Namazı',
  'ikindi': 'İkindi Namazı',
  'aksam': 'Akşam Namazı',
  'yatsi': 'Yatsı Namazı',
  'vitir': 'Vitir Namazı',
  'cuma': 'Cuma Namazı',
  'teravih': 'Teravih Namazı',
  'bayram': 'Bayram Namazı',
  'dualar': 'Namaz Duaları',
  'gusul': 'Gusül',
  'teyemmum': 'Teyemmüm',
};

const namazVideolari = <NamazVideo>[
  NamazVideo('nglUmluXEAE', 'Abdest Nasıl Alınır?', 'DiyanetTV', '3:27', 'abdest'),
  NamazVideo('vnUCPvWZLS8', 'Abdest Almak · Namaz Kılmayı Öğreniyorum 1. Bölüm', 'Diyanet Çocuk', '5:04', 'abdest'),
  NamazVideo('OQCaR6bS5fA', 'Sabah Namazı Nasıl Kılınır?', 'DiyanetTV', '12:20', 'sabah'),
  NamazVideo('-KMWx7zgHwY', 'Sabah Namazı · Namaz Kılmayı Öğreniyorum 2. Bölüm', 'Diyanet Çocuk', '9:49', 'sabah'),
  NamazVideo('8r3-Dc3xBiw', 'Öğle Namazı Nasıl Kılınır?', 'DiyanetTV', '24:30', 'ogle'),
  NamazVideo('CxnBsT_L3Kw', 'Öğle Namazı · Namaz Kılmayı Öğreniyorum 3. Bölüm', 'Diyanet Çocuk', '14:20', 'ogle'),
  NamazVideo('k7QyYEsJNrk', 'İkindi Namazı Nasıl Kılınır?', 'DiyanetTV', '18:32', 'ikindi'),
  NamazVideo('lyy3sP5AlWE', 'İkindi Namazı · Namaz Kılmayı Öğreniyorum 4. Bölüm', 'Diyanet Çocuk', '6:39', 'ikindi'),
  NamazVideo('RWBSdwhnzcg', 'Akşam Namazı Nasıl Kılınır?', 'DiyanetTV', '14:16', 'aksam'),
  NamazVideo('IHQnrD9gJeo', 'Akşam Namazı · Namaz Kılmayı Öğreniyorum 5. Bölüm', 'Diyanet Çocuk', '7:23', 'aksam'),
  NamazVideo('17ulcYz04Zg', 'Yatsı Namazı Nasıl Kılınır?', 'DiyanetTV', '28:08', 'yatsi'),
  NamazVideo('RKyl090YILc', 'Yatsı Namazı · Namaz Kılmayı Öğreniyorum 6. Bölüm', 'Diyanet Çocuk', '6:24', 'yatsi'),
  NamazVideo('8B7ZZgefZa8', 'Vitir Namazı Nasıl Kılınır?', 'DiyanetTV', '3:15', 'vitir'),
  NamazVideo('2qDWDcYDqzI', 'Cuma Namazı Nasıl Kılınır?', 'DiyanetTV', '6:29', 'cuma'),
  NamazVideo('qPxWcs_rBuc', 'Teravih Namazı Nasıl Kılınır? (Uygulamalı Anlatım)', 'DiyanetTV', '16:45', 'teravih'),
  NamazVideo('z1HITLrgeCk', 'Bayram Namazı Nasıl Kılınır?', 'Diyanet Dijital', '2:19', 'bayram'),
  NamazVideo('F4SN5A3zi8Y', 'Sübhâneke Duası', 'Diyanet Dijital · Elif Bâ', '0:53', 'dualar'),
  NamazVideo('L9IceGdzzJQ', 'Tahiyyât (Ettehiyyâtü) Duası', 'Diyanet Dijital · Elif Bâ', '1:27', 'dualar'),
  NamazVideo('r4-Bo5o_5EE', 'Salli Duası', 'Diyanet Dijital · Elif Bâ', '1:03', 'dualar'),
  NamazVideo('OWklgEzJxJ4', 'Bârik Duası', 'Diyanet Dijital · Elif Bâ', '1:03', 'dualar'),
  NamazVideo('g1AAOwgHAHk', 'Rabbenâ Âtinâ Duası', 'Diyanet Dijital · Elif Bâ', '0:42', 'dualar'),
  NamazVideo('JyajztAUuUk', 'Rabbenağfirlî Duası', 'Diyanet Dijital · Elif Bâ', '0:34', 'dualar'),
  NamazVideo('G4SKsQHP4ko', 'Kunut Duası 1', 'Diyanet Dijital · Elif Bâ', '1:12', 'dualar'),
  NamazVideo('TwvOFaNTfVY', 'Kunut Duası 2', 'Diyanet Dijital · Elif Bâ', '0:52', 'dualar'),
  NamazVideo('B67s_jO8qzI', 'Ezan Duası (Nusretiye Camii)', 'DiyanetTV', '1:29', 'dualar'),
  NamazVideo('Rh0YPTJD_H0', 'Gusül Abdesti Nasıl Alınır?', 'DiyanetTV', '5:50', 'gusul'),
  NamazVideo('flZozLiZyGY', 'Teyemmüm Nasıl Alınır?', 'TRT Diyanet Çocuk', '1:01', 'teyemmum'),
  NamazVideo('VsRRUmTdfR0', 'Teyemmüm Hangi Şartlarda Yapılır?', 'DiyanetTV', '2:15', 'teyemmum'),
];

List<NamazVideo> videosFor(String topic) => [
      for (final v in namazVideolari)
        if (v.topic == topic) v
    ];

/// Günlük duaların okunuş videoları. Diyanet'in bu dualar için videosu olmadığından YouTube'daki
/// başka kanallardan seçildi (kısa, dua metniyle aynı başlıklı okunuş videoları; hepsi gömülebilir).
/// Kanal adı her videonun altında gösterilir.
const gunlukDuaVideolari = <NamazVideo>[
  NamazVideo('KpuL7uXyn5c', 'Eûzü - Besmele', "Hakikat Kitabevi (Hafız Hüseyin Koç)", '0:27', 'gunluk'),
  NamazVideo('SA9eqFEtSvM', 'Rükû ve Secdede Tesbihat', "DiyanetTV", '1:16', 'gunluk'),
  NamazVideo('Jh-hq_xCOmw', 'Namazda Nasıl Selam Verilir', "Fıkıh Mektebi (İsmail Hünerlice)", '1:21', 'gunluk'),
  NamazVideo('Ob5iGRzblIY', "Allâhümme Ente's-Selâm", "Hafız Osman Şahin", '0:24', 'gunluk'),
  NamazVideo('Kba5pyL5xhs', 'Namazdan Sonra Tesbihat ve Dualar', "Alim Çocuk", '3:15', 'gunluk'),
  NamazVideo('7jxYrnzfBb4', "Seyyidü'l-İstiğfâr Duası", "Eyyüp Beyhan", '1:25', 'gunluk'),
  NamazVideo('7fMgIE0Hqlg', 'Bismillâhillezî Lâ Yedurru', "İslam ve İhsan", '0:41', 'gunluk'),
  NamazVideo('pTJ6-86R1GA', 'Radîtü Billâhi Rabben', "Muslimates", '0:51', 'gunluk'),
  NamazVideo('Clr_W6eDGXA', 'Allâhümme Bike Asbahnâ', "Muslimates", '0:29', 'gunluk'),
  NamazVideo('vjw0n9I8uZo', 'Sübhânallâhi ve Bihamdihî (100 kez)', "Mişari Râşid el-Afâsî", '5:49', 'gunluk'),
  NamazVideo('Y-TfaQiHcL8', "Eûzü bi-Kelimâtillâhi't-Tâmmât", "Kuran-MeaL", '0:34', 'gunluk'),
  NamazVideo('naOUISlnhoc', "Allâhümme İnnî Eûzü Bike min Zevâli Ni'metike", "Dualar", '1:05', 'gunluk'),
  NamazVideo('hR4UDSZIujI', 'Tuvalete Girerken Okunacak Dua', "Değer Çocuk", '1:01', 'gunluk'),
  NamazVideo(
      'VDLNevEcdJQ', "Es'elullâhe'l-Azîm... en Yeşfiyek", "Faziletli Ameller (İsmail Hünerlice)", '0:21', 'gunluk'),
  NamazVideo('J-OO3rIG1aQ', 'Kederden ve Borçtan Sığınma Duası', "Kuran-MeaL", '1:29', 'gunluk'),
  NamazVideo(
      'Vk6hfPrLCKU', "Lâ İlâhe İllallâhü'l-Azîmü'l-Halîm", "Background Recite & Memorise Quran", '10:53', 'gunluk'),
  NamazVideo('41_n1wzGAJc', 'İstiğfar Duası', "En Güzel Dualar", '1:48', 'gunluk'),
  NamazVideo('uh30uohqTow', "Yâ Mukallibe'l-Kulûb", "SM Quran Academy", '3:57', 'gunluk'),
  NamazVideo('g0_mQRyLUzY', "Allâhümme İnnî Es'elüke'l-Hüdâ", "Dualar", '1:03', 'gunluk'),
  NamazVideo('Y-Ia5fkjhXI', 'Allâhümme Eınnî alâ Zikrike', "Şiir Gibi Yaşamak", '0:43', 'gunluk'),
  NamazVideo('703ck8EYMrA', "Allâhümme İnnî Es'elüke İlmen Nâfiâ", "Ilm un Nafi", '1:12', 'gunluk'),
  NamazVideo('V1OKSBn_dIM', 'Camiye Girerken ve Çıkarken Okunacak Dua', "İlim Akademisi", '0:59', 'gunluk'),
  NamazVideo('SiP3d4ufUqw', 'Evden Çıkarken Okunacak Dua', "Akra", '1:04', 'gunluk'),
  NamazVideo('Qw4mhJlB7F4', 'Uyanınca Okunacak Dua', "Nebî'nin Duaları", '0:52', 'gunluk'),
];

/// Kimliği verilen video (namaz ya da günlük dua videoları arasında).
NamazVideo? videoById(String id) {
  for (final v in [...namazVideolari, ...gunlukDuaVideolari]) {
    if (v.id == id) return v;
  }
  return null;
}
