import 'package:ezan_saati/data/gunun_sozu.dart';
import 'package:ezan_saati/screens/home_screen.dart';
import 'package:ezan_saati/screens/prayer_times_screen.dart';
import 'package:ezan_saati/services/location_store.dart';
import 'package:ezan_saati/widgets/countdown_banner.dart';
import 'package:ezan_saati/widgets/menu_tile.dart';
import 'package:ezan_saati/widgets/page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'loc_name': 'İstanbul', 'loc_lat': 41.01, 'loc_lng': 28.97});
    await LocationStore.instance.load();
  });

  const order = [
    'Namaz Vakitleri', "Kur'ân-ı Kerîm", 'Dualar', //
    'Hadisler', 'Zikir Sayacı', 'Kıble Bulucu', //
    'Cami Bulucu', 'Dua Zinciri', 'Takibim', //
    'Ramazan', 'Dini Mesajlar', 'Ayarlar',
  ];

  // Üst alan (fotoğraf, konum, kalan süre, ayet, hadis, vakit kartları) her ekranda aynı yükseklikte; uzun
  // ekranda tuşlar uzar, iPhone 13'ten kısa ekranda sayfa kaydırılır. 360×568: GM5 Plus d gibi kısa telefonlar.
  for (final size in const [Size(390, 763), Size(360, 616), Size(360, 568), Size(430, 839), Size(600, 950)]) {
    testWidgets('ana ekran ${size.width.toInt()}×${size.height.toInt()}: 3×4, sabit sıra, sabit üst alan', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(home: HomeScreen()));
      await t.pump();

      final tiles = t.widgetList<MenuTile>(find.byType(MenuTile)).toList();
      expect(tiles.map((m) => m.title), order);
      for (final removed in ['İlahiler', 'Dini Hikâyeler', 'Bebek İsimleri', 'Namaz Öğren']) {
        expect(find.text(removed), findsNothing);
      }

      // 3 sütun × 4 sıra: aynı sıradakiler aynı yükseklikte, sütunlar eşit aralıklı
      final rects = [for (var i = 0; i < 12; i++) t.getRect(find.byType(MenuTile).at(i))];
      for (var r = 0; r < 4; r++) {
        for (var c = 1; c < 3; c++) {
          expect(rects[r * 3 + c].top, moreOrLessEquals(rects[r * 3].top, epsilon: 0.5));
          expect(rects[r * 3 + c].width, moreOrLessEquals(rects[r * 3].width, epsilon: 0.5));
        }
      }
      expect(rects[1].left - rects[0].right, moreOrLessEquals(rects[2].left - rects[1].right, epsilon: 0.5));
      // Tuşlar resim oranının en az %85'i yüksekliğinde (resimleri yalnız alttan kesilir)
      expect(rects.first.height, greaterThanOrEqualTo(rects.first.width * MenuTile.photoAspect * 0.85 - 0.5));

      // Üst alan her ekranda aynı yükseklikte: vakit kartları hep aynı yerde, ortada, ekranın %96'sı
      final banner = t.getRect(find.byType(CountdownBanner));
      expect(banner.bottom, moreOrLessEquals(384 - 2, epsilon: 0.5));
      expect(banner.center.dx, moreOrLessEquals(size.width / 2, epsilon: 0.5));
      expect(banner.width, lessThanOrEqualTo(size.width * 0.96 + 0.5));
      expect(banner.bottom, lessThanOrEqualTo(rects.first.top));

      // Sığmayan ekranda sayfa kaydırılır, sığan ekranda kaydırılmaz
      final fits = rects.last.bottom <= size.height + 0.5;
      final scroll = t.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scroll.physics, fits ? isA<NeverScrollableScrollPhysics>() : isA<ClampingScrollPhysics>());
      // iPhone 13 boyu ve üstündeki telefonlarda (tablette ekran 390 genişliğe ölçeklenir: DesignScale) sığar.
      if (size.width <= 430 && size.height >= 760) expect(fits, isTrue);

      // Sol üstte konum, sağ üstte kalan süre; ana ekranda gündüz/gece düğmesi yok (otomatik, Ayarlar'da)
      expect(find.text('İstanbul'), findsOneWidget);
      expect(find.textContaining(' kalan'), findsOneWidget);
      expect(find.byType(DayNightSwitch), findsNothing);

      // Günün ayeti solda, hadisi sağda; ikisi de vakit kartlarının üstünde
      final ayah = find.byKey(const Key('dailyAyah')), hadith = find.byKey(const Key('dailyHadith'));
      expect(find.textContaining(ayahOfDay(DateTime.now()).meal), findsOneWidget);
      expect(find.textContaining(hadithOfDay(DateTime.now()).text), findsOneWidget);
      expect(t.getRect(ayah).bottom, lessThanOrEqualTo(banner.top + 0.5));
      expect(t.getRect(hadith).bottom, lessThanOrEqualTo(banner.top + 0.5));
      expect(t.getRect(ayah).right, lessThanOrEqualTo(t.getRect(hadith).left));

      // Dokununca ikisi kaynaklarıyla açılır
      await t.tap(ayah);
      await t.pumpAndSettle();
      expect(find.text('GÜNÜN AYETİ'), findsOneWidget);
      expect(find.text('GÜNÜN HADİSİ'), findsOneWidget);
      expect(find.byType(PrayerTimesScreen), findsNothing);
    });
  }
}
