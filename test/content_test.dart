import 'dart:io';

import 'package:ezan_saati/data/namaz_ogren.dart';
import 'package:ezan_saati/screens/learn_namaz_screen.dart';
import 'package:ezan_saati/screens/prayers_screen.dart';
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
      await t.runAsync(() => Future.wait([QuranData.load(), DuaData.all(), DuaData.namaz(), ReadingPrefs.get()]));
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
  });
}
