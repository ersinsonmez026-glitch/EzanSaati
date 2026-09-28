import 'dart:io';

import 'package:ezan_saati/data/namaz_ogren.dart';
import 'package:ezan_saati/screens/baby_names_screen.dart';
import 'package:ezan_saati/screens/learn_namaz_screen.dart';
import 'package:ezan_saati/screens/messages_screen.dart';
import 'package:ezan_saati/screens/prayers_screen.dart';
import 'package:ezan_saati/screens/ramadan_screen.dart';
import 'package:ezan_saati/screens/stories_screen.dart';
import 'package:ezan_saati/screens/surahs_screen.dart';
import 'package:ezan_saati/services/content_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Veri dosyaları', () {
    test("Kur'an: 114 sure, 6236 ayet", () async {
      final q = await QuranData.load();
      expect(q.surahs.length, 114);
      expect(q.verses.length, 114);
      var total = 0;
      for (final s in q.surahs) {
        expect(q.verses[s.no - 1].length, s.ayahCount, reason: s.name);
        total += s.ayahCount;
      }
      expect(total, 6236);
      expect(q.surahs.first.name, 'Fâtiha');
    });

    test('Dualar: 106 dua (26 namaz, 80 diğer), başlıklar tekil', () async {
      final d = await DuaData.all();
      expect(d.length, 106);
      expect(d.where((e) => e.group == 'namaz').length, 26);
      expect(d.where((e) => e.group == 'diger').length, 80);
      expect(d.map((e) => e.title).toSet().length, 106);
    });

    test("Namaz Öğren adımlarındaki bütün dualar ve görseller mevcut", () async {
      final nd = await DuaData.namaz();
      for (final n in namazlar) {
        for (final p in n.parts) {
          for (final s in namazSteps(n, p)) {
            for (final t in s.duas) {
              expect(nd.containsKey(t), isTrue, reason: '${n.title} / ${p.name}: $t');
            }
          }
        }
      }
      for (final t in zammSurahs) {
        expect(nd.containsKey(t), isTrue, reason: t);
      }
      for (final img in poseImages.values.toSet()) {
        expect(File('assets/images/namaz/$img.webp').existsSync(), isTrue, reason: img);
      }
    });

    test('Dini Mesajlar: 30 mesaj, ayetler Ruvvâd mealiyle birebir', () async {
      final msgs = await MessageData.all();
      final q = await QuranData.load();
      expect(msgs.length, 30);
      for (final c in kMessageCategories.keys) {
        expect(msgs.where((m) => m.category == c).length, 5, reason: c);
      }
      String norm(String s) => s.replaceAll(RegExp(r'\[\d+\]'), '').trim();
      var verses = 0;
      for (final m in msgs.where((m) => m.hasVerse)) {
        final match = RegExp(r'^(.+) Sûresi, (\d+)$').firstMatch(m.verseRef!)!;
        final surah = q.surahs.firstWhere((s) => s.name == match.group(1), orElse: () => throw 'Sure yok: ${m.verseRef}');
        final ayah = q.verses[surah.no - 1][int.parse(match.group(2)!) - 1];
        expect(norm(m.verse!), norm(ayah.meal), reason: m.verseRef);
        verses++;
      }
      expect(verses, 13);
      for (final m in msgs.where((m) => m.image != null)) {
        expect(File('assets/images/mesaj/${m.image}.jpg').existsSync(), isTrue, reason: m.image);
      }
    });

    test('Ramazan: 2027 takvimi tutarlı', () async {
      final r = await RamazanData.load();
      expect(r.year, 2027);
      expect(r.start, DateTime(2027, 2, 8));
      expect(r.dayNumber(DateTime(2027, 2, 8, 12)), 1);
      // Son oruç günü bayramdan (9 Mart) bir önceki gün, yani arefe (8 Mart) olmalı.
      expect(r.dateOf(r.days), DateTime(2027, 3, 8));
      expect(r.days, 29);
      expect(r.kadir, DateTime(2027, 3, 5));
      expect(r.bayram, DateTime(2027, 3, 9));
      expect(r.importantDays.length, 7);
      expect(r.prayers.length, 2);
    });

    test('Dini Hikâyeler: yalnızca geçerli Kur\'an ayet aralıkları', () async {
      final st = await StoryData.load();
      final q = await QuranData.load();
      expect(st.stories.length, 9);
      for (final s in st.stories) {
        expect(st.categories.containsKey(s.category), isTrue, reason: s.title);
        expect(s.passages, isNotEmpty, reason: s.title);
        for (final p in s.passages) {
          expect(p.surah, inInclusiveRange(1, 114), reason: s.title);
          expect(p.from, greaterThanOrEqualTo(1), reason: s.title);
          expect(p.to, lessThanOrEqualTo(q.surahs[p.surah - 1].ayahCount), reason: s.title);
          expect(p.from, lessThanOrEqualTo(p.to), reason: s.title);
        }
      }
      final yusuf = st.stories.firstWhere((s) => s.title == 'Hz. Yûsuf');
      expect(yusuf.sourceLines(q), ['Yûsuf Sûresi, 4-101. ayetler']);
    });

    test("Bebek İsimleri: Kur'an'da geçen her isim listelenen her ayette gerçekten geçiyor", () async {
      final d = await BabyNameData.load();
      final q = await QuranData.load();
      // Arapça iskelet: harekeler, elifler ve hemzeler çıkarılır (Osmanlı imlası farkları için).
      String sk(String s) => s
          .replaceAll(RegExp('[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
          .replaceAll(RegExp('[آأإٱاء]'), '')
          .replaceAll('ى', 'ي')
          .replaceAll('ئ', 'ي')
          .replaceAll('ؤ', 'و')
          .replaceAll('ة', 'ه');
      String tr(String s) => s
          .replaceAll('â', 'a')
          .replaceAll('î', 'i')
          .replaceAll('û', 'u')
          .replaceAll('Â', 'A')
          .replaceAll('Î', 'I')
          .replaceAll('Û', 'U');
      const arabic = {
        'Âdem': ['ءادم'], 'İdris': ['ادريس'], 'Nûh': ['نوح'], 'Hûd': ['هود'], 'Sâlih': ['صلح'],
        'İbrâhîm': ['ابرهيم', 'ابرهم'], 'İsmâil': ['اسمعيل'], 'İshak': ['اسحق'], "Ya'kûb": ['يعقوب'],
        'Yûsuf': ['يوسف'], 'Lût': ['لوط'], 'Eyyûb': ['ايوب'], 'Şuayb': ['شعيب'], 'Mûsâ': ['موسي'],
        'Hârûn': ['هرون'], 'Dâvûd': ['داود'], 'Süleyman': ['سليمن'], 'İlyas': ['الياس', 'ياسين'],
        'Elyesa': ['اليسع'], 'Yûnus': ['يونس'], 'Zülkifl': ['كفل'], 'Zekeriyyâ': ['زكريا'], 'Yahyâ': ['يحيي'],
        'Îsâ': ['عيسي'], 'Muhammed': ['محمد'], 'Ahmed': ['احمد'], 'Lokmân': ['لقمن'], 'Üzeyr': ['عزير'],
        'İmrân': ['عمرن'], 'Tâlût': ['طالوت', 'طلوت'], 'Zeyd': ['زيد'], 'Meryem': ['مريم'],
      };
      const meal = {
        'Âdem': ['Adem'], 'İdris': ['İdris'], 'Nûh': ['Nuh', 'Núh'], 'Hûd': ['Hud'], 'Sâlih': ['Salih'],
        'İbrâhîm': ['İbrahim'], 'İsmâil': ['İsmail'], 'İshak': ['İshak'],
        "Ya'kûb": ['Yakub', "Ya'kub", 'Yakup', "Ya'kup"],
        'Yûsuf': ['Yusuf'], 'Lût': ['Lut'], 'Eyyûb': ['Eyyub', 'Eyyup'], 'Şuayb': ['Şuayb', 'Şuayp', "Şu'ayb", 'Şu’ayb'],
        'Mûsâ': ['Musa'], 'Hârûn': ['Harun'], 'Dâvûd': ['Davud', 'Davut'], 'Süleyman': ['Süleyman'],
        'İlyas': ['İlyas'], 'Elyesa': ['Elyesa', 'Elyasa'], 'Yûnus': ['Yunus'], 'Zülkifl': ['Zülkifl'],
        'Zekeriyyâ': ['Zekeriya', 'Zekeriyya'], 'Yahyâ': ['Yahya'], 'Îsâ': ['İsa', 'Isa'], 'Muhammed': ['Muhammed'],
        'Ahmed': ['Ahmed'], 'Lokmân': ['Lokman'], 'Üzeyr': ['Üzeyr', 'Uzeyir', 'Uzeyr'], 'İmrân': ['İmran'],
        'Tâlût': ['Talut'], 'Zeyd': ['Zeyd'], 'Meryem': ['Meryem'],
      };
      expect(d.quran.names.length, 32);
      expect(d.quran.names.where((n) => n.girl).map((n) => n.name), ['Meryem']);
      for (final n in d.quran.names) {
        expect(n.verses, isNotEmpty, reason: n.name);
        final pats = arabic[n.name]!.map(sk).toList();
        final rx = RegExp('(?<![A-Za-zÇĞİÖŞÜçğıöşü])(${meal[n.name]!.map(RegExp.escape).join('|')})');
        for (final (s, a) in n.verses) {
          final v = q.verses[s - 1][a - 1];
          final words = sk(v.arabic).split(' ');
          expect(words.any((w) => pats.any(w.contains)), isTrue, reason: '${n.name}: Arapça metinde yok ($s:$a)');
          // Bakara 53'te Mûsâ adı Arapça metinde var, mealde çevrilmemiş.
          if (n.name == 'Mûsâ' && s == 2 && a == 53) continue;
          expect(rx.hasMatch(tr(v.meal)), isTrue, reason: '${n.name}: mealde yok ($s:$a)');
        }
      }
      // Kur'an'da kişi adı olarak geçmeyenler bu kategoride olmamalı.
      final quranNames = d.quran.names.map((n) => n.name).toSet();
      for (final absent in ['Havva', 'Hatice', 'Fâtıma', 'Âişe', 'Zeynep', 'Hızır', 'Yâsîn', 'Tâhâ', 'Firavun', 'Kârûn']) {
        expect(quranNames.contains(absent), isFalse, reason: absent);
      }
      // İslami isimlerde anlam ve kaynak boş olmamalı.
      for (final n in d.islamic.names) {
        expect(n.meaning, isNotEmpty, reason: n.name);
        expect(n.source, isNotEmpty, reason: n.name);
        expect(n.verses, isEmpty, reason: n.name);
      }
    });

    test('Rekât sayıları anlatımla uyumlu', () {
      for (final n in namazlar) {
        for (final p in n.parts) {
          final rakats = namazSteps(n, p).where((s) => s.rakat != null).length;
          expect(rakats, p.rakats, reason: '${n.title} ${p.name}');
        }
      }
    });
  });

  group('Sayfalar', () {
    Future<void> pump(WidgetTester t, Widget page) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      // Veriler gerçek dosyadan okunur; sayfa açılmadan önce yüklensin.
      await t.runAsync(() => Future.wait([
            QuranData.load(),
            DuaData.all(),
            DuaData.namaz(),
            MessageData.all(),
            RamazanData.load(),
            StoryData.load(),
            BabyNameData.load(),
            ReadingPrefs.get(),
          ]));
      await t.pumpWidget(MaterialApp(home: page));
      // Yüklenmiş verinin sayfaya ulaşması gerçek olay döngüsünde tamamlanır.
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
    }

    testWidgets('Sureler açılır ve sure okunur', (t) async {
      await pump(t, const SurahsScreen());
      expect(find.text('Günün Ayeti'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Bakara'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Tüm Sureler'), findsOneWidget);
      await t.tap(find.text('Bakara'));
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      expect(find.text('Bakara Sûresi'), findsOneWidget);
    });

    testWidgets('Dualar açılır, sekme değişir', (t) async {
      await pump(t, const PrayersScreen());
      expect(find.text('Günün Duası'), findsOneWidget);
      expect(find.text('Sübhâneke'), findsWidgets);
      await t.tap(find.text('Diğer Dualar').first);
      await t.pumpAndSettle();
      expect(find.text("Hz. Âdem'in Tövbe Duası"), findsOneWidget);
    });

    testWidgets('Namaz Öğren: sol sütun kaydırınca sabit kalır', (t) async {
      await pump(t, const LearnNamazScreen());
      expect(find.text('Sabah Namazı'), findsOneWidget);
      final before = t.getTopLeft(find.text('Sabah')).dy;
      await t.drag(find.text('Niyet'), const Offset(0, -600));
      await t.pumpAndSettle();
      final after = t.getTopLeft(find.text('Sabah')).dy;
      expect(after, greaterThan(40)); // başlık şeridinin altında görünür
      expect(after, lessThan(before));
      await t.tap(find.text('Abdest'));
      await t.pumpAndSettle();
      expect(find.text('Abdestin Farzları (4)'), findsOneWidget);
    });

    testWidgets('Dini Mesajlar: kategori ve favori', (t) async {
      await pump(t, const MessagesScreen());
      expect(find.text('Günün Mesajı'), findsOneWidget);
      await t.tap(find.text('Kandil'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('5 mesaj'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('5 mesaj'), findsOneWidget);
    });

    testWidgets('Ramazan: panel ve sekmeler', (t) async {
      await pump(t, const RamadanScreen());
      expect(find.text('İmsakiye'), findsWidgets);
      await t.tap(find.text('Önemli Günler'));
      await t.pump();
      expect(find.text('Berat Kandili'), findsOneWidget);
      await t.tap(find.text('Niyet ve Dua'));
      await t.pump();
      expect(find.text('İFTAR DUASI'), findsOneWidget);
    });

    testWidgets('Dini Hikâyeler: liste, kategori ve kaynak', (t) async {
      await pump(t, const StoriesScreen());
      expect(find.text('Hz. Nûh ve Gemi'), findsOneWidget);
      await t.tap(find.text('Diğer Kıssalar'));
      await t.pumpAndSettle();
      expect(find.text('Ashâb-ı Kehf'), findsOneWidget);
      expect(find.text('Hz. Nûh ve Gemi'), findsNothing);
      await t.tap(find.text('Fil Vakası'));
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('KAYNAK'), 400, scrollable: find.byType(Scrollable).first);
      expect(find.text("Kur'an-ı Kerim, Fîl Sûresi, 1-5. ayetler"), findsOneWidget);
    });

    testWidgets('Bebek İsimleri: kategori, kız/erkek sekmesi, arama ve favori', (t) async {
      await pump(t, const BabyNamesScreen());
      await t.tap(find.text("Kur'an'da Geçen İsimler"));
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      expect(find.text('Meryem'), findsOneWidget);
      await t.tap(find.text('Erkek İsimleri'));
      await t.pumpAndSettle();
      expect(find.text('Meryem'), findsNothing);
      await t.enterText(find.byType(TextField), 'yusuf');
      await t.pumpAndSettle();
      expect(find.text('Yûsuf'), findsOneWidget);
      expect(find.text('Âdem'), findsNothing);
      await t.tap(find.byIcon(Icons.favorite_border).last);
      await t.pumpAndSettle();
      await t.tap(find.text('Favoriler'));
      await t.pumpAndSettle();
      expect(find.text('Favori İsimler'), findsOneWidget);
      expect(find.text('Yûsuf'), findsOneWidget);
    });
  });
}
