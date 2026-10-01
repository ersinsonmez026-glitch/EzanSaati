import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'day_utils.dart';

/// Dua Zinciri (Firebase ücretsiz Spark planı: yalnız Anonim Giriş ve Cloud Firestore).
///
/// Kişi ne okunacağını, kaç tane olacağını ve süreyi seçer; uygulama zincirin bağlantısını verir.
/// Bağlantı WhatsApp'tan istenen kişiye ya da gruba gönderilir. Bağlantıyı açan kişi zincire katılır ve
/// payını alır; bütün paylar alınınca zincir "doldu" olur. Telefon numarası kullanılmaz.
///
/// Firestore yapısı (kurallar: firestore.rules):
/// * chains/{cid}               — zincir (tür, hedef, son gün, alınan toplam, katılanların uid listesi)
/// * chains/{cid}/slots/{n}     — hatimde alınan cüz (n: 1-30)
/// * chains/{cid}/claims/{uid}  — sayılı zincirde kişinin aldığı adet ve okuduğu
///
/// Zincirin kimliği tahmin edilemeyen 20 karakterdir; bağlantıyı bilen zinciri görebilir.

/// Dua türü. [key] 'ozel' ise duanın adını kişi kendisi yazar.
class DuaType {
  final String key;
  final String title;
  final String unit;
  final int defaultTotal;

  const DuaType(this.key, this.title, this.unit, this.defaultTotal);
}

const kDuaTypes = [
  DuaType('hatim', 'Hatim', 'cüz', 30),
  DuaType('yasin', 'Yâsin', 'Yâsin', 41),
  DuaType('salavat', 'Salavat', 'salavat', 1000),
  DuaType('ihlas', 'İhlâs', 'İhlâs', 1000),
  DuaType('istigfar', 'İstiğfar', 'istiğfar', 100),
  DuaType('ozel', 'Özel', 'adet', 100),
];

final kDuaTypesByKey = {for (final t in kDuaTypes) t.key: t};

/// Zincirin en uzun süresi (gün).
const kChainMaxDays = 30;

/// Bir zincire katılabilecek en çok kişi.
const kChainMaxMembers = 200;

/// Uygulamanın Play Store sayfası (paket adı android/app/build.gradle'daki applicationId).
const kAppLink = 'https://play.google.com/store/apps/details?id=com.ezansaati.app';

/// Zincir bağlantısı (Firebase Hosting'deki hosting/public/zincir.html). Uygulama yüklüyse zinciri açar
/// (ezansaati://app/zincir?k=KİMLİK), yüklü değilse Play Store'a götürür.
const kChainLinkBase = 'https://ezansaati-premium-2026.web.app/zincir';

String chainLink(String id) => '$kChainLinkBase?k=$id';

/// Bağlantıdaki zincir kimliği geçerli mi (Firestore'un otomatik kimliği: 20 harf/rakam).
bool validChainId(String id) => RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(id);

/// WhatsApp'ta gönderilen davet.
String chainInviteMessage(GroupChain c) => '🤲 Dua Zincirimize Katılır mısın?\n\n'
    '${c.name} için başlattığımız zincire sen de katılabilirsin.\n\n'
    '🔗 Zincire Katıl: ${chainLink(c.id)}\n\n'
    'Allah kabul etsin. 🌿';

/// Uygulamayı önerme mesajı.
String appSuggestMessage() =>
    'Selamün aleyküm, Ezan Saati uygulamasını kullanıyorum: namaz vakitleri, Kur\'an, dualar ve '
    'sevdiklerimizle birlikte okuduğumuz dua zincirleri bir arada. Sen de kurmak istersen:\n$kAppLink';

