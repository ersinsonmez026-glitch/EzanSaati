import 'dart:io';

import 'package:ezan_saati/data/namaz_ogren.dart';
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
  });
}
