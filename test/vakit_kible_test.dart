import 'dart:async';

import 'package:ezan_saati/screens/prayer_times_screen.dart';
import 'package:ezan_saati/screens/qibla_screen.dart';
import 'package:ezan_saati/services/location_store.dart';
import 'package:ezan_saati/services/prayer_calc.dart';
import 'package:ezan_saati/services/takvim.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'loc_name': 'İstanbul', 'loc_lat': 41.01, 'loc_lng': 28.97});
    await LocationStore.instance.load();
  });

  test('hicrî takvim Diyanet 2026-27 dinî günleriyle aynı gün', () async {
    final t = await TakvimData.load();
    expect(t.religious, hasLength(13));
    for (final e in t.religious) {
      // Veri "1 Recep 1448" biçiminde; hesaplanan hicrî tarih birebir tutmalı.
      expect('${HijriDate.of(e.date)}', e.hijri, reason: '${e.name} ${e.date}');
    }
    expect('${HijriDate.of(DateTime(2027, 2, 8))}', '1 Ramazan 1448');
    expect(hijriMonthStart(DateTime(2027, 2, 20)), DateTime(2027, 2, 8));
    expect(hijriMonthLength(DateTime(2027, 2, 8)), 29);
  });

  test('miladi takvim: resmî tatil, yarım gün ve dinî gün türleri', () async {
    final t = await TakvimData.load();
    expect(t.on(DateTime(2026, 10, 29)).single.holiday, isTrue);
    expect(t.on(DateTime(2026, 10, 28)).single.half, isTrue);
    expect(t.on(DateTime(2027, 1, 4)).single.religious, isTrue);
    expect(t.upcomingReligious(DateTime(2026, 9, 28)).first.name, 'Üç Ayların Başlangıcı');
  });

  Future<void> open(WidgetTester t, Widget page) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: page));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump();
  }

  testWidgets('Namaz Vakitleri: 6 vakit, gün seçimi, alt sayfalar ve geri dönüş', (t) async {
    await open(t, const PrayerTimesScreen());
    for (final n in ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']) {
      expect(find.textContaining(n), findsWidgets, reason: n);
    }
    expect(find.text('Şimdi'), findsOneWidget);
    expect(find.textContaining('vaktine kalan süre'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Sonraki gün'));
    await t.pump();
    expect(find.text('Yarın'), findsOneWidget);
    await t.tap(find.text('Yarın'));
    await t.pump();
    expect(find.text('Bugün'), findsOneWidget);

    await t.tap(find.text('İmsakiye'));
    await t.pump();
    expect(find.text('Tarih'), findsOneWidget);
    // Bugün + sonraki 6 gün = 7 gün; 8. gün yok
    final today = DateTime.now();
    for (var i = 0; i < 8; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      expect(find.text(formatShortDateTr(d)), i < 7 ? findsOneWidget : findsNothing, reason: 'gün $i');
    }
    expect(find.text('Bugün ve sonraki 6 gün'), findsOneWidget);

    // Geri tuşu önce Namaz Vakitleri'ne döner
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.text('Şimdi'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Hicri Takvim'));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump();
    expect(find.text('Önemli Dinî Günler'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pump();

    await t.tap(find.bySemanticsLabel('Miladi Takvim'));
    await t.pump();
    expect(find.text('Resmî tatil'), findsWidgets);
    await t.tap(find.bySemanticsLabel('Sonraki ay'));
    await t.pump();
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.text('Şimdi'), findsOneWidget);
  });

  testWidgets('Kıble: pusulaya göre yön, hizalanınca onay, yardım bölümü', (t) async {
    final ctl = StreamController<Object?>();
    t.binding.defaultBinaryMessenger.setMockStreamHandler(
      const EventChannel('ezan_saati/compass'),
      MockStreamHandler.inline(onListen: (args, sink) {
        ctl.stream.listen(sink.success);
      }),
    );
    addTearDown(ctl.close);
    await open(t, const QiblaScreen());
    expect(find.text('Telefonu düz tutun'), findsOneWidget);
    expect(find.text('152°'), findsWidgets); // İstanbul kıble açısı
    expect(find.text('2.406 km'), findsOneWidget);

    ctl.add([30.0, 3]);
    await t.pump();
    await t.pump();
    expect(find.text('Sağa dönün · 122°'), findsOneWidget);

    ctl.add([152.0, 3]);
    await t.pump();
    await t.pump();
    expect(find.text('Kıble yönündesiniz'), findsNothing); // yumuşatma: hemen oturmaz
    for (var i = 0; i < 30; i++) {
      ctl.add([152.0, 3]);
      await t.pump();
    }
    expect(find.text('Kıble yönündesiniz'), findsOneWidget);

    ctl.add([152.0, 0]); // düşük hassasiyet
    await t.pump();
    await t.pump();
    expect(find.textContaining('Pusula hassasiyeti düşük'), findsOneWidget);

    expect(find.textContaining('Mıknatıslı kılıf'), findsNothing);
    await t.tap(find.text('Pusula yanlış mı gösteriyor?'));
    await t.pump();
    expect(find.textContaining('Mıknatıslı kılıf'), findsOneWidget);
  });
}
