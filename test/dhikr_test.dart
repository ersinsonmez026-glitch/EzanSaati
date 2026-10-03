import 'package:ezan_saati/screens/dhikr_screen.dart';
import 'package:ezan_saati/services/dhikr_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('önizlemedeki 6 zikir ve önerilen hedefler', () {
    expect(kDhikrs.map((z) => z.title), [
      'Sübhânallâh',
      'Elhamdülillâh',
      'Allâhü ekber',
      'Lâ ilâhe illallâh',
      'Estağfirullâh',
      'Allâhümme salli alâ Muhammed',
    ]);
    expect(kDhikrs.map((z) => z.target), [33, 33, 33, 100, 100, 100]);
    expect(kDhikrs.last.label, 'Salavât');
    expect(kTesbihatSeq, ['subhan', 'hamd', 'tekbir']);
  });

  test('sayım, tur, geri al, sıfırla ve serbest hedef', () async {
    final s = await DhikrState.load();
    expect(s.current.id, 'subhan');
    for (var i = 0; i < 32; i++) {
      expect(s.add(), DhikrHit.counted);
    }
    expect(s.add(), DhikrHit.round); // 33
    expect(s.counter('subhan').rounds, 1);
    s.add(); // yeni tur 1'den başlar
    expect(s.counter('subhan').n, 1);
    expect(s.todayTotal, 34);
    expect(s.undo(), isTrue);
    expect(s.counter('subhan').n, 0);
    expect(s.undo(), isFalse);
    s.setTarget(0);
    for (var i = 0; i < 150; i++) {
      s.add();
    }
    expect(s.counter('subhan').n, 150); // serbest: tur yok
    expect(s.reset(), isTrue);
    expect(s.counter('subhan').n, 0);
    expect(s.counter('subhan').rounds, 0);
  });

  test('tesbihat: 33 × 3, ardından tevhid; bitince önceki zikre döner', () async {
    final s = await DhikrState.load();
    s.select('istigfar');
    s.startTesbihat();
    expect(s.current.id, 'subhan');
    expect(s.targetOf('subhan'), 33);
    for (final id in kTesbihatSeq) {
      expect(s.current.id, id);
      for (var i = 0; i < 32; i++) {
        s.add();
      }
      expect(s.add(), DhikrHit.tesbihatStep);
    }
    expect(s.tesbihat, 3);
    expect(s.add(), DhikrHit.ignored); // tevhid sayılmaz, okunur
    s.stopTesbihat();
    expect(s.tesbihat, isNull);
    expect(s.current.id, 'istigfar');
    expect(s.todayTotal, 99);
  });

  test('kayıt: sayılar, hedef, kendi zikri ve titreşim saklanır; gün değişince bugünkü toplam sıfırlanır', () async {
    var day = DateTime(2026, 9, 28, 10);
    final s = await DhikrState.load(now: () => day);
    final z = s.addCustom('Hasbünallah', 99);
    for (var i = 0; i < 5; i++) {
      s.add();
    }
    s.toggleVibrate();

    final again = await DhikrState.load(now: () => day);
    expect(again.custom.single.title, 'Hasbünallah');
    expect(again.current.id, z.id);
    expect(again.targetOf(z.id), 99);
    expect(again.counter(z.id).n, 5);
    expect(again.vibrate, isFalse);
    expect(again.todayTotal, 5);

    day = DateTime(2026, 9, 29, 8);
    final tomorrow = await DhikrState.load(now: () => day);
    expect(tomorrow.todayTotal, 0);
    expect(tomorrow.counter(z.id).n, 5); // sayaç kalır, yalnız günlük toplam sıfırlanır
    tomorrow.removeCustom(z.id);
    expect(tomorrow.current.id, 'subhan');
  });

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: DhikrScreen()));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
  }

  testWidgets('karta dokununca sayar; liste, hedef ve araçlar görünür', (t) async {
    await open(t);
    expect(find.text('Zikir Sayacı'), findsWidgets);
    for (final l in ['Tesbihat', 'Sübhânallâh', 'Elhamdülillâh', 'Allâhü ekber', 'Salavât', '+ Ekle']) {
      expect(find.text(l), findsWidgets, reason: l);
    }
    expect(find.text('0/33'), findsOneWidget);
    await t.tap(find.text('Saymak için karta dokunun ya da yana kaydırın'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Saymak için karta dokunun ya da yana kaydırın'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('2/33'), findsOneWidget);
    expect(find.text('Bugün toplam 2 zikir'), findsOneWidget);

    // Araç şeridine dokunmak saymaz; geri al bir azaltır
    await t.tap(find.bySemanticsLabel('Geri al'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('1/33'), findsOneWidget);

    // Hedef 100
    await t.tap(find.bySemanticsLabel('Hedef 100'));
    await t.pump();
    expect(find.text('1/100'), findsOneWidget);

    // Başka zikir seçimi
    await t.tap(find.text('Salavât'));
    await t.pump();
    expect(find.text('Allâhümme salli alâ Muhammed'), findsOneWidget);
    expect(find.text('0/100'), findsOneWidget);
    await t.pumpAndSettle();
  });

  testWidgets('tesbihat modu ve tevhid ekranı', (t) async {
    await open(t);
    await t.tap(find.text('Tesbihat'));
    await t.pump();
    expect(find.text('TESBİHAT · 1 / 4'), findsOneWidget);
    for (var step = 0; step < 3; step++) {
      for (var i = 0; i < 33; i++) {
        await t.tap(find.text('Saymak için karta dokunun ya da yana kaydırın'));
        await t.pump(const Duration(milliseconds: 250));
      }
    }
    await t.pumpAndSettle();
    expect(find.text('TESBİHAT · 4 / 4'), findsOneWidget);
    expect(find.text('Tesbihatın sonunda bir kez okunur.'), findsOneWidget);
    await t.tap(find.text('Okudum, bitir'));
    await t.pumpAndSettle();
    expect(find.text('Sübhânallâh'), findsWidgets);
    expect(find.text('Bugün toplam 99 zikir'), findsOneWidget);
  });
}
