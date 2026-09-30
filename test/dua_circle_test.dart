import 'package:ezan_saati/screens/dua_circle_screen.dart';
import 'package:ezan_saati/services/prayer_groups.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gruplu Dua Zinciri: iki telefon (kurucu "alice", üye "bob") aynı Firestore'u sırayla kullanır.
/// Güvenlik kuralları ayrıca emülatörde test edilir (test_rules/).
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

  test('grup kodu ve bağlantısı', () {
    final code = newGroupCode();
    expect(code.length, 6);
    expect(RegExp(r'^[A-Z2-9]{6}$').hasMatch(code), isTrue);
    expect(formatCode('AB4K7P'), 'AB4 K7P');
    expect(normalizeCode('ab4 k7p'), 'AB4K7P');
    expect(groupLink('AB4K7P'), 'https://ezansaati-premium-2026.web.app/grup?k=AB4K7P');
    final msg = groupInviteMessage(const PrayerGroup(
        id: 'g', name: 'Aile', ownerUid: 'a', ownerName: 'Ali', code: 'AB4K7P', memberUids: ['a']));
    expect(msg, contains('"Aile" dua grubuna'));
    expect(msg, endsWith(groupLink('AB4K7P')));
    expect(msg, isNot(contains('0532'))); // numara yok
    expect(appSuggestMessage(), endsWith(kAppLink));
  });

  test('grup kurulur, bob kodla katılır, hatimde cüz alır ve okur', () async {
    await as('alice', 'Ali');
    final g = await sync.createGroup('Aile');
    await pumpEventQueue();
    expect(sync.groups.single.name, 'Aile');

    await as('bob', 'Veli');
    expect(sync.groups, isEmpty);
    final info = await sync.lookupCode(formatCode(g.code));
    expect(info, isNotNull);
    expect(info!.$2, 'Aile');
    expect(info.$3, 'Ali');
    expect(await sync.lookupCode('ZZZZZZ'), isNull);
    await sync.joinGroup(info.$1);
    await pumpEventQueue();
    expect(sync.groups.single.memberUids, ['alice', 'bob']);
    expect(sync.groups.single.nameOf('alice'), 'Ali');

    await as('alice', 'Ali');
    final c = await sync.startChain(
        groupId: g.id, type: 'hatim', name: 'Hatim', unit: 'cüz', total: 30, mode: 'pick', days: 7);
    await pumpEventQueue();
    expect(sync.chains.single.groupName, 'Aile');
    expect(sync.chains.single.taken, 0);

    await as('bob', 'Veli');
    var hc = sync.chain(g.id, c.id)!;
    await sync.takeParts(hc, [7, 8]);
    await pumpEventQueue();
    hc = sync.chain(g.id, c.id)!;
    expect(hc.partsOf('bob'), [7, 8]);
    expect(hc.slots[7]!.name, 'Veli');
    await sync.markPart(hc, 7, true);
    await pumpEventQueue();
    hc = sync.chain(g.id, c.id)!;
    expect(hc.done, 1);
    expect(hc.taken, 2);
    expect(hc.active, isTrue);
  });

  test('eşit bölmede cüzler ve adetler üyelere dağıtılır', () async {
    await as('alice', 'Ali');
    final g = await sync.createGroup('Cami cemaati');
    await as('bob', 'Veli');
    await sync.joinGroup(g.id);
    await as('carol', 'Ayşe');
    await sync.joinGroup(g.id);
    await pumpEventQueue();

    final h = await sync.startChain(
        groupId: g.id, type: 'hatim', name: 'Hatim', unit: 'cüz', total: 30, mode: 'equal', days: 7);
    final s = await sync.startChain(
        groupId: g.id, type: 'salavat', name: '1.000 Salavat', unit: 'salavat', total: 1000, mode: 'equal', days: 3);
    await pumpEventQueue();
    final hc = sync.chain(g.id, h.id)!;
    expect(hc.taken, 30);
    expect(hc.partsOf('alice'), List.generate(10, (i) => i + 1));
    expect(hc.partsOf('carol'), List.generate(10, (i) => i + 21));
    final sc = sync.chain(g.id, s.id)!;
    expect(sc.claims.values.map((x) => x.amount).toList()..sort(), [333, 333, 334]);
    expect(sc.taken, 1000);

    await sync.setDone(sc, 400); // payından fazlası yazılmaz
    await pumpEventQueue();
    expect(sync.chain(g.id, s.id)!.claimOf('carol')!.done, sc.claimOf('carol')!.amount);
  });

  test('sayılı zincirde pay alınır, değiştirilir; ayrılan grubu görmez', () async {
    await as('alice', 'Ali');
    final g = await sync.createGroup('Aile');
    await as('bob', 'Veli');
    await sync.joinGroup(g.id);
    await pumpEventQueue();
    final c = await sync.startChain(
        groupId: g.id, type: 'yasin', name: '41 Yâsin', unit: 'Yâsin', total: 41, mode: 'pick', days: 7);
    await pumpEventQueue();
    await sync.setAmount(sync.chain(g.id, c.id)!, 5);
    await pumpEventQueue();
    await sync.setDone(sync.chain(g.id, c.id)!, 2);
    await sync.setAmount(sync.chain(g.id, c.id)!, 7);
    await pumpEventQueue();
    final x = sync.chain(g.id, c.id)!;
    expect(x.claimOf('bob')!.amount, 7);
    expect(x.claimOf('bob')!.done, 2);
    expect(x.free, 34);

    await sync.leaveGroup(sync.group(g.id)!);
    await pumpEventQueue();
    expect(sync.groups, isEmpty);
    expect(sync.chains, isEmpty);
  });

  test('kurucu grubu silince kod da silinir', () async {
    await as('alice', 'Ali');
    final g = await sync.createGroup('Aile');
    await sync.startChain(groupId: g.id, type: 'hatim', name: 'Hatim', unit: 'cüz', total: 30, mode: 'pick', days: 7);
    await pumpEventQueue();
    await sync.leaveGroup(sync.group(g.id)!);
    await pumpEventQueue();
    expect(sync.groups, isEmpty);
    expect(await sync.lookupCode(g.code), isNull);
    expect((await db.collection('groups').doc(g.id).get()).exists, isFalse);
  });

  test('yalnız ben zinciri telefonda tutulur', () async {
    SharedPreferences.setMockInitialValues({});
    await sync.load();
    final c = await sync.startChain(
        groupId: null, type: 'istigfar', name: '100 İstiğfar', unit: 'istiğfar', total: 100, mode: 'pick', days: 3);
    expect(c.solo, isTrue);
    await sync.setDone(sync.chains.single, 60);
    expect(sync.chains.single.done, 60);
    final h = await sync.startChain(
        groupId: null, type: 'hatim', name: 'Hatim', unit: 'cüz', total: 30, mode: 'pick', days: 30);
    await sync.markPart(sync.chain(null, h.id)!, 3, true);
    expect(sync.chain(null, h.id)!.done, 1);
    // Yeniden açılınca kayıt yerinde.
    sync.resetLocal();
    await sync.load();
    expect(sync.chains.length, 2);
    expect(sync.chains.firstWhere((x) => x.type == 'istigfar').done, 60);
  });

  testWidgets('Dua Zinciri: sekmeler, yalnız ben zinciri başlatma', (t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(() => sync.load());
    await t.pumpWidget(const MaterialApp(home: DuaCircleScreen()));
    await t.pump();
    expect(find.text('Zincirlerim'), findsOneWidget);
    expect(find.text('Gruplarım'), findsOneWidget);
    expect(find.text('Uygulamayı tavsiye et'), findsOneWidget);
    expect(find.textContaining('Henüz zinciriniz yok'), findsOneWidget);

    await t.tap(find.text('Gruplarım'));
    await t.pump();
    expect(find.text('Grup kur'), findsOneWidget);
    expect(find.text('Kodla katıl'), findsOneWidget);

    await t.tap(find.text('Zincirlerim'));
    await t.pump();
    await t.tap(find.byKey(const Key('startChain')));
    await t.pumpAndSettle();
    expect(find.text('Yalnız ben'), findsOneWidget);
    await t.tap(find.text('İstiğfar'));
    await t.pump();
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('doStart')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pumpAndSettle();
    expect(find.text('100 İstiğfar'), findsWidgets);
    expect(find.text('0 / 100'), findsOneWidget);
    await t.tap(find.text('+10'));
    await t.pumpAndSettle();
    expect(find.text('10 / 100'), findsOneWidget);
  });

  testWidgets('grup bağlantısı katılma ekranını açar', (t) async {
    await t.pumpWidget(MaterialApp(
      onGenerateRoute: (s) {
        final uri = Uri.parse(s.name ?? '/');
        if (uri.path == '/grup') {
          return MaterialPageRoute<void>(builder: (_) => GroupJoinScreen(code: uri.queryParameters['k'] ?? ''));
        }
        return MaterialPageRoute<void>(builder: (_) => const SizedBox());
      },
      initialRoute: '/grup?k=AB',
    ));
    await t.pumpAndSettle();
    expect(find.byType(GroupJoinScreen), findsOneWidget);
    expect(find.textContaining('grup kodu eksik'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });
}
