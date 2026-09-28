// Namaz Öğren içeriği. Metinler onaylı tasarımdaki (onizleme/05-namaz-ogren.html) anlatımın
// aynısıdır. Anlatımlar Hanefî mezhebine ve Türkiye'deki uygulamaya göredir.
// Adımların altındaki dualar assets/data/namaz_dualari.json dosyasından başlığa göre alınır.

/// Namazın bir bölümünün türü.
enum PartType {
  sunnahMuakkad, // müekked sünnet
  sunnahGhayr, // gayr-i müekked sünnet
  fard, // farz
  witr, // vitir (vacip)
}

class NamazPart {
  final String name; // "Sünnet", "Farz", "İlk Sünnet" ...
  final int rakats;
  final PartType type;

  const NamazPart(this.name, this.rakats, this.type);
}

class Namaz {
  final String key;
  final String title;
  final String shortTitle; // sol listede
  final String description;
  final int? vakit; // vakit sırası: 0 İmsak, 2 Öğle, 3 İkindi, 4 Akşam, 5 Yatsı
  final List<NamazPart> parts;

  const Namaz(this.key, this.title, this.shortTitle, this.description, this.vakit, this.parts);
}

const namazlar = <Namaz>[
  Namaz('sabah', 'Sabah Namazı', 'Sabah', '2 rekât sünnet + 2 rekât farz', 0, [
    NamazPart('Sünnet', 2, PartType.sunnahMuakkad),
    NamazPart('Farz', 2, PartType.fard),
  ]),
  Namaz('ogle', 'Öğle Namazı', 'Öğle', '4 sünnet + 4 farz + 2 son sünnet', 2, [
    NamazPart('İlk Sünnet', 4, PartType.sunnahMuakkad),
    NamazPart('Farz', 4, PartType.fard),
    NamazPart('Son Sünnet', 2, PartType.sunnahMuakkad),
  ]),
  Namaz('ikindi', 'İkindi Namazı', 'İkindi', '4 rekât sünnet + 4 rekât farz', 3, [
    NamazPart('Sünnet', 4, PartType.sunnahGhayr),
    NamazPart('Farz', 4, PartType.fard),
  ]),
  Namaz('aksam', 'Akşam Namazı', 'Akşam', '3 rekât farz + 2 rekât sünnet', 4, [
    NamazPart('Farz', 3, PartType.fard),
    NamazPart('Sünnet', 2, PartType.sunnahMuakkad),
  ]),
  Namaz('yatsi', 'Yatsı Namazı', 'Yatsı', '4 sünnet + 4 farz + 2 son sünnet + 3 vitir', 5, [
    NamazPart('İlk Sünnet', 4, PartType.sunnahGhayr),
    NamazPart('Farz', 4, PartType.fard),
    NamazPart('Son Sünnet', 2, PartType.sunnahMuakkad),
    NamazPart('Vitir', 3, PartType.witr),
  ]),
  Namaz('cuma', 'Cuma Namazı', 'Cuma', '4 ilk sünnet + 2 farz (cemaatle) + 4 son sünnet', null, [
    NamazPart('İlk Sünnet', 4, PartType.sunnahMuakkad),
    NamazPart('Farz', 2, PartType.fard),
    NamazPart('Son Sünnet', 4, PartType.sunnahMuakkad),
  ]),
  Namaz('vitir', 'Vitir Namazı', 'Vitir', '3 rekât (vacip) · Yatsıdan sonra', null, [
    NamazPart('Vitir', 3, PartType.witr),
  ]),
  Namaz('teravih', 'Teravih Namazı', 'Teravih', "20 rekât sünnet · Ramazan'da yatsıdan sonra", null, [
    NamazPart('2 Rekât', 2, PartType.sunnahMuakkad),
  ]),
];

