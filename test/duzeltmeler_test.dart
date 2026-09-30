import 'dart:convert';

import 'package:ezan_saati/services/day_utils.dart';
import 'package:ezan_saati/services/dhikr_store.dart';
import 'package:ezan_saati/services/location_store.dart';
import 'package:ezan_saati/services/mosque_mode.dart';
import 'package:ezan_saati/services/premium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Zikir: widget\'ın yazdığı sayı uygulamada kaybolmaz, yarıda kalan tesbihat sürer', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await DhikrState.load();
    s.startTesbihat();
    expect(s.tesbihat, 0);

    // Ana ekran widget'ı kaydı doğrudan değiştirir (uygulamanın bellekteki kopyası eski kalır).
    final p = await SharedPreferences.getInstance();
    final j = jsonDecode(p.getString('zikir_v2')!) as Map<String, dynamic>;
    (j['c'] as Map)['subhan'] = [50, 0];
    SharedPreferences.setMockInitialValues({'zikir_v2': jsonEncode(j)});

    final again = await DhikrState.load();
    expect(again.counter('subhan').n, 50);
    expect(again.tesbihat, 0); // tesbihat modu kapanmadı
    again.stopTesbihat();
    expect(again.tesbihat, isNull);
  });

  test('Gün farkı yaz saatinden etkilenmez', () {
    expect(calendarDaysBetween(DateTime(2027, 3, 27), DateTime(2027, 3, 29)), 2);
    expect(calendarDaysBetween(DateTime(2027, 12, 31, 23, 59), DateTime(2028, 1, 1)), 1);
    expect(previousDay(DateTime(2027, 3, 1)), DateTime(2027, 2, 28));
  });

  test('Cami modu: arka plan görevi kullanıcının seçtiği vakitleri kullanır', () async {
    SharedPreferences.setMockInitialValues({
      'cami_acik': true,
      'cami_vakitler': 1 | (1 << 4), // yalnız sabah ve yatsı
      'cami_sure': 45,
      'cami_gecikme': 15,
      'premium_test': true,
      'loc_name': 'İstanbul',
      'loc_lat': 41.01,
      'loc_lng': 28.97,
    });
    await LocationStore.instance.load();
    await Premium.instance.load();
    final m = MosqueMode.instance;
    m.prayers = [false, true, true, true, true]; // başka ortamdan kalmış varsayılanlar
    await m.load();
    await m.writeWindows();
    final p = await SharedPreferences.getInstance();
    final w = (jsonDecode(p.getString('cami_araliklar')!) as List).cast<List>();
    expect(w, isNotEmpty);
    for (final x in w) {
      expect(x[1] - x[0], 45 * 60000); // cuma öğlesi seçili değil: hepsi 45 dk
    }
    // Günde 2 vakit (ilk gün geçmiş olanlar hariç): 14 günde en çok 28.
    expect(w.length, lessThanOrEqualTo(28));
    expect(w.length, greaterThanOrEqualTo(26));

    // Hiç vakit seçili değilse liste yazılmaz.
    await m.update(toggle: 0);
    await m.update(toggle: 4);
    await m.writeWindows();
    expect(p.getString('cami_araliklar'), isNull);
    Premium.instance.debugSet(false);
  });
}
