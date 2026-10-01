/// Ana ekrandaki "Günün ayeti" ve "Günün hadisi".
///
/// Ayetler: meal uygulamanın Kur'an verisinden (assets/data/kuran.json, Ruvvâd Tercüme Merkezi) aynen alınmıştır.
/// Hadisler: Diyanet İşleri Başkanlığı, "Hadislerle İslâm" (hadislerleislam.diyanet.gov.tr) eserinde
/// Hz. Peygamber'in sözü olarak tırnak içinde verilen ve dipnotta Kütüb-i Sitte'ye dayandırılan kısa
/// hadisler; metin değiştirilmemiştir (yalnız sitedeki " işareti kesme işaretine ’ çevrildi).
/// Kaynak, eserdeki dipnottur; cilt/sayfa eserin sayfasını gösterir.
library;

class DailyAyah {
  final String surah;
  final int no;
  final String meal;

  const DailyAyah(this.surah, this.no, this.meal);

  String get source => '$surah, $no';
}

class DailyHadith {
  final String text;
  final String source; // eserdeki dipnot: kitap, bölüm, bab
  final int cilt;
  final int sayfa;

  const DailyHadith(this.text, this.source, this.cilt, this.sayfa);

  String get book => 'Hadislerle İslâm, $cilt/$sayfa';
  String get url => 'https://hadislerleislam.diyanet.gov.tr/sayfa.php?CILT=$cilt&SAYFA=$sayfa';
}