/// Namaz türü açıklaması (başlığın altında).
String partSubtitle(Namaz n, NamazPart p) {
  if (n.key == 'teravih') return '20 rekât · Her 2 rekâtta bir selam verilir (10 kez)';
  final extra = switch (p.type) {
    PartType.sunnahGhayr => ' (gayr-i müekked)',
    PartType.witr => ' (vacip)',
    _ => '',
  };
  return '${p.name} · ${p.rakats} rekât$extra';
}

String _lowerTr(String s) => s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

String niyetText(Namaz n, NamazPart p) {
  if (n.key == 'vitir' || p.type == PartType.witr) {
    return 'Niyet ettim Allah rızası için vitir namazını kılmaya.';
  }
  if (n.key == 'teravih') return 'Niyet ettim Allah rızası için teravih namazını kılmaya.';
  if (n.key == 'cuma' && p.type == PartType.fard) {
    return 'Niyet ettim Allah rızası için cuma namazının farzını kılmaya, uydum hazır olan imama.';
  }
  final name = _lowerTr(n.title.replaceAll(' Namazı', ''));
  final part = _lowerTr(p.name);
  final which = part == 'farz'
      ? 'farzını'
      : part == 'son sünnet'
          ? 'son sünnetini'
          : part == 'ilk sünnet'
              ? 'ilk sünnetini'
              : 'sünnetini';
  return 'Niyet ettim Allah rızası için bugünkü $name namazının $which kılmaya.';
}

/// Adım adım anlatımdaki bir satır. [rakat] doluysa bu bir "n. Rekât" ara başlığıdır.
class NamazStep {
  final int? rakat;
  final String pose; // duruş görseli: assets/images/namaz/p_<pose>.webp
  final String title;
  final String description;
  final List<String> duas; // namaz_dualari.json başlıkları
  final String? niyet;
  final bool pickSurah; // zamm-ı sure seçimi

  const NamazStep.rakat(int this.rakat)
      : pose = '',
        title = '',
        description = '',
        duas = const [],
        niyet = null,
        pickSurah = false;

  const NamazStep(this.pose, this.title, this.description,
      {this.duas = const [], this.niyet, this.pickSurah = false})
      : rakat = null;

  bool get hasDetails => duas.isNotEmpty || niyet != null || pickSurah;
}

/// Duruş görselleri (onaylı tasarımdaki eşleşme; zamm-ı sure kıyam görseliyle gösterilir).
const poseImages = {
  'niyet': 'p_niyet',
  'tekbir': 'p_tekbir',
  'kiyam': 'p_kiyam',
  'zamm': 'p_kiyam',
  'ruku': 'p_ruku',
  'kavme': 'p_kavme',
  'secde': 'p_secde',
  'celse': 'p_celse',
  'kade': 'p_kade',
  'kalk': 'p_kalk',
  'selam': 'p_selam',
  'dua': 'p_dua',
};

/// Zamm-ı sure olarak seçilebilen sureler (namaz_dualari.json'da bulunanlar).
const zammSurahs = [
  'İhlâs Sûresi',
  'Kevser Sûresi',
  'Fîl Sûresi',
  'Kureyş Sûresi',
  'Mâûn Sûresi',
  'Kâfirûn Sûresi',
  'Nasr Sûresi',
  'Tebbet Sûresi',
  'Felak Sûresi',
  'Nâs Sûresi',
];

