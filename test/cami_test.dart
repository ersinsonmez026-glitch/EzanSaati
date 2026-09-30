import 'package:ezan_saati/services/location_store.dart';
import 'package:ezan_saati/services/mosque_mode.dart';
import 'package:ezan_saati/services/prayer_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const loc = AppLocation(name: 'İstanbul', lat: 41.01, lng: 28.97);

  test('Cami modu: seçili vakitlerde, ezandan sonra, cuma öğlesi uzun', () {
    final m = MosqueMode.instance
      ..prayers = [false, true, true, true, true]
      ..delay = 5
      ..minutes = 20
      ..friday = 60;
    final thursday = DateTime(2026, 10, 1); // perşembe, gün başı
    final w = m.windows(loc, thursday, days: 2);
    expect(w.length, 8); // 2 gün × 4 vakit (sabah kapalı)
    final slots = PrayerCalc.forDay(loc, thursday).slots;
    expect(w.first[0], slots[2].time.add(const Duration(minutes: 5)).millisecondsSinceEpoch); // öğle + 5 dk
    expect(w.first[1] - w.first[0], 20 * 60000);
    final fridayNoon = w[4]; // cuma öğle
    expect(fridayNoon[1] - fridayNoon[0], 60 * 60000);
    expect(w[5][1] - w[5][0], 20 * 60000); // cuma ikindi normal

    // Geçmiş aralıklar alınmaz.
    final noon = slots[2].time.add(const Duration(minutes: 40));
    expect(m.windows(loc, noon, days: 1).length, 3);
  });
}
