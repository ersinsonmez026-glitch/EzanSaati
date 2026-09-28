import 'package:ezan_saati/data/namaz_ogren.dart';
import 'package:ezan_saati/data/namaz_videolari.dart';
import 'package:ezan_saati/screens/about_screen.dart';
import 'package:ezan_saati/screens/learn_namaz_screen.dart';
import 'package:ezan_saati/screens/video_screen.dart';
import 'package:ezan_saati/screens/city_picker_screen.dart';
import 'package:ezan_saati/screens/hadiths_screen.dart';
import 'package:ezan_saati/screens/mosque_finder_screen.dart';
import 'package:ezan_saati/screens/notifications_screen.dart';
import 'package:ezan_saati/screens/settings_screen.dart';
import 'package:ezan_saati/services/app_prefs.dart';
import 'package:ezan_saati/services/ezan_notifications.dart';
import 'package:ezan_saati/services/hadith_store.dart';
import 'package:ezan_saati/services/location_store.dart';
import 'package:ezan_saati/services/mosque_store.dart';
import 'package:ezan_saati/services/takvim.dart';
import 'package:ezan_saati/widgets/page_shell.dart';
import 'package:ezan_saati/widgets/reading_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _fakeHadith(String id) => {
      'id': id,
      'title': 'Başlık $id',
      'hadeeth': 'Metin $id',
      'hadeeth_ar': 'نص $id',
      'attribution': 'Müslim rivayet etmiştir',
      'grade': 'Sahih Hadis',
      'explanation': 'Açıklama $id',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const loc = AppLocation(name: 'İstanbul', lat: 41.01, lng: 28.97);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'loc_name': 'İstanbul', 'loc_lat': 41.01, 'loc_lng': 28.97});
    await LocationStore.instance.load();
  });

  group('Hadisler (HadeethEnc)', () {
    test('metinler kaynaktan değiştirilmeden alınır, saklanır ve internetsiz de açılır', () async {
      var calls = 0;
      var day = DateTime(2026, 9, 28);
      final store = HadithStore(fetch: (id) async {
        calls++;
        return _fakeHadith(id);
      }, now: () => day);
      final items = await store.load();
      expect(items.map((h) => h.id), kHadithIds);
      expect(items.first.text, 'Metin ${kHadithIds.first}');
      expect(items.first.url, 'https://hadeethenc.com/tr/browse/hadith/${kHadithIds.first}');
      expect(calls, kHadithIds.length);

      // Bir hafta dolmadan yeniden indirilmez
      await store.load();
      expect(calls, kHadithIds.length);

      // Bağlantı yoksa saklanan metinler döner
      day = DateTime(2026, 10, 10);
      final offline = HadithStore(fetch: (_) async => throw Exception('internet yok'), now: () => day);
      expect((await offline.load()).length, kHadithIds.length);
    });

    test('hiç indirilmemişse ve internet yoksa hata verir', () async {
      final store = HadithStore(fetch: (_) async => throw Exception('internet yok'));
      expect(store.load(), throwsException);
    });

    testWidgets('sayfa: günün hadisi, liste, favori sekmesi ve okuma', (t) async {
      t.view.physicalSize = const Size(390, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final store = HadithStore(fetch: (id) async => _fakeHadith(id));
      await t.pumpWidget(MaterialApp(home: HadithsScreen(store: store)));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pumpAndSettle();
      expect(find.text('Günün Hadisi'), findsOneWidget);
      expect(find.text('Tüm Hadisler'), findsOneWidget);
      expect(find.text('Başlık ${kHadithIds[1]}'), findsOneWidget);
      await t.tap(find.text('Favorilerim'));
      await t.pump();
      expect(find.textContaining('Henüz favori hadisiniz yok'), findsOneWidget);
      await t.tap(find.text('Tüm Hadisler'));
      await t.pump();
      await t.tap(find.text('Başlık ${kHadithIds[1]}'));
      await t.pumpAndSettle();
      expect(find.text('Metin ${kHadithIds[1]}'), findsOneWidget);
      expect(find.text('Sahih Hadis'), findsOneWidget);
      await t.tap(find.text('Açıklama'));
      await t.pump();
      expect(find.text('Açıklama ${kHadithIds[1]}'), findsOneWidget);
    });
  });

  group('Cami Bulucu (OpenStreetMap)', () {
    Map<String, dynamic> resp(int n) => {
          'elements': [
            for (var i = 0; i < n; i++)
              {
                'type': 'way',
                'center': {'lat': 41.01 + i * 0.002, 'lon': 28.97},
                'tags': i == 1 ? <String, dynamic>{} : {'name': 'Cami $i'},
              },
          ],
        };

    test('yakından uzağa sıralanır, adsız kayıt gösterilir, az sonuçta alan genişler', () async {
      final radii = <String>[];
      final store = MosqueStore(fetch: (q) async {
        radii.add(RegExp(r'around:(\d+)').firstMatch(q)!.group(1)!);
        return resp(radii.length == 1 ? 2 : 6);
      });
      final list = await store.near(41.01, 28.97);
      expect(radii, ['1500', '4000']);
      expect(list.first.name, 'Cami 0');
      expect(list[1].name, 'Cami (adı kayıtlı değil)');
      expect(list.map((m) => m.km), orderedEquals([...list.map((m) => m.km)]..sort()));
      expect(list[2].directionText, 'Kuzey');
      expect(list[2].distanceText, endsWith('m'));
    });

    testWidgets('sayfa listeyi ve yol tarifi düğmelerini gösterir', (t) async {
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: MosqueFinderScreen(store: MosqueStore(fetch: (_) async => resp(6)))));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      expect(find.text('Yakındaki Camiler'), findsOneWidget);
      expect(find.text('Cami 0'), findsOneWidget);
      expect(find.text('Yol tarifi'), findsNWidgets(6));
      expect(find.textContaining('Şehir merkezine göre aranıyor'), findsOneWidget);
    });

    testWidgets('bağlantı yoksa anlaşılır uyarı ve haritada arama', (t) async {
      await t.pumpWidget(MaterialApp(
        home: MosqueFinderScreen(store: MosqueStore(fetch: (_) async => throw Exception('internet yok'))),
      ));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pumpAndSettle();
      expect(find.textContaining('Camiler yüklenemedi'), findsOneWidget);
      expect(find.text('Haritada ara'), findsOneWidget);
    });
  });

  group('Ezan bildirimleri', () {
    test('kapalıyken hiçbir şey kurulmaz', () {
      expect(planNotifications(s: EzanSettings(), loc: loc, now: DateTime(2026, 9, 28, 12)), isEmpty);
    });

    test('açık vakitler, önceden hatırlatma, Güneş uyarısı ve dinî günler', () {
      final s = EzanSettings(enabled: true, before: 10, vakit: [true, true, true, true, true, true]);
      final now = DateTime(2026, 9, 28, 0, 1);
      final plan = planNotifications(
        s: s,
        loc: loc,
        now: now,
        days: 2,
        religious: [ReligiousDay(DateTime(2026, 9, 29), 'Deneme Kandili', '1 Recep 1448', 'lamp')],
      );
      // 2 gün × (6 vakit + 5 önceden hatırlatma; Güneş'te yok) + 1 dinî gün
      expect(plan.length, 2 * 11 + 1);
      expect(plan.where((n) => n.title == 'Güneş doğuyor').length, 2);
      expect(plan.where((n) => n.title.startsWith('Güneş vaktine')), isEmpty);
      expect(plan.where((n) => n.title == 'Öğle vaktine 10 dakika').length, 2);
      final kandil = plan.singleWhere((n) => n.title == 'Bugün Deneme Kandili');
      expect(kandil.at, DateTime(2026, 9, 29, 9));
      expect(plan.map((n) => n.id).toSet().length, plan.length); // kimlikler benzersiz
      expect(plan.every((n) => n.at.isAfter(now)), isTrue);
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].at.isBefore(plan[i - 1].at), isFalse);
      }
    });

    test('yalnız seçilen vakitler; geçmiş vakitler kurulmaz', () {
      final s = EzanSettings(enabled: true, vakit: [false, false, true, false, false, false], religiousDays: false);
      final plan = planNotifications(s: s, loc: loc, now: DateTime(2026, 9, 28, 23), days: 3);
      expect(plan.length, 2); // bugünkü öğle geçti; yarın ve öbür gün
      expect(plan.every((n) => n.title == 'Öğle vakti'), isTrue);
    });

    testWidgets('Bildirimler sayfası', (t) async {
      t.view.physicalSize = const Size(390, 2000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(home: NotificationsScreen()));
      await t.pump();
      expect(find.text('Bildirim Ayarları'), findsOneWidget);
      expect(find.text('Ezan Vakitleri'), findsOneWidget);
      expect(find.text('Tüm ezan bildirimleri'), findsOneWidget);
      expect(find.text('Kandil ve bayramlar'), findsOneWidget);
      expect(find.textContaining('Bildirimler kapalı'), findsOneWidget);
    });
  });

  testWidgets('Ayarlar, Hakkında ve Şehir seçimi yeni tasarımla açılır', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await t.pump();
    for (final l in ['Konum', 'Görünüm', 'Bildirimler', 'Hesaplama', 'Hakkında', 'Görsel', 'Krem', 'Yeşil', 'Otomatik', 'Gündüz', 'Gece']) {
      expect(find.text(l), findsWidgets, reason: l);
    }
    await t.tap(find.text('Gizlilik ve kaynaklar'));
    await t.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('Gizlilik'), findsOneWidget);
    expect(find.textContaining('HadeethEnc'), findsWidgets);
  });

  testWidgets('Şehir seçimi: konum düğmesi ve Türkçe arama', (t) async {
    t.view.physicalSize = const Size(390, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: CityPickerScreen()));
    await t.pump();
    expect(find.text('Konumumu otomatik bul'), findsOneWidget);
    expect(find.text('Adana'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'izmir');
    await t.pump();
    expect(find.text('İzmir'), findsOneWidget);
    expect(find.text('Adana'), findsNothing);
  });

  test('Gündüz/Gece seçimi vakitten bağımsız görünümü belirler ve saklanır', () async {
    await AppPrefs.instance.setDayMode(DayMode.gece);
    expect(isDaytime(), isFalse);
    expect(PagePalette.current().night, isTrue);
    await AppPrefs.instance.setDayMode(DayMode.gunduz);
    expect(isDaytime(), isTrue);
    expect(PagePalette.current().night, isFalse);
    await AppPrefs.instance.setDayMode(DayMode.otomatik);
    expect(isDaytime(), isDaytimeByClock());
    expect((await SharedPreferences.getInstance()).getInt('day_mode'), DayMode.otomatik.index);
  });

  group('Namaz videoları (Diyanet)', () {
    test('her namaz ve abdest/gusül/teyemmüm için video var, kimlikler benzersiz', () {
      expect(namazVideolari.map((v) => v.id).toSet().length, namazVideolari.length);
      for (final n in namazlar) {
        expect(videosFor(n.key), isNotEmpty, reason: n.key);
      }
      for (final k in ['abdest', 'gusul', 'teyemmum']) {
        expect(videosFor(k), isNotEmpty, reason: k);
      }
      for (final v in namazVideolari) {
        expect(kVideoTopics.containsKey(v.topic), isTrue, reason: v.id);
        expect(RegExp(r'^[\w-]{11}$').hasMatch(v.id), isTrue, reason: v.id);
        expect(v.channel, contains('Diyanet'));
      }
    });

    testWidgets('Namaz Öğren: videolu anlatım kartı, Videolar listesi ve video ekranı', (t) async {
      t.view.physicalSize = const Size(412, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(home: LearnNamazScreen()));
      await t.pump();
      expect(find.text('Videolu Anlatım (Diyanet)'), findsOneWidget);
      await t.tap(find.text('Videolar'));
      await t.pump();
      expect(find.text('Bayram Namazı'), findsOneWidget);
      await t.tap(find.text('Abdest Nasıl Alınır?'));
      await t.pumpAndSettle();
      expect(find.byType(VideoScreen), findsOneWidget);
      expect(find.text("YouTube'da aç"), findsOneWidget);
      expect(find.text('Diğer Videolar'), findsOneWidget);
    });
  });
}
