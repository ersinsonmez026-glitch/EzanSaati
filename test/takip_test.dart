import 'package:ezan_saati/screens/tracking_screen.dart';
import 'package:ezan_saati/services/dhikr_store.dart';
import 'package:ezan_saati/services/prayer_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final log = PrayerLog.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await log.load();
  });

  test('namaz işaretleme, seri ve özel gün', () async {
    final today = DateTime(2026, 9, 30);
    for (var i = 1; i <= 3; i++) {
      for (var p = 0; p < 5; p++) {
        log.toggle(today.subtract(Duration(days: i)), p);
      }
    }
    expect(log.count(today.subtract(const Duration(days: 1))), 5);
    expect(log.streak(today), 3); // bugün bitmediği için dünden sayılır
    log.setPaused(today.subtract(const Duration(days: 4)), true);
    for (var p = 0; p < 5; p++) {
      log.toggle(today.subtract(const Duration(days: 5)), p);
    }
    expect(log.streak(today), 4); // özel gün seriyi bozmaz ama sayılmaz
    log.toggle(today, 0);
    expect(log.prayed(today, 0), isTrue);
    log.toggle(today, 0);
    expect(log.prayed(today, 0), isFalse);
    final (done, total) = log.range(today.subtract(const Duration(days: 5)), today.subtract(const Duration(days: 1)));
    expect((done, total), (20, 20)); // 4 gün × 5, özel gün hariç
    // Yeniden yüklenince kayıt yerinde
    await log.load();
    expect(log.count(today.subtract(const Duration(days: 2))), 5);
  });

  test('kaza borcu namaz ve oruç', () async {
    log.setKaza(0, 3);
    log.setKaza(0, log.kaza[0] - 5);
    expect(log.kaza[0], 0); // eksiye düşmez
    log.setKaza(2, 10);
    log.setKazaOruc(7);
    await log.load();
    expect(log.kazaTotal, 10);
    expect(log.kazaOruc, 7);
  });

  test('zikir günlük geçmişi', () async {
    final s = await DhikrState.load(now: () => DateTime(2026, 9, 30, 10));
    s.add();
    s.add();
    s.undo();
    expect(s.onDay(DateTime(2026, 9, 30)), 1);
    final r = await DhikrState.load(now: () => DateTime(2026, 9, 30, 11));
    expect(r.onDay(DateTime(2026, 9, 30)), 1);
  });

  testWidgets('Takibim: namaz, oruç ve kaza; zikir yalnız çekildiyse görünür', (t) async {
    t.view.physicalSize = const Size(390, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: TrackingScreen()));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    expect(find.text('Namazlarım'), findsOneWidget);
    expect(find.text('Oruçlarım'), findsOneWidget);
    expect(find.text('Kaza borcum'), findsOneWidget);
    expect(find.text('Zikirlerim'), findsNothing);

    // Bugünün sabah namazı tablodan işaretlenir
    final now = DateTime.now();
    await t.tap(find.bySemanticsLabel(RegExp('^Sabah ${now.day}\\. gün')).first);
    await t.pump();
    expect(PrayerLog.instance.prayed(now, 0), isTrue);

    // Zikir çekilince zikir tablosu araya girer
    await t.runAsync(() async {
      final s = await DhikrState.load();
      s.add();
    });
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(const MaterialApp(home: TrackingScreen()));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    expect(find.text('Zikirlerim'), findsOneWidget);
    final y1 = t.getTopLeft(find.text('Namazlarım')).dy;
    final y2 = t.getTopLeft(find.text('Zikirlerim')).dy;
    final y3 = t.getTopLeft(find.text('Oruçlarım')).dy;
    expect(y1 < y2 && y2 < y3, isTrue);
  });
}
