import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ezan_saati/services/circle_sync.dart';
import 'package:ezan_saati/services/dua_circle_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ortak Dua Zinciri akışı: iki telefon (kurucu "alice", davetli "bob") aynı
/// Firestore'u sırayla kullanır. Güvenlik kuralları ayrıca emülatörde test edilir
/// (test_rules/).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late SharedPreferences prefs;
  final sync = CircleSync.instance;
  final store = DuaCircleStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = FakeFirebaseFirestore();
    store.replaceAll([]);
  });

  tearDown(() => sync.stop());

  Future<void> as(String uid, {String name = '', String phone = ''}) async {
    await sync.startWith(db, uid, prefs);
    await sync.saveProfile(name, phone);
    await pumpEventQueue();
  }

  List<DuaCircle> remote() => store.circles.where((c) => c.remote).toList();

  Future<DuaCircle> aliceCreates({String phone = '0532 111 22 33'}) async {
    await as('alice', name: 'Ali');
    final now = DateTime.now();
    final c = await store.save(
      DuaCircle(
        id: 'yerel',
        type: 'salavat',
        name: '110 Salavat',
        total: 110,
        created: now,
        end: DateTime(now.year, now.month, now.day + 7),
        members: [
          CircleMember(name: 'Ben', share: 55, status: MemberStatus.me),
          CircleMember(name: 'Veli', phone: phone, share: 55),
        ],
      ),
      isNew: true,
    );
    await pumpEventQueue();
    return c;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> memberDoc(String cid, String key) =>
      db.collection('circles').doc(cid).collection('members').doc(key).get();

  test('Davet kodu tahmin edilmesi zor ve okunaklı', () {
    final codes = {for (var i = 0; i < 200; i++) newInviteCode()};
    expect(codes.length, 200);
    for (final c in codes) {
      expect(c, matches(RegExp(r'^[A-HJKMNP-Z2-9]{10}$')));
    }
    expect(formatCode('ABCDEFGHJK'), 'ABCDE-FGHJK');
    expect(normalizeCode(' abcde-fghjk '), 'ABCDEFGHJK');
  });

  test('Numara özeti yazım biçiminden bağımsız, numaranın kendisini içermez', () {
    final h = phoneHash('0532 111 22 33');
    expect(h, phoneHash('+90 (532) 111-22-33'));
    expect(h, hasLength(64));
    expect(h, isNot(contains('5321112233')));
    expect(phoneHash('123'), '');
  });

  test('Kurucu ortak zincir kurar; telefon numarası sunucuya açık yazılmaz', () async {
    final c = await aliceCreates();
    expect(c.remote, isTrue);
    final code = c.members.firstWhere((m) => !m.isOwner).key;
    expect(code, hasLength(10));
    expect((await db.collection('invites').doc(code).get()).data()?['circleId'], c.id);

    final all = db.dump();
    expect(all, isNot(contains('5321112233')));
    expect(all, isNot(contains('532 111')));
    expect(all, contains(phoneHash('05321112233')));

    final list = remote();
    expect(list, hasLength(1));
    expect(list.single.mine, isTrue);
    expect(list.single.pending.single.name, 'Veli');
    // Numara yalnızca kurucunun telefonunda (WhatsApp daveti için)
    expect(list.single.pending.single.phone, '0532 111 22 33');
    final msg = inviteMessage(list.single, list.single.pending.single);
    expect(msg, endsWith(inviteLink(code))); // tek bağlantı: uygulamayı açar ya da indirme sayfasına götürür
    expect(msg, isNot(contains(kAppLink)));
  });

  test('Davetli davetini numarasıyla görür, kabul eder; ilerleme ve tamamlanma herkes için eşitlenir', () async {
    final c = await aliceCreates();
    final code = c.members.firstWhere((m) => !m.isOwner).key;

    // Bob'un telefonu
    await as('bob', name: 'Veli', phone: '+90 532 111 22 33');
    expect(sync.invites, hasLength(1));
    final inv = sync.invites.single;
    expect(inv.code, code);
    expect(inv.ownerName, 'Ali');
    expect(inv.share, 55);
    await sync.accept(inv);
    await pumpEventQueue();
    expect(sync.invites, isEmpty);
    expect((await memberDoc(c.id, code)).data()?['phoneHash'], isNull);

    final joined = remote().single;
    expect(joined.mine, isFalse);
    expect(joined.ownerName, 'Ali');
    expect(joined.me.share, 55);
    await store.addMine(joined, 10);
    await pumpEventQueue();
    expect((await memberDoc(c.id, code)).data()?['done'], 10);
    await store.addMine(remote().single, 100); // payı aşamaz
    await pumpEventQueue();
    expect((await memberDoc(c.id, code)).data()?['done'], 55);
    await sync.stop();

    // Kurucunun telefonu: Veli katılımcı olarak görünür
    await as('alice', name: 'Ali');
    var mine = remote().single;
    expect(mine.active.map((m) => m.name), containsAll(['Ben', 'Veli']));
    expect(mine.pending, isEmpty);
    expect(mine.done, 55);
    expect(mine.isComplete, isFalse);
    await store.addMine(mine, 55);
    await pumpEventQueue();
    mine = remote().single;
    expect(mine.isComplete, isTrue);
    await sync.stop();

    // Bob da tamamlandığını görür
    await as('bob', name: 'Veli', phone: '05321112233');
    expect(remote().single.isComplete, isTrue);
    expect(remote().single.percent, 100);
  });

  test('Kodla katılma: numara kaydetmemiş kişi kodu yazarak daveti bulur ve reddedebilir', () async {
    final c = await aliceCreates(phone: '');
    final code = c.members.firstWhere((m) => !m.isOwner).key;
    await sync.stop();

    await as('carol');
    expect(sync.invites, isEmpty);
    expect(await sync.redeemCode('AAAAA-AAAAA'), isNotNull);
    expect(await sync.redeemCode(formatCode(code).toLowerCase()), isNull);
    expect(sync.invites.single.code, code);
    await sync.decline(sync.invites.single);
    expect(sync.invites, isEmpty);
    await sync.stop();

    // Kurucunun uygulaması reddedilen payı kurucuya geri verir
    await as('alice', name: 'Ali');
    await pumpEventQueue();
    final mine = remote().single;
    expect(mine.members, hasLength(1));
    expect(mine.owner.share, 110);
    expect(mine.notice, contains('kabul etmedi'));
    expect((await db.collection('invites').doc(code).get()).exists, isFalse);
  });

  test('24 saatte yanıt vermeyen davetlinin payı kurucuya döner', () async {
    final c = await aliceCreates();
    final code = c.members.firstWhere((m) => !m.isOwner).key;
    await sync.stop();
    final past = DateTime.now().subtract(const Duration(hours: 25));
    await db.collection('circles').doc(c.id).collection('members').doc(code).update({
      'invitedAt': Timestamp.fromDate(past),
      'expiresAt': Timestamp.fromDate(past.add(const Duration(hours: kInviteHours))),
    });

    // Süresi geçen davet davetliye gösterilmez
    await as('bob', name: 'Veli', phone: '05321112233');
    expect(sync.invites, isEmpty);
    await sync.stop();

    await as('alice', name: 'Ali');
    await pumpEventQueue();
    final mine = remote().single;
    expect(mine.pending, isEmpty);
    expect(mine.owner.share, 110);
    expect(mine.notice, contains('24 saat içinde yanıt vermedi'));
  });

  test('Son günü geçen tamamlanmamış zincir silinir, tamamlanan saklanır', () async {
    final open = await aliceCreates();
    final done = await aliceCreates();
    Future<void> expire(String id) => db.collection('circles').doc(id).update({
          'endDate': '2020-01-01',
          'deadline': Timestamp.fromDate(DateTime(2020, 1, 2)),
        });
    // İkinci zinciri tamamla: kurucu kendi payını, davetliyi elle katılımcı yapıp payını girer
    var d = remote().firstWhere((c) => c.id == done.id);
    await store.accept(d, d.pending.single);
    await pumpEventQueue();
    d = remote().firstWhere((c) => c.id == done.id);
    await store.setDone(d, d.members.firstWhere((m) => !m.isOwner), 55);
    await store.addMine(d, 55);
    await pumpEventQueue();
    await sync.stop();
    await expire(open.id);
    await expire(done.id);

    await as('alice', name: 'Ali');
    await pumpEventQueue();
    expect((await db.collection('circles').doc(open.id).get()).exists, isFalse);
    expect((await db.collection('circles').doc(done.id).get()).exists, isTrue);
    expect(remote().map((c) => c.id), [done.id]);
  });

  test('Kurucu düzenler: yeni kişi eklenir, çıkarılanın payı ve kodu silinir', () async {
    final c = await aliceCreates();
    final oldCode = c.members.firstWhere((m) => !m.isOwner).key;
    final cur = remote().single;
    final edited = DuaCircle(
      id: cur.id,
      type: cur.type,
      name: '110 Salavat (şifa)',
      total: 110,
      created: cur.created,
      end: cur.end,
      members: [
        cur.owner.copy()..share = 60,
        CircleMember(name: 'Ayşe', phone: '05330000000', share: 50),
      ],
      remote: true,
      mine: true,
    );
    await store.save(edited, isNew: false);
    await pumpEventQueue();
    final after = remote().single;
    expect(after.name, '110 Salavat (şifa)');
    expect(after.pending.single.name, 'Ayşe');
    expect(after.owner.share, 60);
    expect((await db.collection('invites').doc(oldCode).get()).exists, isFalse);
    expect((await memberDoc(c.id, oldCode)).exists, isFalse);
  });

  test('Firestore belgesinden model: bu telefondaki kişi ve kurucu doğru bulunur', () {
    final now = Timestamp.fromDate(DateTime(2026, 10, 1, 9));
    final c = circleFromFirestore(
      'c1',
      {
        'ownerUid': 'alice',
        'ownerName': 'Ali',
        'type': 'yasin',
        'name': '41 Yasin',
        'total': 41,
        'created': now,
        'endDate': '2026-10-05'
      },
      [
        ('alice', {'name': 'Ali', 'share': 21, 'done': 5, 'status': 'owner', 'uid': 'alice', 'invitedAt': now}),
        ('KOD1234567', {'name': 'Veli', 'share': 20, 'done': 3, 'status': 'accepted', 'uid': 'bob', 'invitedAt': now}),
      ],
      'bob',
      const {},
    );
    expect(c.mine, isFalse);
    expect(c.owner.name, 'Ali');
    expect(c.me.name, 'Veli');
    expect(c.done, 8);
    expect(c.end, DateTime(2026, 10, 5));
    expect(c.unit, 'Yasin');
  });
}