/// Bir namaz bölümünün adımlarını üretir.
List<NamazStep> namazSteps(Namaz nz, NamazPart part) {
  final r = part.rakats;
  final t = part.type;
  final fard = t == PartType.fard;
  final withSurah = !fard;
  final o = <NamazStep>[];

  for (var i = 1; i <= r; i++) {
    o.add(NamazStep.rakat(i));
    if (i == 1) {
      o.add(NamazStep(
        'niyet',
        'Niyet',
        'Hangi namazı kılacağınızı kalbinizden geçirin. İsterseniz dilinizle de söyleyebilirsiniz.',
        niyet: niyetText(nz, part),
      ));
      o.add(const NamazStep(
        'tekbir',
        'İftitah Tekbiri',
        'Eller kulak hizasına kaldırılır, avuçlar kıbleye dönük; "Allâhü ekber" denir ve eller göbeğin '
            'altında bağlanır (sağ el sol elin üstünde).',
      ));
      o.add(NamazStep(
        'kiyam',
        'Kıyam',
        "${fard && nz.key == 'cuma' ? "İmam okur, cemaat Sübhâneke'yi okuyup susarak dinler. " : ''}"
            'Sübhâneke, Eûzü-Besmele ve Fâtiha okunur.',
        duas: const ['Sübhâneke', 'Eûzü - Besmele', 'Fâtiha Sûresi'],
      ));
    } else if (t == PartType.sunnahGhayr && i == 3) {
      o.add(const NamazStep(
        'kalk',
        'Üçüncü Rekâta Kalkış',
        '"Allâhü ekber" diyerek ayağa kalkılır. Gayr-i müekked sünnette 3. rekât yeni bir namaz gibi başlar.',
      ));
      o.add(const NamazStep(
        'kiyam',
        'Kıyam',
        'Sübhâneke, Eûzü-Besmele ve Fâtiha okunur.',
        duas: ['Sübhâneke', 'Eûzü - Besmele', 'Fâtiha Sûresi'],
      ));
    } else {
      if (!(i == 3 && r > 2)) {
        o.add(NamazStep('kalk', '$i. Rekâta Kalkış', '"Allâhü ekber" diyerek ayağa kalkılır, eller bağlanır.'));
      }
      o.add(NamazStep(
        'kiyam',
        'Kıyam',
        fard && i >= 3 ? 'Besmele çekilir ve sadece Fâtiha okunur.' : 'Besmele çekilir ve Fâtiha okunur.',
        duas: const ['Fâtiha Sûresi'],
      ));
    }
    if (withSurah || i <= 2) {
      o.add(const NamazStep(
        'zamm',
        'Zamm-ı Sure',
        "Fâtiha'dan sonra kısa bir sure ya da en az üç kısa ayet okunur. Aşağıdan birini seçebilirsiniz.",
        pickSurah: true,
      ));
    }
    if (t == PartType.witr && i == 3) {
      o.add(const NamazStep(
        'tekbir',
        'Kunut Tekbiri',
        'Zamm-ı sureden sonra eller kulak hizasına kaldırılıp "Allâhü ekber" denir, eller tekrar bağlanır.',
      ));
      o.add(const NamazStep(
        'zamm',
        'Kunut Duaları',
        'Ayakta, eller bağlıyken Kunut duaları okunur.',
        duas: ['Kunut Duaları'],
      ));
    }
    o.add(const NamazStep(
      'ruku',
      'Rükû',
      '"Allâhü ekber" diyerek eğilinir. Eller parmaklar açık olarak dizlere konur, sırt ve baş düz tutulur. '
          'Üç kez rükû tesbihi söylenir.',
      duas: ['Rükû Tesbihi'],
    ));
    o.add(const NamazStep(
      'kavme',
      'Kavme (Doğrulma)',
      "\"Semiallâhü li-men hamideh\" diyerek doğrulunur, dik durunca \"Rabbenâ leke'l-hamd\" denir.",
      duas: ['Rükûdan Kalkarken'],
    ));
    o.add(const NamazStep(
      'secde',
      'Birinci Secde',
      '"Allâhü ekber" diyerek secdeye varılır: önce dizler, sonra eller, sonra alın ve burun yere konur. '
          'Kollar yerden ve yanlardan uzak tutulur. Üç kez secde tesbihi söylenir.',
      duas: ['Secde Tesbihi'],
    ));
    o.add(const NamazStep(
      'celse',
      'Celse (Oturma)',
      '"Allâhü ekber" diyerek secdeden kalkılır ve bir tesbih miktarı oturulur.',
    ));
    o.add(const NamazStep(
      'secde',
      'İkinci Secde',
      '"Allâhü ekber" diyerek tekrar secdeye varılır ve üç kez secde tesbihi söylenir.',
      duas: ['Secde Tesbihi'],
    ));
    if (i == 2 && r > 2) {
      final ghayr = t == PartType.sunnahGhayr;
      o.add(NamazStep(
        'kade',
        "Ka'de-i Ûlâ (İlk Oturuş)",
        'Sol ayak yere yatırılıp üzerine oturulur, sağ ayak parmakları kıbleye dönük dik tutulur. '
            "${ghayr ? "Ettehiyyâtü'den sonra Salli ve Bârik de okunur, sonra 3. rekâta kalkılır." : 'Sadece Ettehiyyâtü okunur ve 3. rekâta kalkılır.'}",
        duas: ghayr ? const ['Ettehiyyâtü', 'Allâhümme Salli', 'Allâhümme Bârik'] : const ['Ettehiyyâtü'],
      ));
    }
    if (i == r) {
      o.add(const NamazStep(
        'kade',
        "Ka'de-i Âhîre (Son Oturuş)",
        'Sol ayak üzerine oturulur, sağ ayak dik tutulur. Ettehiyyâtü, Salli, Bârik ve Rabbenâ duaları okunur.',
        duas: ['Ettehiyyâtü', 'Allâhümme Salli', 'Allâhümme Bârik', 'Rabbenâ Duaları'],
      ));
      o.add(const NamazStep(
        'selam',
        'Selam',
        'Önce sağa, sonra sola "Esselâmü aleyküm ve rahmetullâh" diyerek selam verilir. Namaz tamamlanır.',
        duas: ['Selam'],
      ));
      if (fard && nz.key != 'cuma') {
        o.add(const NamazStep(
          'dua',
          'Namazdan Sonra',
          "Farz namazlardan sonra \"Allâhümme ente's-selâm\" okunur. Son sünnet varsa kılınır; ardından "
              "Âyetü'l-Kürsî ve tesbihat yapılıp dua edilir.",
          duas: ["Allâhümme Ente's-Selâm", "Âyetü'l-Kürsî", 'Tesbihat'],
        ));
      }
    }
  }
  return o;
}

