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
    expect(msg, contains('1.000 Salavat'));
    expect(msg, endsWith(chainLink(c.id)));
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

  testWidgets('yeni zincir: dua, adet, süre; sonra WhatsApp daveti ve pay alma', (t) async {
    t.view.physicalSize = const Size(390, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(() => as('alice', 'Ali'));
    await t.pumpWidget(const MaterialApp(home: DuaCircleScreen()));
    await t.pump();
    expect(find.text('Gruplarım'), findsNothing);
    expect(find.text('Nasıl çalışır?'), findsOneWidget);
    expect(find.text('Uygulamayı tavsiye et'), findsOneWidget);

    await t.tap(find.byKey(const Key('startChain')));
    await t.pumpAndSettle();
    expect(find.text('1. NE OKUNACAK?'), findsOneWidget);
    expect(find.text('2. KAÇ TANE?'), findsOneWidget);
    expect(find.text('3. NE ZAMANA KADAR?'), findsOneWidget);
    await t.tap(find.text('İstiğfar'));
    await t.pump();
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('doStart')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pumpAndSettle();
    expect(find.text('Zincir hazır'), findsOneWidget);
    expect(find.text("WhatsApp'tan davet gönder"), findsOneWidget);
    expect(find.text('0 / 100 istiğfar okundu'), findsOneWidget);

    await t.tap(find.byKey(const Key('takeShare')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('askText')), '20');
    await t.runAsync(() async {
      await t.tap(find.text('Al'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await t.pumpAndSettle();
    expect(find.text('0 / 20'), findsOneWidget);
    expect(find.text('80 boşta'), findsOneWidget);
    await t.runAsync(() async {
      await t.tap(find.text('+10'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await t.pumpAndSettle();
    expect(find.text('10 / 20'), findsOneWidget);
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
