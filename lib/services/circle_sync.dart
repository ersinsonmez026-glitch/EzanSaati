import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'dua_circle_store.dart';

/// Dua Çemberi'nin ortak (sunuculu) kısmı: Firebase ücretsiz Spark planı.
///
/// Kullanılan servisler yalnızca Anonim Giriş ve Cloud Firestore'dur.
/// Telefon numaraları sunucuya yazılmaz; davetleri eşleştirmek için yalnızca
/// numaranın özeti ([phoneHash]) kaydedilir. Numaranın kendisi kurucunun
/// telefonunda kalır (WhatsApp daveti için).
///
/// Firestore yapısı (kurallar: firestore.rules):
/// * users/{uid}                  — ad ve kendi numarasının özeti
/// * circles/{cid}                — çemberin ortak bilgileri, üyelerin uid listesi
/// * circles/{cid}/members/{mid}  — kişi başına pay, okunan, durum
///                                  (kurucu: mid = uid; davetli: mid = davet kodu)
/// * invites/{kod}                — davet kodundan çembere ulaşmak için
enum SyncState { off, connecting, ready, error }

/// Kişiye gelen, henüz yanıtlanmamış davet.
class CircleInvite {
  final String circleId;
  final String code;
  final String circleName;
  final String ownerName;
  final String type;
  final String name; // kurucunun bu kişiye verdiği ad
  final int share;
  final int total;
  final DateTime end;
  final DateTime expiresAt;

  const CircleInvite({
    required this.circleId,
    required this.code,
    required this.circleName,
    required this.ownerName,
    required this.type,
    required this.name,
    required this.share,
    required this.total,
    required this.end,
    required this.expiresAt,
  });

  String get unit => (kDuaTypesByKey[type] ?? kDuaTypes.last).unit;
}

/// Numaranın özeti: ülke koduyla yazılmış numaraya uygulamaya özgü ön ek eklenip SHA-256.
String phoneHash(String phone) {
  final n = waNumber(phone);
  if (n.isEmpty) return '';
  return sha256.convert(utf8.encode('ezansaati-cember-v1:$n')).toString();
}

const _codeChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Tahmin edilmesi zor 10 karakterlik davet kodu.
String newInviteCode([Random? r]) {
  final rnd = r ?? Random.secure();
  return List.generate(10, (_) => _codeChars[rnd.nextInt(_codeChars.length)]).join();
}

/// Kodu okunaklı yazar: ABCDE-FGHJK
String formatCode(String code) => code.length == 10 ? '${code.substring(0, 5)}-${code.substring(5)}' : code;

