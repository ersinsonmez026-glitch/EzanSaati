import 'dart:io';

import 'package:ezan_saati/data/namaz_ogren.dart';
import 'package:ezan_saati/screens/learn_namaz_screen.dart';
import 'package:ezan_saati/screens/messages_screen.dart';
import 'package:ezan_saati/screens/prayers_screen.dart';
import 'package:ezan_saati/screens/ramadan_screen.dart';
import 'package:ezan_saati/screens/surahs_screen.dart';
import 'package:ezan_saati/screens/video_screen.dart';
import 'package:ezan_saati/services/content_store.dart';
import 'package:ezan_saati/services/takvim.dart';
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

    test('Dini Mesajlar: 96 mesaj, ayetler Ruvvâd mealinden birebir alıntı', () async {
      final msgs = await MessageData.all();
      final q = await QuranData.load();
      expect(msgs.length, 96);
      const counts = {'cuma': 41, 'kandil': 20, 'ramazan': 5, 'bayram': 20, 'sabah': 5, 'dua': 5};
      for (final c in kMessageCategories.keys) {
        expect(msgs.where((m) => m.category == c).length, counts[c], reason: c);
      }
      String norm(String s) => s.replaceAll(RegExp(r'\[\d+\]'), '').trim();
      var verses = 0;
      for (final m in msgs.where((m) => m.hasVerse)) {
        final match = RegExp(r'^(.+) Sûresi, (\d+)(?:-(\d+))?$').firstMatch(m.verseRef!)!;
        final surah =
            q.surahs.firstWhere((s) => s.name == match.group(1), orElse: () => throw 'Sure yok: ${m.verseRef}');
        final from = int.parse(match.group(2)!), to = int.parse(match.group(3) ?? match.group(2)!);
        final meal = [for (var a = from; a <= to; a++) norm(q.verses[surah.no - 1][a - 1].meal)].join(' ');
        // "…" atlanan yerleri gösterir; her parça mealde aynen geçmeli.
        for (final part in m.verse!.split('…').map((p) => p.trim()).where((p) => p.isNotEmpty)) {
          expect(meal.contains(part), isTrue, reason: '${m.verseRef}: $part');
        }
        verses++;
      }
      expect(verses, 48);
      for (final m in msgs.where((m) => m.image != null)) {
        expect(File('assets/images/mesaj/${m.image}.jpg').existsSync(), isTrue, reason: m.image);
      }
    });

    test('Günün mesajı güne göre: kandil, bayram, Ramazan, cuma, diğer günler', () async {
      final msgs = await MessageData.all();
      final dini = TakvimData.parse(File('assets/data/takvim.json').readAsStringSync()).religious;
      String cat(DateTime d) => msgs[dailyMessageIndex(msgs, d, dini)].category;
      expect(cat(DateTime(2027, 1, 4)), 'kandil'); // Miraç Kandili
      expect(cat(DateTime(2027, 3, 8)), 'bayram'); // arefe
      expect(cat(DateTime(2027, 5, 19)), 'bayram'); // Kurban Bayramı 4. gün
      expect(cat(DateTime(2027, 5, 20)), isNot('bayram'));
      expect(cat(DateTime(2027, 2, 19)), 'ramazan'); // Ramazan'da cuma da olsa
      expect(cat(DateTime(2026, 10, 2)), 'cuma');
      expect(['sabah', 'dua'], contains(cat(DateTime(2026, 9, 29))));
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
      expect(r.prayers.length, 3);
      expect(r.fasting.map((f) => f.kind), ['bozar', 'bozmaz', 'bilgi']);
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
    // Günün ayeti/duası her gün değişir; uzun olduğu günlerde liste aşağı kayar. Bu yüzden
    // listeye bakan testlerde uzun ekran kullanılır.
    Future<void> pump(WidgetTester t, Widget page, {double height = 844}) async {
      t.view.physicalSize = Size(390, height);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      // Veriler gerçek dosyadan okunur; sayfa açılmadan önce yüklensin.
      await t.runAsync(() => Future.wait([
            QuranData.load(),
            DuaData.all(),
            DuaData.namaz(),
            MessageData.all(),
            RamazanData.load(),
            EsmaName.all(),
            ReadingPrefs.get(),
          ]));
      await t.pumpWidget(MaterialApp(home: page));
      // Yüklenmiş verinin sayfaya ulaşması gerçek olay döngüsünde tamamlanır.
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
    }

    testWidgets('Sureler açılır ve sure okunur', (t) async {
      await pump(t, const SurahsScreen(), height: 2400);
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
      await pump(t, const PrayersScreen(), height: 2400);
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
      await t.scrollUntilVisible(find.text('20 mesaj'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('20 mesaj'), findsOneWidget);
    });

    testWidgets('Ramazan: panel ve sekmeler', (t) async {
      await pump(t, const RamadanScreen(), height: 1600);
      expect(find.text('İmsakiye'), findsWidgets);
      await t.tap(find.text('Önemli Günler'));
      await t.pump();
      expect(find.text('Berat Kandili'), findsOneWidget);
      await t.tap(find.text('Niyet ve Dua'));
      await t.pump();
      expect(find.text('İFTAR DUASI'), findsOneWidget);
    });

    testWidgets("Dualar: Esmâü'l-Hüsnâ sekmesi ve sesli dinleme", (t) async {
      await pump(t, const PrayersScreen(), height: 1600);
      await t.tap(find.text("Esmâü'l-Hüsnâ").first);
      await t.pump();
      expect(find.text('er-Rahmân'), findsOneWidget);
      await t.tap(find.text('Sesli Dinle (ritimli okunuş)'));
      await t.pumpAndSettle();
      expect(find.byType(VideoScreen), findsOneWidget);
    });
  });
}