const kDailyAyahs = <DailyAyah>[
  DailyAyah('Bakara', 45, 'Sabır ve namazla Allah’tan yardım isteyin ve şüphesiz bu (namaz), huşu duyanlardan başkasına ağır gelir.'),
  DailyAyah('Bakara', 152, 'O halde yalnız beni anın ki, ben de sizi anayım. Bana şükredin ve sakın bana nankörlük etmeyin!'),
  DailyAyah('Bakara', 153, 'Ey iman edenler! Sabrederek ve namaz kılarak Allah\'tan yardım dileyin! Şüphesiz ki Allah, sabredenlerle beraberdir.'),
  DailyAyah('Âl-i İmrân', 92, 'Sevdiğiniz şeylerden infak etmedikçe iyiliğe asla erişemezsiniz. Her ne harcarsanız Allah onu hakkıyla bilir.'),
  DailyAyah('Âl-i İmrân', 139, 'Gevşemeyin, hüzünlenmeyin. Eğer (gerçekten) iman etmiş kimseler iseniz üstün olan sizlersiniz.'),
  DailyAyah('Nisâ', 28, 'Allah, sizden (ağır yükümlülükleri) hafifletmek istiyor. Çünkü insan zayıf yaratılmıştır.'),
  DailyAyah('En\'âm', 162, 'De ki: “Benim namazım, kurbanım, hayatım ve ölümüm âlemlerin Rabbi olan Allah içindir.”'),
  DailyAyah('A\'râf', 199, 'Af yolunu tut, iyiliği emret, cahillerden de yüz çevir!'),
  DailyAyah('Tevbe', 51, 'De ki: Allah’ın bize yazdığından başkası başımıza gelmez. O, bizim mevlamızdır. Müminler Allah’a güvenip, tevekkül etsinler.'),
  DailyAyah('Hûd', 115, '(Ey Muhammed!) Sabırlı ol! Çünkü Allah ihsan sahibi kimselerin mükâfatını zayi etmez.'),
  DailyAyah('Ra\'d', 28, 'Bunlar, iman edenler ve gönülleri Allah\'ın zikriyle sükûnete erenlerdir. Bilesiniz ki, kalpler ancak Allah\'ı zikretmekle huzur bulur.'),
  DailyAyah('Nahl', 128, 'Şüphesiz Allah, korkup, sakınanlar ve iyilik yapanlarla beraberdir.'),
  DailyAyah('Tâhâ', 25, '"Rabbim gönlüme ferahlık ver!" dedi.'),
  DailyAyah('Mü\'minûn', 1, 'Gerçekten Mü\'minler kurtuluşa ermiştir.'),
  DailyAyah('Mü\'minûn', 2, 'Onlar namazlarında huşû içinde olanlardır.'),
  DailyAyah('Mü\'minûn', 118, 'De ki: “Rabbim! Bağışla, merhamet et. Çünkü sen merhamet edenlerin en hayırlısısın!”'),
  DailyAyah('Kasas', 24, 'Bunun üzerine Mûsâ, onların (davarlarını) sulayıp bir gölgeye çekilerek: “Rabbim doğrusu bana indireceğin hayra muhtacım” dedi.'),
  DailyAyah('Ahzâb', 41, 'Ey iman edenler! Allah’ı çok çok zikredin.'),
  DailyAyah('Ahzâb', 56, 'Şüphesiz Allah ve melekleri Nebi’ye salat ederler. Ey Müminler siz de ona salat ve selam edin.'),
  DailyAyah('Ahzâb', 70, 'Ey iman edenler! Allah’tan sakının ve doğru söz söyleyin.'),
  DailyAyah('Fâtır', 15, 'Ey insanlar! Allah\'a muhtaç olanlar sizlersiniz. Allah zengin ve övülmeye lâyık olandır.'),
  DailyAyah('Mü\'min', 44, 'Size söylediklerimi hatırlayacaksınız. Ben işimi Allah’a havale ediyorum. Şüphesiz Allah, kullarını çok iyi görendir.'),
  DailyAyah('Şûrâ', 19, 'Allah, kullarına karşı çok lütufkârdır. Dilediğini rızıklandırır. Çok kuvvetli ve güçlü olan O’dur.'),
  DailyAyah('Muhammed', 7, 'Ey İman edenler! Eğer Allah’a yardım ederseniz, O da size yardım edecek ve ayaklarınızı sabit kılacaktır.'),
  DailyAyah('Hucurât', 10, 'Müminler ancak kardeştirler. Öyleyse kardeşlerinizin arasını düzeltin ve Allah’tan sakının ki, merhamet olunasınız.'),
  DailyAyah('Kâf', 16, 'Şüphesiz insanı biz yarattık ve nefsinin ona ne vesveseler vermekte olduğunu da biliriz. Biz ona şahdamarından daha yakınız.'),
  DailyAyah('Zâriyât', 56, 'Ben cinleri de insanları da ancak bana ibadet etsinler, diye yarattım.'),
  DailyAyah('Rahmân', 13, 'Öyleyse Rabbinizin hangi nimetlerini yalanlayabilirsiniz?'),
  DailyAyah('Rahmân', 60, 'İyiliğin karşılığı iyilikten başkası olabilir mi?'),
  DailyAyah('A\'lâ', 14, 'Arınan kimse mutlaka kurtuluşa erer.'),
  DailyAyah('Duhâ', 3, 'Rabbin ne seni terk etti, ne de sana darıldı.'),
  DailyAyah('Duhâ', 5, 'Elbette Rabbin sana verecek, sen de hoşnut olacaksın.'),
  DailyAyah('İnşirâh', 5, 'Şüphesiz her zorlukla beraber bir kolaylık vardır.'),
  DailyAyah('İnşirâh', 8, 'Ve yalnızca Rabbine yönel.'),
  DailyAyah('Tîn', 4, 'Biz, gerçekten insanı en güzel bir biçimde yarattık.'),
  DailyAyah('Zilzâl', 7, 'Artık kim zerre ağırlığınca bir hayır işlerse, onun mükâfatını görecektir.'),
  DailyAyah('İhlâs', 1, 'De ki: O Allah birdir.'),
  DailyAyah('Şuarâ', 80, '"Hastalandığımda da O bana şifa verir."'),
  DailyAyah('Bakara', 201, 'İnsanlardan: “Rabbimiz! Bize bu dünyada da iyilik ver, ahirette de iyilik ver ve bizi ateşin azabından koru!” diyen kimseler de vardır.'),
  DailyAyah('Âl-i İmrân', 8, 'Rabbimiz! Bizi doğru yola ilettikten sonra, kalplerimizi eğriltme. Bize katından rahmet bahşet! Şüphesiz sen, bol bol bahşedensin.'),
];