/// Kullanıcının yazdığı kodu sadeleştirir.
String normalizeCode(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _parseDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime _time(Object? v, [DateTime? fallback]) =>
    v is Timestamp ? v.toDate() : (fallback ?? DateTime.fromMillisecondsSinceEpoch(0));

class CircleSync extends ChangeNotifier {
  CircleSync._();
  static final instance = CircleSync._();

  static const _nameKey = 'cember_ad';
  static const _phoneKey = 'cember_tel';
  static const _phonesKey = 'cember_numaralar'; // davet kodu → numara (yalnız bu telefonda)
  static const _codesKey = 'cember_kodlar'; // elle girilen davet kodları

  FirebaseFirestore? _db;
  String? _uid;
  SharedPreferences? _p;
  SyncState state = SyncState.off;
  String error = '';
  Future<void>? _starting;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _circlesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _invitesSub;
  final _memberSubs = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final _circleDocs = <String, Map<String, dynamic>>{};
  final _memberDocs = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  final _hashInvites = <String, CircleInvite>{};
  final _codeInvites = <String, CircleInvite>{};
  final _cleaning = <String>{};

  bool get ready => state == SyncState.ready;
  String? get uid => _uid;

  String get profileName => _p?.getString(_nameKey) ?? '';
  String get profilePhone => _p?.getString(_phoneKey) ?? '';

  List<CircleInvite> get invites {
    final now = DateTime.now();
    final all = {..._codeInvites, ..._hashInvites}.values.where((i) => i.expiresAt.isAfter(now)).toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return all;
  }

  Map<String, String> get _phones {
    final raw = _p?.getString(_phonesKey);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  void _setPhones(Map<String, String> m) => _p?.setString(_phonesKey, jsonEncode(m));

  // ---------------- Başlatma ----------------

  /// Firebase'e bağlanır (yalnız Android). Başarısız olursa çemberler telefonda çalışmaya devam eder.
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
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
  Future<void> startWith(FirebaseFirestore db, String uid, SharedPreferences prefs) => _attach(db, uid, prefs);

  Future<void> _attach(FirebaseFirestore db, String uid, SharedPreferences prefs) async {
    await stop();
    _db = db;
    _uid = uid;
    _p = prefs;
    state = SyncState.ready;
    _circlesSub = db
        .collection('circles')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .listen(_onCircles, onError: _onError);
    _listenInvites();
    for (final code in prefs.getStringList(_codesKey) ?? const <String>[]) {
      unawaited(_loadCode(code).catchError((_) => null));
    }
    notifyListeners();
  }

  /// Dinlemeleri kapatır (testler ve yeniden bağlanma için).
  Future<void> stop() async {
    await _circlesSub?.cancel();
    await _invitesSub?.cancel();
    for (final s in _memberSubs.values) {
      await s.cancel();
    }
    _circlesSub = null;
    _invitesSub = null;
    _memberSubs.clear();
    _circleDocs.clear();
    _memberDocs.clear();
    _hashInvites.clear();
    _codeInvites.clear();
    _cleaning.clear();
    state = SyncState.off;
    _db = null;
    _uid = null;
    DuaCircleStore.instance.setRemote(const []);
  }

  void _onError(Object e) {
    error = e is FirebaseException ? (e.message ?? e.code) : '$e';
    notifyListeners();
  }

  // ---------------- Profil ----------------

  /// Kişinin adı ve kendi numarası. Numara sunucuya yazılmaz, yalnız özeti yazılır.
  Future<void> saveProfile(String name, String phone) async {
    await _p?.setString(_nameKey, name.trim());
    await _p?.setString(_phoneKey, phone.trim());
    final db = _db, uid = _uid;
    if (db != null && uid != null) {
      final h = phoneHash(phone);
      await db.collection('users').doc(uid).set({
        'name': name.trim(),
        'phoneHash': h.isEmpty ? null : h,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _listenInvites();
    }
    notifyListeners();
  }

  // ---------------- Dinleme ----------------

  void _listenInvites() {
    _invitesSub?.cancel();
    _invitesSub = null;
    _hashInvites.clear();
    final db = _db, h = phoneHash(profilePhone);
    if (db == null || h.isEmpty) return;
    _invitesSub = db.collectionGroup('members').where('phoneHash', isEqualTo: h).snapshots().listen((s) {
      _hashInvites
        ..clear()
        ..addEntries(s.docs.map(_inviteFrom).whereType<CircleInvite>().map((i) => MapEntry(i.code, i)));
      notifyListeners();
    }, onError: _onError);
  }

  CircleInvite? _inviteFrom(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final cid = d.reference.parent.parent?.id;
    if (m == null || cid == null) return null;
    if (m['status'] != 'pending' || m['uid'] != null || m['ownerUid'] == _uid) return null;
    return CircleInvite(
      circleId: cid,
      code: d.id,
      circleName: m['circleName'] as String? ?? '',
      ownerName: m['ownerName'] as String? ?? '',
      type: m['type'] as String? ?? 'ozel',
      name: m['name'] as String? ?? '',
      share: (m['share'] as num?)?.toInt() ?? 0,
      total: (m['total'] as num?)?.toInt() ?? 0,
      end: _parseDate(m['endDate'] as String? ?? _dateKey(DateTime.now())),
      expiresAt: _time(m['expiresAt']),
    );
  }

  void _onCircles(QuerySnapshot<Map<String, dynamic>> s) {
    final ids = s.docs.map((d) => d.id).toSet();
    for (final id in _memberSubs.keys.toList()) {
      if (!ids.contains(id)) {
        _memberSubs.remove(id)?.cancel();
        _memberDocs.remove(id);
        _circleDocs.remove(id);
      }
    }
    for (final d in s.docs) {
      _circleDocs[d.id] = d.data();
      _memberSubs[d.id] ??= d.reference.collection('members').snapshots().listen((ms) {
        _memberDocs[d.id] = ms.docs;
        _publish();
      }, onError: _onError);
    }
    _publish();
  }

  /// Firestore verisini ekranın kullandığı modele çevirir ve kurucu olarak süre kurallarını uygular.
  void _publish() {
    final now = DateTime.now();
    final phones = _phones;
    final list = <DuaCircle>[];
    for (final e in _circleDocs.entries) {
      final docs = _memberDocs[e.key];
      if (docs == null) continue;
      final c = circleFromFirestore(e.key, e.value, [for (final d in docs) (d.id, d.data())], _uid ?? '', phones);
      if (c.mine) _ownerCleanup(c, now);
      // Süresi geçmiş ve tamamlanmamış çemberler üyelere gösterilmez (kurucu silene kadar).
      if (!c.isComplete && !now.isBefore(c.deadline)) continue;
      list.add(c);
    }
    DuaCircleStore.instance.setRemote(list);
    notifyListeners();
  }

  // ---------------- Kurucu işlemleri ----------------

  Map<String, dynamic> _denorm(DuaCircle c) => {
        'circleName': c.name,
        'ownerName': c.ownerName,
        'ownerUid': _uid,
        'type': c.type,
        'intent': c.intent,
        'total': c.total,
        'endDate': _dateKey(c.end),
        'deadline': Timestamp.fromDate(c.deadline),
      };

  Map<String, dynamic> _inviteDoc(DuaCircle c, CircleMember m, DateTime now) {
    final h = phoneHash(m.phone);
    return {
      'name': m.name,
      'share': m.share,
      'done': 0,
      'status': 'pending',
      'uid': null,
      'phoneHash': h.isEmpty ? null : h,
      'invitedAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: kInviteHours))),
      'respondedAt': null,
      ..._denorm(c),
    };
  }

  Future<void> _commit(WriteBatch b) async {
    try {
      // Çevrimdışıyken yazma sırada bekler ve bağlantı gelince gönderilir.
      await b.commit().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // sıraya alındı
    }
  }

  /// Yeni çemberi sunucuya yazar. Davetlilere kod verilir (üyelerin [CircleMember.key] alanı).
  Future<DuaCircle> createCircle(DuaCircle c) async {
    final db = _db!, uid = _uid!;
    final now = DateTime.now();
    final ref = db.collection('circles').doc();
    c
      ..remote = true
      ..mine = true
      ..ownerUid = uid
      ..ownerName = profileName.isEmpty ? 'Bir kullanıcı' : profileName;
    final b = db.batch();
    b.set(ref, {
      'ownerUid': uid,
      'ownerName': c.ownerName,
      'type': c.type,
      'name': c.name,
      'intent': c.intent,
      'total': c.total,
      'created': Timestamp.fromDate(now),
      'endDate': _dateKey(c.end),
      'deadline': Timestamp.fromDate(c.deadline),
      'memberUids': [uid],
      'lastJoin': '',
      'notice': '',
    });
    final phones = _phones;
    for (final m in c.members) {
      if (m.isOwner) {
        m.key = uid;
        m.uid = uid;
        b.set(ref.collection('members').doc(uid), {
          'name': m.name,
          'share': m.share,
          'done': m.done,
          'status': 'owner',
          'uid': uid,
          'phoneHash': null,
          'invitedAt': Timestamp.fromDate(now),
          'expiresAt': null,
          'respondedAt': null,
          ..._denorm(c),
        });
      } else {
        m.key = newInviteCode();
        m.invitedAt = now;
        b.set(ref.collection('members').doc(m.key), _inviteDoc(c, m, now));
        b.set(db.collection('invites').doc(m.key), {'circleId': ref.id, 'createdAt': Timestamp.fromDate(now)});
        if (m.phone.isNotEmpty) phones[m.key] = m.phone;
      }
    }
    _setPhones(phones);
    final created = DuaCircle(
      id: ref.id,
      type: c.type,
      name: c.name,
      intent: c.intent,
      total: c.total,
      created: now,
      end: c.end,
      members: c.members,
      remote: true,
      mine: true,
      ownerUid: uid,
      ownerName: c.ownerName,
    );
    await _commit(b);
    return created;
  }

  /// Kurucunun düzenlemesi: pay/ad değişiklikleri, yeni davetliler, çıkarılanlar.
  Future<void> updateCircle(DuaCircle c) async {
    final db = _db!;
    final now = DateTime.now();
    final ref = db.collection('circles').doc(c.id);
    final current = _memberDocs[c.id]?.map((d) => d.id).toSet() ?? <String>{};
    final keep = <String>{};
    final phones = _phones;
    final b = db.batch();
    b.update(ref, {
      'name': c.name,
      'intent': c.intent,
      'total': c.total,
      'endDate': _dateKey(c.end),
      'deadline': Timestamp.fromDate(c.deadline),
    });
    for (final m in c.members) {
      if (m.key.isEmpty) {
        m.key = newInviteCode();
        m.invitedAt = now;
        b.set(ref.collection('members').doc(m.key), _inviteDoc(c, m, now));
        b.set(db.collection('invites').doc(m.key), {'circleId': c.id, 'createdAt': Timestamp.fromDate(now)});
        if (m.phone.isNotEmpty) phones[m.key] = m.phone;
      } else {
        keep.add(m.key);
        b.update(ref.collection('members').doc(m.key), {'name': m.name, 'share': m.share, ..._denorm(c)});
      }
    }
    for (final key in current.difference(keep)) {
      b.delete(ref.collection('members').doc(key));
      if (key != _uid) b.delete(db.collection('invites').doc(key));
      phones.remove(key);
    }
    _setPhones(phones);
    await _commit(b);
  }

  Future<void> deleteCircle(DuaCircle c) async {
    final db = _db!;
    final ref = db.collection('circles').doc(c.id);
    final b = db.batch();
    for (final d in _memberDocs[c.id] ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
      b.delete(d.reference);
      if (d.id != _uid) b.delete(db.collection('invites').doc(d.id));
    }
    b.delete(ref);
    await _commit(b);
  }

  /// Okunan miktar (kendi payım ya da kurucunun elle girdiği).
  Future<void> setDone(DuaCircle c, CircleMember m, int value) async {
    final v = value.clamp(0, m.share);
    m.done = v;
    DuaCircleStore.instance.notifyRemoteChanged();
    await _db!
        .collection('circles')
        .doc(c.id)
        .collection('members')
        .doc(m.key)
        .update({'done': v, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Kurucu: uygulaması olmayan kişiyi "kabul etti" olarak işaretler (ilerlemesini kurucu girer).
  Future<void> markAccepted(DuaCircle c, CircleMember m) async {
    final db = _db!;
    final b = db.batch()
      ..update(db.collection('circles').doc(c.id).collection('members').doc(m.key),
          {'status': 'accepted', 'phoneHash': null, 'respondedAt': FieldValue.serverTimestamp()})
      ..delete(db.collection('invites').doc(m.key));
    await _commit(b);
  }

  /// Kurucu: okumaya başlamamış kişiyi çıkarır; payı kurucuya döner.
  Future<void> removeMember(DuaCircle c, CircleMember m) async {
    if (m.isOwner || m.done > 0) return;
    final db = _db!;
    final ref = db.collection('circles').doc(c.id);
    final b = db.batch()
      ..delete(ref.collection('members').doc(m.key))
      ..delete(db.collection('invites').doc(m.key))
      ..update(ref.collection('members').doc(_uid), {'share': FieldValue.increment(m.share)});
    if (m.uid != null) {
      b.update(ref, {
        'memberUids': FieldValue.arrayRemove([m.uid]),
      });
    }
    await _commit(b);
  }

  Future<void> dismissNotice(DuaCircle c) async {
    c.notice = '';
    DuaCircleStore.instance.notifyRemoteChanged();
    await _db!.collection('circles').doc(c.id).update({'notice': ''});
  }

  /// Kurucu tarafında süre kuralları:
  /// * 24 saatte yanıt vermeyen ya da reddeden kişinin payı kurucuya döner.
  /// * Son günü geçen ve tamamlanmamış çember silinir; tamamlananlar saklanır.
  void _ownerCleanup(DuaCircle c, DateTime now) {
    if (_cleaning.contains(c.id)) return;
    final db = _db;
    if (db == null) return;
    if (!c.isComplete && !now.isBefore(c.deadline)) {
      _cleaning.add(c.id);
      deleteCircle(c).whenComplete(() => _cleaning.remove(c.id)).catchError((_) {});
      return;
    }
    final gone = c.members.where((m) => m.isDeclined || (m.isPending && m.inviteLeft(now) <= Duration.zero)).toList();
    if (gone.isEmpty) return;
    _cleaning.add(c.id);
    final ref = db.collection('circles').doc(c.id);
    final sum = gone.fold(0, (s, m) => s + m.share);
    final declined = gone.where((m) => m.isDeclined).map((m) => m.name).toList();
    final late = gone.where((m) => !m.isDeclined).map((m) => m.name).toList();
    final parts = [
      if (late.isNotEmpty) '${late.join(', ')} $kInviteHours saat içinde yanıt vermedi.',
      if (declined.isNotEmpty) '${declined.join(', ')} daveti kabul etmedi.',
    ];
    final b = db.batch();
    for (final m in gone) {
      b.delete(ref.collection('members').doc(m.key));
      b.delete(db.collection('invites').doc(m.key));
    }
    b.update(ref.collection('members').doc(_uid), {'share': FieldValue.increment(sum)});
    b.update(ref, {
      'notice':
          '${parts.join(' ')} ${trNum(sum)} ${c.unit} size döndü; dilerseniz Kişi Ekle ile başkasına verebilirsiniz.',
    });
    _commit(b).whenComplete(() => _cleaning.remove(c.id)).catchError((_) {});
  }

  // ---------------- Davetli işlemleri ----------------

  /// Elle girilen davet kodunu bulur. Bulunamazsa hata mesajı döner.
  Future<String?> redeemCode(String input) async {
    final code = normalizeCode(input);
    if (code.length != 10) return 'Davet kodu 10 karakter olmalı';
    try {
      final inv = await _loadCode(code);
      if (inv == null) return 'Bu kodla geçerli bir davet bulunamadı';
      final codes = {...?_p?.getStringList(_codesKey), code}.toList();
      await _p?.setStringList(_codesKey, codes);
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'unavailable' ? 'İnternet bağlantısı yok' : 'Bu kodla geçerli bir davet bulunamadı';
    }
  }

  Future<CircleInvite?> _loadCode(String code) async {
    final db = _db!;
    final inv = await db.collection('invites').doc(code).get();
    final cid = inv.data()?['circleId'] as String?;
    if (cid == null) {
      _forgetCode(code);
      return null;
    }
    final m = await db.collection('circles').doc(cid).collection('members').doc(code).get();
    final i = _inviteFrom(m);
    if (i == null || !i.expiresAt.isAfter(DateTime.now())) {
      _forgetCode(code);
      return null;
    }
    _codeInvites[code] = i;
    notifyListeners();
    return i;
  }

  void _forgetCode(String code) {
    _codeInvites.remove(code);
    final codes = (_p?.getStringList(_codesKey) ?? const <String>[]).where((c) => c != code).toList();
    _p?.setStringList(_codesKey, codes);
  }

  /// Daveti kabul eder: kişi çemberin üyesi olur, payı ona ait olur.
  Future<void> accept(CircleInvite i) async {
    final db = _db!, uid = _uid!;
    final ref = db.collection('circles').doc(i.circleId);
    final b = db.batch()
      ..update(ref.collection('members').doc(i.code), {
        'status': 'accepted',
        'uid': uid,
        'phoneHash': null,
        'respondedAt': FieldValue.serverTimestamp(),
      })
      ..update(ref, {
        'memberUids': FieldValue.arrayUnion([uid]),
        'lastJoin': i.code,
      });
    await b.commit();
    _hashInvites.remove(i.code);
    _forgetCode(i.code);
    notifyListeners();
  }

  /// Daveti reddeder; kurucunun uygulaması payı kurucuya geri verir.
  Future<void> decline(CircleInvite i) async {
    await _db!
        .collection('circles')
        .doc(i.circleId)
        .collection('members')
        .doc(i.code)
        .update({'status': 'declined', 'respondedAt': FieldValue.serverTimestamp()});
    _hashInvites.remove(i.code);
    _forgetCode(i.code);
    notifyListeners();
  }
}

/// Firestore belgelerinden ekran modeli.
@visibleForTesting
DuaCircle circleFromFirestore(
  String id,
  Map<String, dynamic> c,
  List<(String, Map<String, dynamic>)> members,
  String myUid,
  Map<String, String> phones,
) {
  MemberStatus status(String? s) => switch (s) {
        'owner' => MemberStatus.me,
        'accepted' => MemberStatus.accepted,
        'declined' => MemberStatus.declined,
        _ => MemberStatus.pending,
      };
  final list = [
    for (final (key, m) in members)
      CircleMember(
        key: key,
        name: m['name'] as String? ?? '',
        phone: phones[key] ?? '',
        share: (m['share'] as num?)?.toInt() ?? 0,
        done: (m['done'] as num?)?.toInt() ?? 0,
        status: status(m['status'] as String?),
        uid: m['uid'] as String?,
        self: m['uid'] != null && m['uid'] == myUid,
        invitedAt: _time(m['invitedAt'], DateTime.now()),
      ),
  ]..sort((a, b) => a.isOwner == b.isOwner ? a.invitedAt.compareTo(b.invitedAt) : (a.isOwner ? -1 : 1));
  return DuaCircle(
    id: id,
    type: c['type'] as String? ?? 'ozel',
    name: c['name'] as String? ?? '',
    intent: c['intent'] as String? ?? '',
    total: (c['total'] as num?)?.toInt() ?? 0,
    created: _time(c['created'], DateTime.now()),
    end: _parseDate(c['endDate'] as String? ?? _dateKey(DateTime.now())),
    members: list,
    notice: c['notice'] as String? ?? '',
    remote: true,
    mine: c['ownerUid'] == myUid,
    ownerUid: c['ownerUid'] as String? ?? '',
    ownerName: c['ownerName'] as String? ?? '',
  );
}