// ---------------------------------------------------------------------------
// Abdest, Gusül, Teyemmüm, Farzlar ve Sık Sorulanlar
// ---------------------------------------------------------------------------

/// Madde: isteğe bağlı kalın başlangıç + metin.
class InfoItem {
  final String? lead;
  final String text;

  const InfoItem(this.text, {this.lead});
}

/// Bilgi kartı: başlık, açıklama ya da numaralı maddeler, alt not.
class InfoCard {
  final String title;
  final String? body;
  final List<InfoItem> items;
  final String? warn;

  const InfoCard(this.title, {this.body, this.items = const [], this.warn});
}

/// Açılır kapanır bölüm.
class InfoAccordion {
  final String title;
  final String? body;
  final List<String> bullets;

  const InfoAccordion(this.title, {this.body, this.bullets = const []});
}

class InfoTopic {
  final String key;
  final String railTitle;
  final List<InfoCard> cards;
  final List<InfoAccordion> accordions;

  const InfoTopic(this.key, this.railTitle, {this.cards = const [], this.accordions = const []});
}

const infoTopics = <InfoTopic>[
  InfoTopic('abdest', 'Abdest', cards: [
    InfoCard('Abdestin Farzları (4)', items: [
      InfoItem('Yüzü bir kere yıkamak'),
      InfoItem('Kolları dirseklerle birlikte bir kere yıkamak'),
      InfoItem('Başın dörtte birini meshetmek'),
      InfoItem('Ayakları topuklarla birlikte bir kere yıkamak'),
    ]),
    InfoCard(
      'Abdest Nasıl Alınır?',
      items: [
        InfoItem('Niyet edilir, "Eûzü-Besmele" çekilir.'),
        InfoItem('Eller bileklere kadar üç kez yıkanır.'),
        InfoItem('Sağ avuçla ağza üç kez su verilip çalkalanır.'),
        InfoItem('Sağ avuçla burna üç kez su çekilir, sol elle temizlenir.'),
        InfoItem('Yüz, alın saç bitiminden çene altına, kulak yumuşaklarına kadar üç kez yıkanır.'),
        InfoItem('Önce sağ, sonra sol kol dirseklerle birlikte üç kez yıkanır.'),
        InfoItem('Islak elle başın dörtte biri meshedilir.'),
        InfoItem('Islak parmaklarla kulaklar, ellerin dışıyla ense meshedilir.'),
        InfoItem('Önce sağ, sonra sol ayak topuklarla birlikte üç kez yıkanır, parmak araları hilallenir.'),
      ],
      warn: 'Yıkanan organlar sırayla ve ara vermeden yıkanmalı; tırnak cilası gibi suyun ulaşmasını '
          'engelleyen şeyler bulunmamalıdır.',
    ),
  ], accordions: [
    InfoAccordion('Abdesti bozan durumlar', bullets: [
      'Önden veya arkadan bir şey çıkması (idrar, dışkı, yel)',
      'Vücudun herhangi bir yerinden kan, irin gibi akıntının akması',
      'Ağız dolusu kusmak',
      'Uyumak (bir yere dayanarak ya da uzanarak)',
      'Bayılmak, sarhoş olmak',
      'Rükû ve secdeli bir namazda sesli gülmek',
    ]),
  ]),
  InfoTopic('gusul', 'Gusül', cards: [
    InfoCard('Guslün Farzları (3)', items: [
      InfoItem('Ağza su verip çalkalamak (mazmaza)'),
      InfoItem('Burna su çekmek (istinşak)'),
      InfoItem('Bütün bedeni kuru yer kalmayacak şekilde yıkamak'),
    ]),
    InfoCard(
      'Gusül Nasıl Alınır?',
      items: [
        InfoItem('Niyet edilir, besmele çekilir.'),
        InfoItem('Eller ve avret yerleri yıkanır, bedende pislik varsa temizlenir.'),
        InfoItem('Namaz abdesti gibi abdest alınır.'),
        InfoItem('Önce başa, sonra sağ omuza, sonra sol omuza üçer kez su dökülür.'),
        InfoItem('Bütün beden ovularak kuru yer kalmayacak şekilde yıkanır.'),
      ],
      warn: 'Ağız ve burun mutlaka yıkanmalıdır; göbek çukuru, kulak delikleri gibi yerlere suyun ulaşmasına '
          'dikkat edilir.',
    ),
  ]),
  InfoTopic('teyemmum', 'Teyemmüm', cards: [
    InfoCard(
      'Teyemmüm Ne Zaman Yapılır?',
      body: 'Su bulunamadığında ya da suyu kullanmak hastalık gibi bir sebeple zarar vereceğinde abdest veya '
          'gusül yerine teyemmüm yapılır.',
    ),
    InfoCard('Teyemmümün Farzları (2)', items: [
      InfoItem('Niyet etmek'),
      InfoItem('İki kez temiz toprağa vurmak: birinde yüzü, diğerinde kolları dirseklerle meshetmek'),
    ]),
    InfoCard(
      'Teyemmüm Nasıl Yapılır?',
      items: [
        InfoItem('Niyet edilir, besmele çekilir.'),
        InfoItem('Eller temiz toprağa (ya da toprak cinsinden bir şeye) vurulur, silkelenir ve bütün yüz '
            'meshedilir.'),
        InfoItem('Eller tekrar toprağa vurulur, silkelenir; önce sağ, sonra sol kol dirseklerle birlikte '
            'meshedilir.'),
      ],
      warn: 'Abdesti bozan her şey teyemmümü de bozar. Su bulununca ya da özür ortadan kalkınca teyemmüm biter.',
    ),
  ]),
  InfoTopic('sart', 'Farzlar', cards: [
    InfoCard('Namazın Dışındaki Farzlar (Şartlar)', items: [
      InfoItem('Abdestli olmak, gerekiyorsa gusletmek', lead: 'Hadesten tahâret:'),
      InfoItem('Beden, elbise ve namaz yerinin temiz olması', lead: 'Necasetten tahâret:'),
      InfoItem('Örtülmesi gereken yerleri örtmek', lead: 'Setr-i avret:'),
      InfoItem('Kıbleye yönelmek', lead: 'İstikbâl-i kıble:'),
      InfoItem('Namazı vaktinde kılmak', lead: 'Vakit:'),
      InfoItem('Kılınacak namaza niyet etmek', lead: 'Niyet:'),
    ]),
    InfoCard('Namazın İçindeki Farzlar (Rükünler)', items: [
      InfoItem('"Allâhü ekber" diyerek namaza başlamak', lead: 'İftitah tekbiri:'),
      InfoItem('Ayakta durmak', lead: 'Kıyam:'),
      InfoItem("Kur'an'dan bir miktar okumak", lead: 'Kıraat:'),
      InfoItem('Eğilmek', lead: 'Rükû:'),
      InfoItem('Secde etmek', lead: 'Sücûd:'),
      InfoItem('Son oturuşta Ettehiyyâtü okuyacak kadar oturmak', lead: "Ka'de-i âhîre:"),
    ]),
  ]),
  InfoTopic('sss', 'Sorular', accordions: [
    InfoAccordion(
      'Namazda bir hata yaparsam ne olur?',
      body: 'Bir vacibi unutmak gibi hatalarda namazın sonunda sehiv secdesi yapılır: Son oturuşta Ettehiyyâtü '
          'okunduktan sonra sağa selam verilir, iki secde yapılır, sonra tekrar oturulup Ettehiyyâtü, Salli, '
          'Bârik ve Rabbenâ okunarak selam verilir. Bir farz terk edilirse namaz yeniden kılınır.',
    ),
    InfoAccordion(
      'Zamm-ı sure olarak hangi sureleri okuyabilirim?',
      body: "Fâtiha'dan sonra en az üç kısa ayet ya da bir sure okunur. Namaz sureleri olarak bilinen Fîl'den "
          "Nâs'a kadarki kısa sureler en çok okunanlardır. Dualar bölümünde bu surelerin tamamı var.",
    ),
    InfoAccordion(
      'Vitir namazı nasıl kılınır?',
      body: 'Vitir üç rekâttır ve vaciptir. Üç rekâtta da Fâtiha ve zamm-ı sure okunur. Üçüncü rekâtta '
          'zamm-ı sureden sonra tekbir alınır ve Kunut duaları okunur. İkinci rekâtta sadece Ettehiyyâtü '
          'okunup kalkılır.',
    ),
    InfoAccordion(
      'Kaza namazı nasıl kılınır?',
      body: 'Kaçırılan farz namazlar ve vitir kaza edilir, sünnetler kaza edilmez. Niyette hangi namazın kazası '
          'olduğu belirtilir: "Niyet ettim Allah rızası için kılamadığım ilk öğle namazının farzını kılmaya" '
          'gibi. Kerahat vakitleri dışında her zaman kılınabilir.',
    ),
    InfoAccordion(
      'Kerahat vakitleri nelerdir?',
      body: 'Güneş doğarken (doğduktan sonra yaklaşık 45 dakikaya kadar), güneş tam tepedeyken ve güneş batarken '
          '(sararmasından batışına kadar) namaz kılınmaz. Bu vakitleri Namaz Vakitleri sayfasından takip '
          'edebilirsiniz.',
    ),
    InfoAccordion(
      'Kadınların namazı erkeklerden farklı mı?',
      body: 'Namazın farzları ve okunanlar aynıdır. Tekbirde ellerin kaldırılacağı yer, ellerin bağlanış yeri, '
          'rükû, secde ve oturuş biçimleri gibi bazı hareketlerde farklar vardır. Adım adım anlatımda '
          'Erkek/Kadın seçeneğiyle bunları görebilirsiniz.',
    ),
  ]),
];