const kDailyHadiths = <DailyHadith>[
  DailyHadith('Dua ibadetin özüdür.', 'Tirmizî, Deavât, 1', 2, 52),
  DailyHadith('Sadaka malı eksiltmez!', 'Müslim, Birr, 69', 1, 660),
  DailyHadith('Her iyilik bir sadakadır.', 'Buhârî, Edeb, 33', 2, 488),
  DailyHadith('Hiçbir iyiliği küçümseme.', 'Müslim, Birr, 144', 3, 46),
  DailyHadith('Hayâ ancak hayır getirir.', 'Müslim, Îmân, 60', 3, 173),
  DailyHadith('Mümin, müminin aynasıdır.', 'Ebû Dâvûd, Edeb, 49', 4, 354),
  DailyHadith('Kişi sevdiğiyle beraberdir.', 'Tirmizî, Zühd, 50', 1, 201),
  DailyHadith('Oruç, sabrın yarısıdır.', 'İbn Mâce, Sıyâm, 44', 2, 416),
  DailyHadith('Allah güzeldir ve güzeli sever.', 'Müslim, Îmân, 147', 7, 537),
  DailyHadith('Merhamet etmeyene merhamet edilmez!', 'Buhârî, Edeb, 18', 4, 147),
  DailyHadith('Komşuna iyilik yap ki mümin olasın.', 'Tirmizî, Zühd, 2', 4, 340),
  DailyHadith('Gücünüz yettiği kadar amel üstlenin.', 'Buhârî, Rikâk, 18', 2, 573),
  DailyHadith('Her canlıya iyilik için ecir vardır.', 'Buhârî, Mezâlim, 23', 3, 108),
  DailyHadith('Mümin bir delikten iki kere sokulmaz!', 'Müslim, Zühd, 63', 4, 351),
  DailyHadith('Dünyada bir garip veya yolcu gibi ol!', 'Buhârî, Rikâk, 3', 6, 416),
  DailyHadith('Benden bir âyet bile olsa ulaştırınız.', 'Buhârî, Enbiyâ, 50', 1, 381),
  DailyHadith('Kişi, dostunun dini/ahlâkı üzerinedir.', 'Tirmizî, Zühd, 45', 3, 83),
  DailyHadith('Allah’a inandım de, sonra dosdoğru ol!', 'Müslim, Îmân, 62', 3, 402),
  DailyHadith('Çalışana ücretini, teri kurumadan verin.', 'İbn Mâce, Rühûn, 4', 5, 316),
  DailyHadith('Çocuklarınız arasında adaletli davranın.', 'Ebû Dâvûd, Büyû’ (İcâre), 83', 4, 410),
  DailyHadith('Sabır, musibetin başa geldiği ilk andadır.', 'Müslim, Cenâiz, 14', 3, 186),
  DailyHadith('Biliniz ki sizin en hayırlı ameliniz namazdır.', 'İbn Mâce, Tahâret, 4', 3, 173),
  DailyHadith('Cimrilik ve kötü ahlâk asla bir müminde bulunmaz.', 'Tirmizî, Birr, 41', 1, 615),
  DailyHadith('İnsanlara teşekkür etmeyen, Allah’a da şükretmez.', 'Tirmizî, Birr, 35', 2, 76),
  DailyHadith('Kişinin ailesi için yaptığı harcama da sadakadır.', 'Buhârî, Meğâzî, 12', 2, 496),
  DailyHadith('İnsanın yediği şeylerin en güzeli, elinin emeğidir.', 'Ebû Dâvûd, Büyû’ (İcâre), 77', 1, 618),
  DailyHadith('Rahatsız edici bir şeyi yoldan kaldırmak sadakadır.', 'Buhârî, Cihâd 128', 7, 374),
  DailyHadith('Sizin en hayırlınız, Kur’an’ı öğrenen ve öğretendir.', 'Tirmizî, Fedâilü’l-Kur’ân, 15', 1, 560),
  DailyHadith('İnsanlara merhamet etmeyene Allah da merhamet etmez.', 'Buhârî, Tevhîd, 2', 3, 91),
  DailyHadith('Yüce Allah her işte rıfkı (yumuşak huyluluğu) sever.', 'Buhârî, Edeb, 35', 4, 452),
  DailyHadith('Allah Teâlâ katında duadan daha kıymetli bir şey yoktur.', 'Tirmizî, Deavât, 1', 2, 52),
  DailyHadith('Dilin sürekli Allah’ın zikriyle ıslansın (meşgul olsun)!', 'Tirmizî, Deavât, 4', 2, 87),
  DailyHadith('Cennetin anahtarı namaz, namazın anahtarı ise abdesttir.', 'Tirmizî, Tahâret, 1', 2, 120),
  DailyHadith('Yiyip şükreden kimse sabrederek oruç tutan kimse gibidir.', 'Tirmizî, Sıfatü’l-kıyâme, 43', 2, 77),
  DailyHadith('Sizin en hayırlınız ailesine karşı en hayırlı olanınızdır.', 'Tirmizî, Menâkıb, 63', 3, 103),
  DailyHadith('Rıfktan (zarafetten) mahrum olan, hayırdan da mahrum olur.', 'Müslim, Birr, 74', 3, 419),
  DailyHadith('Kazayı ancak dua değiştirebilir, ömrü yalnız iyilik uzatır.', 'Tirmizî, Kader, 6', 1, 607),
  DailyHadith('Günahtan tevbe eden kimse, hiç günahı olmayan kimse gibidir.', 'İbn Mâce, Zühd, 30', 2, 101),
  DailyHadith('Kolaylaştırın zorlaştırmayın; müjdeleyin, nefret ettirmeyin!', 'Buhârî, İlim, 11', 6, 581),
  DailyHadith('Allah, nimetinin eserini kulunun üzerinde görülmesini sever.', 'Tirmizî, Edeb, 54', 7, 484),
  DailyHadith('İlim için yola koyulan kimse, dönünceye kadar Allah yolundadır.', 'Tirmizî, İlim, 2', 1, 376),
  DailyHadith('Ey kalpleri çeviren Rabbim, benim kalbimi dinin üzere sabit kıl.', 'Tirmizî, Deavât, 89', 3, 59),
  DailyHadith('Kim Allah’a ve âhiret gününe iman ederse komşusuna iyilik etsin!', 'Müslim, Îmân, 77', 3, 105),
  DailyHadith('Bir şey isteyeceğin zaman veya yardım dilediğinde Allah’tan iste.', 'Tirmizî, Sıfatü’l-kıyâme, 59', 7, 587),
  DailyHadith('Kim Allah’a ve âhiret gününe inanıyorsa, ya hayır söylesin ya da sussun.', 'Müslim, Îmân, 74', 3, 387),
  DailyHadith('Her dinin bir ahlâkı (karakteri, özü) vardır. İslâm’ın ahlâkı da hayâdır.', 'İbn Mâce, Zühd, 17', 1, 367),
  DailyHadith('Hiçbir baba, evlâdına güzel terbiyeden daha üstün bir hediye vermemiştir.', 'Tirmizî, Birr, 33', 3, 19),
  DailyHadith('Bana bir kez salavât getirene Allah on kez salavât getirir (rahmet eyler).', 'Müslim, Salât, 70', 1, 202),
  DailyHadith('Müslüman, elinden ve dilinden diğer Müslümanların zarar görmediği kişidir.', 'Müslim, Îmân, 65', 3, 456),
  DailyHadith('Müminlerin iman bakımından en mükemmeli, ahlâk bakımından en güzel olanıdır.', 'Ebû Dâvûd, Sünnet, 15', 1, 615),
  DailyHadith('Mazlumun bedduasından sakının, çünkü Allah ile mazlum arasında perde yoktur.', 'Buhârî, Zekât, 63', 2, 66),
  DailyHadith('Müslüman’ın diğer Müslümanlarla ilişkisi, birbirine kenetlenmiş bina gibidir.', 'Buhârî, Mezâlim, 5', 3, 355),
  DailyHadith('Allah, insanların suretlerine ve mallarına değil, kalplerine ve amellerine bakar.', 'Müslim, Birr, 34', 3, 119),
  DailyHadith('Ey insanlar! Gücünüzün yeteceği amelleri yapın! Allah usanmaz ama siz usanırsınız!', 'Müslim, Müsâfirîn, 215', 3, 200),
  DailyHadith('Güçlü kimse, insanları güreşte yenen değil, bilakis öfke anında kendisine hâkim olandır.', 'Müslim, Birr, 107', 3, 210),
  DailyHadith('Kulun Rabbine en yakın olduğu (an) secde hâlidir. Öyleyse (secdede iken) çokça dua ediniz.', 'Müslim, Salât, 215', 2, 168),
  DailyHadith('Allah’ım, seni zikretmek, sana şükretmek ve sana güzelce ibadet etmek için bana yardım et!', 'Ebû Dâvûd, Vitr, 26', 6, 538),
  DailyHadith('İyilik güzel ahlâktır. Kötülük ise içini huzursuz eden ve başkalarının bilmesini istemediğin şeydir.', 'Müslim, Birr, 14', 3, 17),
  DailyHadith('Hiçbiriniz kendisi için istediğini (mümin) kardeşi için de istemedikçe (gerçek mânâda) iman etmiş olmaz.', 'Buhârî, Îmân, 7', 3, 409),
  DailyHadith('Kim darda kalmış (borçlu) bir kimseye kolaylık sağlarsa, Allah da ona dünyada ve âhirette kolaylık sağlar.', 'Müslim, Zikir, 38', 5, 238),
  DailyHadith('İman etmedikçe cennete giremezsiniz, aranızda sevgi ve muhabbeti ikame etmedikçe de iman etmiş olmazsınız.', 'Müslim, Îmân, 93', 3, 358),
  DailyHadith('Sadakanın en faziletlisi, Müslüman’ın bir bilgi öğrenmesi, sonra da o bilgiyi Müslüman kardeşine öğretmesidir.', 'İbn Mâce, Sünnet, 20', 1, 381),
  DailyHadith('Birbirinize kin beslemeyin, birbirinize haset etmeyin, birbirinize sırt çevirmeyin. Ey Allah’ın kulları! Kardeşler olun!', 'Buhârî, Edeb, 62', 3, 577),
  DailyHadith('Kim inanarak ve karşılığını Allah’tan bekleyerek Ramazan orucunu tutarsa geçmiş günahları bağışlanır.', 'Buhârî, Îmân, 28', 2, 396),
  DailyHadith('Allah’ım! Günahlarımı bağışla, rızkımı genişlet ve bana verdiğin rızıkları bereketli kıl!', 'Tirmizî, Deavât, 78', 1, 651),
  DailyHadith('Rabbin hoşnutluğu anne babanın hoşnutluğuna, O’nun öfkesi ise anne babanın öfkesine bağlıdır.', 'Tirmizî, Birr, 3', 4, 426),
  DailyHadith('Cemaatle kılınan namaz, tek başına kılınan namazdan yirmi yedi kat daha faziletlidir.', 'Buhârî, Ezân, 30', 2, 191),
  DailyHadith('Allah sadece samimi bir şekilde ve kendi rızası gözetilerek yapılan amelleri kabul eder.', 'Nesâî, Cihâd, 24', 3, 26),
  DailyHadith('Her kim sabah namazını kılarsa, o kimse Allah’ın koruması altındadır.', 'Müslim, Mesâcid, 262', 2, 178),
  DailyHadith('Allah’ım, bütün hayırlar senin elindedir. Şer ile sana ulaşmak mümkün değildir.', 'Müslim, Müsâfirîn, 201', 3, 605),
  DailyHadith('Sözün en güzeli Allah’ın kelâmı, en güzel yol da Muhammed’in yoludur.', 'Nesâî, Sehv, 65', 3, 386),
  DailyHadith('Temizlik imanın yarısıdır. Elhamdülillâh (demek) mizanı (teraziyi) doldurur.', 'Müslim, Tahâret, 1', 5, 27),
  DailyHadith('Sana fayda veren şeye çaba göster; Allah’tan yardım dile ve âciz olma!', 'Müslim, Kader, 34', 5, 138),
  DailyHadith('Ben ve yetime kol kanat geren kimse cennette böyle (yan yana) olacağız.', 'Buhârî, Talâk, 25', 4, 292),
];

int _day(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2024)).inDays;

/// Her gün sıradaki ayet; gün içinde değişmez.
DailyAyah ayahOfDay(DateTime d) => kDailyAyahs[_day(d) % kDailyAyahs.length];

/// Her gün sıradaki hadis; gün içinde değişmez.
DailyHadith hadithOfDay(DateTime d) => kDailyHadiths[_day(d) % kDailyHadiths.length];
