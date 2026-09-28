import 'package:ezan_saati/screens/home_screen.dart';
import 'package:ezan_saati/services/location_store.dart';
import 'package:ezan_saati/widgets/countdown_banner.dart';
import 'package:ezan_saati/widgets/menu_tile.dart';
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
    'Namaz Vakitleri', 'Sureler', 'Dualar', //
    'Zikir Sayacı', 'Kıble Bulucu', 'Cami Bulucu', //
    'Dua Çemberi', 'Hadisler', 'Ramazan', //
    'Namaz Öğren', 'Dini Mesajlar', 'Ayarlar',
  ];

  for (final size in const [Size(390, 763), Size(360, 616), Size(430, 839)]) {
    testWidgets('ana ekran ${size.width.toInt()}×${size.height.toInt()}: 3×4, sabit sıra, kaydırmasız', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(home: HomeScreen()));
      await t.pump();

      final tiles = t.widgetList<MenuTile>(find.byType(MenuTile)).toList();
      expect(tiles.map((m) => m.title), order);
      for (final removed in ['İlahiler', 'Dini Hikâyeler', 'Bebek İsimleri']) {
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

      // Her şey ekrana sığar: son sıra ekranın içinde, sayfa kaydırılmaz
      expect(rects.last.bottom, lessThanOrEqualTo(size.height + 0.5));
      final scroll = t.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scroll.physics, isA<NeverScrollableScrollPhysics>());

      // Geri sayım tam ortada ve ekran genişliğinde
      final banner = t.getRect(find.byType(CountdownBanner));
      expect(banner.center.dx, moreOrLessEquals(size.width / 2, epsilon: 0.5));
      expect(banner.width, moreOrLessEquals(size.width - 12, epsilon: 0.5));
      expect(banner.bottom, lessThanOrEqualTo(rects.first.top));
    });
  }
}