/// 1.234.567 biçiminde sayı.
String trNum(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

DateTime _time(Object? v) => v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

/// Hatimde alınan bir cüz.
class ChainSlot {
  final String uid;
  final String name;
  final bool done;

  const ChainSlot({required this.uid, required this.name, this.done = false});
}

/// Sayılı zincirde bir kişinin aldığı pay.
class ChainClaim {
  final String uid;
  final String name;
  final int amount;
  final int done;

  const ChainClaim({required this.uid, required this.name, required this.amount, this.done = 0});
}

class GroupChain {
  final String id;
  final String creatorUid;
  final String creatorName;
  final String type;
  final String name;
  final String unit;
  final int total;

  /// Sayılı zincirde alınan toplam (sunucudaki sayaç; kurallar hedefi aşmasına izin vermez).
  final int takenCount;
  final DateTime created;
  final DateTime deadline;
  final List<String> memberUids;
  final Map<int, ChainSlot> slots;
  final Map<String, ChainClaim> claims;

  const GroupChain({
    required this.id,
    required this.creatorUid,
    required this.creatorName,
    required this.type,
    required this.name,
    required this.unit,
    required this.total,
    this.takenCount = 0,
    required this.created,
    required this.deadline,
    this.memberUids = const [],
    this.slots = const {},
    this.claims = const {},
  });

  factory GroupChain.fromMap(String id, Map<String, dynamic> m) => GroupChain(
        id: id,
        creatorUid: m['creatorUid'] as String? ?? '',
        creatorName: m['creatorName'] as String? ?? '',
        type: m['type'] as String? ?? 'ozel',
        name: m['name'] as String? ?? '',
        unit: m['unit'] as String? ?? 'adet',
        total: (m['total'] as num?)?.toInt() ?? 1,
        takenCount: (m['taken'] as num?)?.toInt() ?? 0,
        created: _time(m['created']),
        deadline: _time(m['deadline']),
        memberUids: [for (final u in (m['memberUids'] as List<dynamic>? ?? const [])) '$u'],
      );

  bool get isHatim => type == 'hatim';

  /// Okunan (hatimde okunan cüz sayısı).
  int get done => isHatim
      ? slots.values.where((s) => s.done).length
      : claims.values.fold(0, (a, c) => a + min(c.done, c.amount));

  /// Alınan (hatimde alınan cüz sayısı).
  int get taken => isHatim ? slots.length : max(takenCount, claims.values.fold(0, (a, c) => a + c.amount));

  int get free => max(0, total - taken);

  /// Bütün paylar alındı: yeni gelen pay alamaz.
  bool get full => free == 0;
  bool get complete => done >= total;
  bool get expired => !complete && DateTime.now().isAfter(deadline);
  bool get active => !complete && !expired;
  double get progress => total == 0 ? 0 : min(1, done / total);

  List<int> partsOf(String uid) => (slots.entries.where((e) => e.value.uid == uid).map((e) => e.key).toList())..sort();
  ChainClaim? claimOf(String uid) => claims[uid];
  bool hasShare(String uid) => isHatim ? slots.values.any((s) => s.uid == uid) : claims.containsKey(uid);

  /// Son güne kalan gün (bugün biterse 0).
  int get daysLeft => max(0, calendarDaysBetween(DateTime.now(), deadline));

  GroupChain withParts({Map<int, ChainSlot>? slots, Map<String, ChainClaim>? claims}) => GroupChain(
        id: id,
        creatorUid: creatorUid,
        creatorName: creatorName,
        type: type,
        name: name,
        unit: unit,
        total: total,
        takenCount: takenCount,
        created: created,
        deadline: deadline,
        memberUids: memberUids,
        slots: slots ?? this.slots,
        claims: claims ?? this.claims,
      );
}

enum SyncState { off, connecting, ready, error }

/// Zincirleri Firestore'dan dinler: katıldığım zincirler ve bağlantıdan açılan zincir.
class GroupSync extends ChangeNotifier {
  GroupSync._();
  static final instance = GroupSync._();

  static const _nameKey = 'cember_ad';

  /// Kişi bir zincir başlattı ya da pay aldı (Zikir Sayacı ancak o zaman sunucuya bağlanır).
  static const usedKey = 'zincir_kullanildi';

  FirebaseFirestore? _db;
  String? _uid;
  SharedPreferences? _p;
  SyncState state = SyncState.off;
  String error = '';
  Future<void>? _starting;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _mineSub;
  final _subs = <String, StreamSubscription<Object?>>{};
  final _mine = <String>{}; // katıldığım zincirler
  final _docs = <String, GroupChain>{};
  final _slots = <String, Map<int, ChainSlot>>{};
  final _claims = <String, Map<String, ChainClaim>>{};
  final _missing = <String>{}; // bağlantısı açılan ama bulunamayan (silinmiş) zincirler

  bool get ready => state == SyncState.ready;
  String? get uid => _uid;
  String get myName => _p?.getString(_nameKey) ?? '';

  GroupChain? _build(String id) =>
      _docs[id]?.withParts(slots: _slots[id] ?? const {}, claims: _claims[id] ?? const {});

  /// Katıldığım zincirler, yeniden eskiye.
  List<GroupChain> get chains =>
      _mine.map(_build).whereType<GroupChain>().toList()..sort((a, b) => b.created.compareTo(a.created));

  GroupChain? chain(String id) => _build(id);

  /// Bağlantısı açılan zincir sunucuda yok (silinmiş ya da yanlış bağlantı).
  bool isMissing(String id) => _missing.contains(id);

  bool isMember(GroupChain c) => _uid != null && c.memberUids.contains(_uid);

  // ---------------- Başlatma ----------------

  /// Telefonda tutulan adı yükler.
  Future<void> load() async {
    _p ??= await SharedPreferences.getInstance();
    notifyListeners();
  }

  /// Firebase'e bağlanır (yalnız Android).
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    await load();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return; // birim testlerinde sunucuya bağlanılmaz
    state = SyncState.connecting;
    notifyListeners();
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.android).timeout(const Duration(seconds: 10));
      }
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser ?? (await auth.signInAnonymously().timeout(const Duration(seconds: 15))).user;
      if (user == null) throw StateError('Giriş yapılamadı');
      await _attach(FirebaseFirestore.instance, user.uid, await SharedPreferences.getInstance());
    } catch (e) {
      state = SyncState.error;
      error = e is FirebaseException ? (e.message ?? e.code) : '$e';
      _starting = null; // sonra yeniden denenebilsin
      notifyListeners();
    }
  }

  @visibleForTesting
  Future<void> startWith(FirebaseFirestore db, String uid, SharedPreferences prefs) async {
    _p = prefs;
    await _attach(db, uid, prefs);
  }

  Future<void> _attach(FirebaseFirestore db, String uid, SharedPreferences prefs) async {
    await stop();
    _db = db;
    _uid = uid;
    _p = prefs;
    state = SyncState.ready;
    _mineSub = db.collection('chains').where('memberUids', arrayContains: uid).snapshots().listen((snap) {
      final ids = {for (final d in snap.docs) d.id};
      for (final d in snap.docs) {
        _docs[d.id] = GroupChain.fromMap(d.id, d.data());
        _watch(d.id);
      }
      for (final id in _mine.difference(ids)) {
        if (!_subs.containsKey('v:$id')) _forget(id);
      }
      _mine
        ..clear()
        ..addAll(ids);
      notifyListeners();
    }, onError: _onError);
    notifyListeners();
  }

  /// Dinlemeleri kapatır (testler ve yeniden bağlanma için).
  Future<void> stop() async {
    await _mineSub?.cancel();
    _mineSub = null;
    for (final s in _subs.values) {
      await s.cancel();
    }
    _subs.clear();
    _mine.clear();
    _docs.clear();
    _slots.clear();
    _claims.clear();
    _missing.clear();
    state = SyncState.off;
    _db = null;
    _uid = null;
    _starting = null;
  }

  @visibleForTesting
  void resetLocal() => _p = null;

  void _onError(Object e) {
    error = e is FirebaseException ? (e.message ?? e.code) : '$e';
    notifyListeners();
  }

  /// Zincirin pay belgelerini dinler (cüzler ya da sayılı paylar).
  void _watch(String id) {
    final db = _db;
    final c = _docs[id];
    if (db == null || c == null || _subs.containsKey('p:$id')) return;
    final ref = db.collection('chains').doc(id);
    if (c.isHatim) {
      _subs['p:$id'] = ref.collection('slots').snapshots().listen((s) {
        _slots[id] = {
          for (final x in s.docs)
            if (int.tryParse(x.id) != null)
              int.parse(x.id): ChainSlot(
                uid: x.data()['uid'] as String? ?? '',
                name: x.data()['name'] as String? ?? '',
                done: x.data()['done'] == true,
              ),
        };
        notifyListeners();
      }, onError: (_) {});
    } else {
      _subs['p:$id'] = ref.collection('claims').snapshots().listen((s) {
        _claims[id] = {
          for (final x in s.docs)
            x.id: ChainClaim(
              uid: x.id,
              name: x.data()['name'] as String? ?? '',
              amount: (x.data()['amount'] as num?)?.toInt() ?? 0,
              done: (x.data()['done'] as num?)?.toInt() ?? 0,
            ),
        };
        notifyListeners();
      }, onError: (_) {});
    }
  }

  void _forget(String id) {
    _subs.remove('p:$id')?.cancel();
    _subs.remove('v:$id')?.cancel();
    _docs.remove(id);
    _slots.remove(id);
    _claims.remove(id);
  }

  // ---------------- Profil ----------------

  Future<void> saveName(String name) async {
    _p ??= await SharedPreferences.getInstance();
    await _p!.setString(_nameKey, name.trim());
    notifyListeners();
  }

  // ---------------- Zincirler ----------------

  FirebaseFirestore _need() {
    final db = _db;
    if (db == null || _uid == null) {
      throw StateError('İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edip tekrar deneyin.');
    }
    return db;
  }

  DocumentReference<Map<String, dynamic>> _ref(String id) => _need().collection('chains').doc(id);

  /// Bağlantıdan gelen zinciri açar: sunucudan okur ve değişikliklerini dinler. Katılmak için pay alınır.
  Future<void> open(String id) async {
    final db = _need();
    if (_subs.containsKey('v:$id')) return;
    final first = Completer<void>();
    _subs['v:$id'] = db.collection('chains').doc(id).snapshots().listen((d) {
      final m = d.data();
      if (!d.exists || m == null) {
        _missing.add(id);
        _docs.remove(id);
      } else {
        _missing.remove(id);
        _docs[id] = GroupChain.fromMap(id, m);
        _watch(id);
      }
      if (!first.isCompleted) first.complete();
      notifyListeners();
    }, onError: (Object e) {
      _missing.add(id);
      if (!first.isCompleted) first.complete();
      notifyListeners();
    });
    await first.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  /// Zincir başlatır ve kimliğini döndürür (bağlantı: [chainLink]).
  Future<GroupChain> startChain({
    required String type,
    required String name,
    required String unit,
    required int total,
    required int days,
  }) async {
    final db = _need();
    final uid = _uid!;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + days, 23, 59);
    final deadline = end.difference(now).inDays >= kChainMaxDays ? now.add(const Duration(days: kChainMaxDays)) : end;
    if (type == 'hatim') total = 30;
    final ref = db.collection('chains').doc();
    final data = {
      'creatorUid': uid,
      'creatorName': myName,
      'type': type,
      'name': name.trim(),
      'unit': unit,
      'total': total,
      'taken': 0,
      'created': Timestamp.fromDate(now),
      'deadline': Timestamp.fromDate(deadline),
      'memberUids': [uid],
    };
    await ref.set(data);
    await _markUsed();
    final c = GroupChain.fromMap(ref.id, data);
    _docs[ref.id] = c;
    _mine.add(ref.id);
    _watch(ref.id);
    notifyListeners();
    return c;
  }

  /// Katılanlar listesine kendini ekler (pay alırken aynı yazmada).
  void _join(WriteBatch b, GroupChain c) {
    if (!isMember(c)) b.update(_ref(c.id), {'memberUids': FieldValue.arrayUnion([_uid])});
  }

  /// Hatimde cüz alır.
  Future<void> takeParts(GroupChain c, List<int> parts) async {
    final db = _need();
    final ref = _ref(c.id);
    final b = db.batch();
    _join(b, c);
    for (final p in parts) {
      b.set(ref.collection('slots').doc('$p'), {'uid': _uid, 'name': myName, 'done': false});
    }
    await b.commit();
    await _markUsed();
  }

  /// Hatimde alınan cüzü bırakır.
  Future<void> releasePart(GroupChain c, int part) => _ref(c.id).collection('slots').doc('$part').delete();

  /// Cüzü okundu / okunmadı yapar.
  Future<void> markPart(GroupChain c, int part, bool done) =>
      _ref(c.id).collection('slots').doc('$part').update({'done': done});

  /// Sayılı zincirde pay alır (alınan toplam sayacıyla birlikte; kurallar hedefi aşmayı engeller).
  Future<void> takeAmount(GroupChain c, int amount) async {
    if (amount <= 0) return;
    if (amount > c.free) throw StateError('En fazla ${trNum(c.free)} ${c.unit} alabilirsiniz.');
    final db = _need();
    final ref = _ref(c.id);
    final b = db.batch();
    b.set(ref.collection('claims').doc(_uid), {'name': myName, 'amount': amount, 'done': 0});
    b.update(ref, {
      'taken': FieldValue.increment(amount),
      if (!isMember(c)) 'memberUids': FieldValue.arrayUnion([_uid]),
    });
    await b.commit();
    await _markUsed();
  }

  /// Henüz okumaya başlanmamış payı bırakır.
  Future<void> releaseAmount(GroupChain c) async {
    final mine = c.claimOf(_uid ?? '');
    if (mine == null || mine.done > 0) return;
    final db = _need();
    final ref = _ref(c.id);
    final b = db.batch();
    b.delete(ref.collection('claims').doc(_uid));
    b.update(ref, {'taken': FieldValue.increment(-mine.amount)});
    await b.commit();
  }

  /// Okunan adedi yazar (0 ile pay arasında).
  Future<void> setDone(GroupChain c, int done) async {
    final mine = c.claimOf(_uid ?? '');
    if (mine == null) return;
    await _ref(c.id).collection('claims').doc(_uid).update({'done': done.clamp(0, mine.amount)});
  }

  /// Payı olmayan kişi zincirden ayrılır (listesinden kalkar).
  Future<void> leave(GroupChain c) async {
    if (c.creatorUid == _uid || c.hasShare(_uid ?? '')) return;
    await _ref(c.id).update({'memberUids': FieldValue.arrayRemove([_uid])});
  }

  /// Zinciri siler (yalnız başlatan).
  Future<void> deleteChain(GroupChain c) async {
    final db = _need();
    final ref = _ref(c.id);
    final b = db.batch();
    for (final s in (await ref.collection('slots').get()).docs) {
      b.delete(s.reference);
    }
    for (final s in (await ref.collection('claims').get()).docs) {
      b.delete(s.reference);
    }
    b.delete(ref);
    await b.commit();
    _mine.remove(c.id);
    _forget(c.id);
    notifyListeners();
  }

  Future<void> _markUsed() async {
    _p ??= await SharedPreferences.getInstance();
    await _p!.setBool(usedKey, true);
  }

  /// Okumam bekleyen zincirler (Zikir Sayacı'nda en üstte): payımı almışım ama bitirmemişim.
  List<GroupChain> get pendingReadings {
    final me = _uid ?? '';
    return [
      for (final c in chains)
        if (c.active &&
            (c.isHatim
                ? c.partsOf(me).any((n) => !(c.slots[n]?.done ?? false))
                : _unfinished(c.claimOf(me))))
          c,
    ];
  }

  static bool _unfinished(ChainClaim? m) => m != null && m.done < m.amount;

  bool canDelete(GroupChain c) => _uid != null && c.creatorUid == _uid;
}
