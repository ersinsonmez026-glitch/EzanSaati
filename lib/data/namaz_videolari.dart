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
