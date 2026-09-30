import 'package:ezan_saati/services/hatim_plan.dart';
import 'package:ezan_saati/services/quran_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final plan = HatimPlan.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    plan.reset();
    await plan.load();
  });

  test('ayet sırasından sûre ve ayet', () {
    expect(ayahOfGlobal(1), (1, 1));
    expect(ayahOfGlobal(7), (1, 7));
    expect(ayahOfGlobal(8), (2, 1));
    expect(ayahOfGlobal(262), (2, 255));
    expect(ayahOfGlobal(6236), (114, 6));
    for (var s = 1; s <= 114; s++) {
      expect(ayahOfGlobal(globalAyahNumber(s, 1)), (s, 1));
    }
  });

  test('bölümler Kur\'an\'ı boşluksuz ve eşit böler', () {
    for (final n in HatimPlan.durations) {
      var prev = 0;
      for (var i = 0; i < n; i++) {
        final (a, b) = HatimPlan.portionOf(i, n);
        expect(a, prev + 1);
        expect(b - a + 1, inInclusiveRange(kTotalAyahs ~/ n - 1, kTotalAyahs ~/ n + 2));
        prev = b;
      }
      expect(prev, kTotalAyahs);
    }
  });

  test('plan: gün, geride kalma, okudum ve hatim sayısı', () async {
    final start = DateTime(2026, 9, 1);
    plan.begin(7, start);
    expect(plan.next, 0);
    expect(plan.dayIndex(DateTime(2026, 9, 3, 20)), 2);
    expect(plan.behind(DateTime(2026, 9, 3)), 3);
    plan.markRead(0);
    plan.markRead(1);
    expect(plan.next, 2);
    expect(plan.behind(DateTime(2026, 9, 3)), 1);
    await plan.load(); // kayıt yerinde
    expect(plan.done, {0, 1});
    for (var i = 2; i < 6; i++) {
      expect(plan.markRead(i), isFalse);
    }
    expect(plan.markRead(6), isTrue); // hatim bitti
    expect(plan.active, isFalse);
    expect(plan.completed, 1);
  });
}
