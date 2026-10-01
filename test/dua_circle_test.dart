import 'package:ezan_saati/screens/dua_circle_screen.dart';
import 'package:ezan_saati/services/prayer_groups.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bağlantılı Dua Zinciri: birkaç telefon ("alice" başlatır, ötekiler bağlantıyı açar) aynı Firestore'u
/// sırayla kullanır. Güvenlik kuralları ayrıca emülatörde test edilir (test_rules/).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  final sync = GroupSync.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    sync.resetLocal();
  });

  tearDown(() => sync.stop());

  Future<void> as(String uid, String name) async {
    SharedPreferences.setMockInitialValues({'cember_ad': name});
    await sync.startWith(db, uid, await SharedPreferences.getInstance());
    await pumpEventQueue();
  }

  test('zincir bağlantısı ve WhatsApp daveti', () async {
    await as('alice', 'Ali');
    final c = await sync.startChain(type: 'salavat', name: '1.000 Salavat', unit: 'salavat', total: 1000, days: 7);
    expect(validChainId(c.id), isTrue);
    expect(validChainId('kisa'), isFalse);
    expect(chainLink(c.id), 'https://ezansaati-premium-2026.web.app/zincir?k=${c.id}');
    final msg = chainInviteMessage(c);
    expect(msg, '🤲 Dua Zincirimize Katılır mısın?\n\n'
        '1.000 Salavat için başlattığımız zincire sen de katılabilirsin.\n\n'
        '🔗 Zincire Katıl: ${chainLink(c.id)}\n\n'
        'Allah kabul etsin. 🌿');
    expect(msg, isNot(contains('Ali'))); // kişinin adı ya da numarası mesaja yazılmaz
    expect(appSuggestMessage(), endsWith(kAppLink));
  });

  test('hatim: bağlantıyı açan cüz alır ve zincir listesine girer', () async {
    await as('alice', 'Ali');
    final h = await sync.startChain(type: 'hatim', name: 'Hatim', unit: 'cüz', total: 30, days: 7);
    await pumpEventQueue();
    expect(sync.chains.single.memberUids, ['alice']);

    await as('bob', 'Veli');
    expect(sync.chains, isEmpty);
    await sync.open(h.id);
    await pumpEventQueue();
    final c = sync.chain(h.id)!;
    expect(sync.isMember(c), isFalse);
    expect(c.full, isFalse);
    await sync.takeParts(c, [5, 6]);
    await pumpEventQueue();
    final after = sync.chain(h.id)!;
    expect(sync.isMember(after), isTrue);
    expect(after.partsOf('bob'), [5, 6]);
    expect(sync.chains.map((x) => x.id), [h.id]);
    await sync.markPart(after, 5, true);
    await pumpEventQueue();
    expect(sync.chain(h.id)!.done, 1);

    await as('alice', 'Ali');
    await pumpEventQueue();
    expect(sync.chain(h.id)!.slots[5]!.name, 'Veli');
    expect(sync.chain(h.id)!.taken, 2);
  });

  test('sayılı zincir: paylar toplamı hedefi geçmez, dolunca yeni gelen alamaz', () async {
    await as('alice', 'Ali');
    final s = await sync.startChain(type: 'salavat', name: '100 Salavat', unit: 'salavat', total: 100, days: 3);

    await as('bob', 'Veli');
    await sync.open(s.id);
    await pumpEventQueue();
    await sync.takeAmount(sync.chain(s.id)!, 60);
    await pumpEventQueue();
    expect(sync.chain(s.id)!.free, 40);

    await as('eve', 'Ayşe');
    await sync.open(s.id);
    await pumpEventQueue();
    expect(() => sync.takeAmount(sync.chain(s.id)!, 41), throwsStateError);
    await sync.takeAmount(sync.chain(s.id)!, 40);
    await pumpEventQueue();
    expect(sync.chain(s.id)!.full, isTrue);

    await as('carl', 'Can');
    await sync.open(s.id);
    await pumpEventQueue();
    final full = sync.chain(s.id)!;
    expect(full.full, isTrue);
    expect(sync.isMember(full), isFalse);
    expect(() => sync.takeAmount(full, 1), throwsStateError);
    expect(sync.chains, isEmpty); // dolu zincire katılmadı, listesine girmedi

    // Ayşe okumadığı payını bırakınca yer açılır.
    await as('eve', 'Ayşe');
    await pumpEventQueue();
    await sync.releaseAmount(sync.chain(s.id)!);
    await pumpEventQueue();
    expect(sync.chain(s.id)!.free, 40);
    expect(sync.chain(s.id)!.claimOf('eve'), isNull);

    await as('bob', 'Veli');
    await pumpEventQueue();
    await sync.setDone(sync.chain(s.id)!, 60);
    await pumpEventQueue();
    expect(sync.chain(s.id)!.done, 60);
  });

  test('silinen ya da olmayan zincir', () async {
    await as('bob', 'Veli');
    await sync.open('AbCdEfGhIjKlMnOpQrSt');
    await pumpEventQueue();
    expect(sync.chain('AbCdEfGhIjKlMnOpQrSt'), isNull);
    expect(sync.isMissing('AbCdEfGhIjKlMnOpQrSt'), isTrue);
  });

  testWidgets('zincir oluştur: ne, kaç tane, kaç gün, kendi payı; sonra sayaç', (t) async {
    t.view.physicalSize = const Size(390, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(() => as('alice', 'Ali'));
    await t.pumpWidget(const MaterialApp(home: DuaCircleScreen()));
    await t.pump();
    // Zinciri olmayan kişi oluşturma formunu görür; solda menü.
    expect(find.text('Başlattıklarım'), findsOneWidget);
    expect(find.text('Katıldıklarım'), findsOneWidget);
    expect(find.text('Ne okunacak?'), findsOneWidget);
    expect(find.text('Uygulamayı tavsiye et'), findsNothing); // Ayarlar'a taşındı

    await t.tap(find.byKey(const Key('typePick')));
    await t.pumpAndSettle();
    await t.tap(find.text('İstiğfar').last);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('total')), '100');
    await t.enterText(find.byKey(const Key('days')), '10');
    await t.enterText(find.byKey(const Key('myShare')), '20');
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('doStart')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pumpAndSettle();
    final c = sync.chains.single;
    expect(c.name, '100 İstiğfar');
    expect(c.daysLeft, 10);
    expect(c.claimOf('alice')!.amount, 20);
    expect(sync.pendingReadings.single.id, c.id); // kurucunun payı Zikir Sayacı'nda bekler
    expect(find.text('Başlattıklarım (1)'), findsOneWidget);
    expect(find.text('100 İstiğfar'), findsOneWidget);

    // Zincir sayfası: kurucu "Şimdi oku / Daha sonra" görmez, kendi payını görür.
    await t.tap(find.text('100 İstiğfar'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('readNow')), findsNothing);
    expect(find.text('0 / 20 istiğfar'), findsOneWidget);
    expect(find.text('Siz'), findsOneWidget);
    expect(find.text('Toplam'), findsOneWidget);

    // Sayaç: her dokunuş bir sayar, zincire yazılır.
    await t.tap(find.byKey(const Key('continueRead')));
    await t.pumpAndSettle();
    expect(find.text('/ 20 istiğfar'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const Key('chainTap')));
      await t.pump();
    }
    expect(find.text('3'), findsOneWidget);
    await t.runAsync(() async {
      await t.pump(const Duration(seconds: 3)); // yazma gecikmesi
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await t.pumpAndSettle();
    expect(sync.chain(c.id)!.claimOf('alice')!.done, 3);
  });

  testWidgets('bağlantıyı açan: kaç tane, Şimdi oku / Daha sonra', (t) async {
    t.view.physicalSize = const Size(390, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    late String id;
    await t.runAsync(() async {
      await as('alice', 'Ali');
      id = (await sync.startChain(type: 'salavat', name: '1.000 Salavat', unit: 'salavat', total: 1000, days: 7)).id;
      await as('ayse', 'Ayşe');
    });
    await t.pumpWidget(MaterialApp(home: ChainScreen(chainId: id)));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pumpAndSettle();
    expect(find.text('Kaç salavat okuyacaksın?'), findsOneWidget);
    await t.enterText(find.byKey(const Key('amount')), '50');
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('readLater')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pumpAndSettle();
    expect(find.text('0 / 50 salavat'), findsOneWidget);
    expect(sync.pendingReadings.single.id, id);
    expect(sync.chains.single.id, id); // Katıldıklarım listesine girdi
  });

  testWidgets('dolu zincir bağlantısı: "Zincir doldu" yazar, pay alınamaz', (t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    late String id;
    await t.runAsync(() async {
      await as('alice', 'Ali');
      final s = await sync.startChain(type: 'salavat', name: '10 Salavat', unit: 'salavat', total: 10, days: 3);
      id = s.id;
      await pumpEventQueue();
      await sync.takeAmount(sync.chain(id)!, 10);
      await as('carl', 'Can');
    });
    await t.pumpWidget(MaterialApp(home: ChainScreen(chainId: id)));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pumpAndSettle();
    expect(find.text('Zincir doldu'), findsOneWidget);
    expect(find.byKey(const Key('takeShare')), findsNothing);
    expect(find.text("WhatsApp'tan davet gönder"), findsNothing);
    expect(find.text('Ali'), findsOneWidget); // katılanlar listesi görünür
  });
}
