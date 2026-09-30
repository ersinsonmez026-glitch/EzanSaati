import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

/// Dua Zinciri: uygulama içindeki dua grupları ve gruplarda başlatılan zincirler
/// (Firebase ücretsiz Spark planı: yalnız Anonim Giriş ve Cloud Firestore).
///
/// Kişi bir gruba bir kez katılır (WhatsApp'tan gelen grup bağlantısı ya da grup koduyla);
/// o grupta başlatılan bütün zincirleri uygulamada görür. Telefon numarası kullanılmaz.
///
/// Firestore yapısı (kurallar: firestore.rules):
/// * groups/{gid}                            — grup adı, kurucu, grup kodu, üyelerin uid listesi
/// * groups/{gid}/members/{uid}              — üyenin grupta görünen adı
/// * groups/{gid}/chains/{cid}               — zincir (tür, hedef, son gün, pay dağıtımı)
/// * groups/{gid}/chains/{cid}/slots/{n}     — hatimde alınan cüz (n: 1-30)
/// * groups/{gid}/chains/{cid}/claims/{uid}  — sayılı zincirde kişinin aldığı adet ve okuduğu
/// * groupCodes/{kod}                        — grup kodundan gruba ulaşmak için
///
/// "Yalnız ben" zincirleri sunucuya yazılmaz, bu telefonda tutulur.

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

/// Uygulamanın Play Store sayfası (paket adı android/app/build.gradle'daki applicationId).
const kAppLink = 'https://play.google.com/store/apps/details?id=com.ezansaati.app';

/// Grup bağlantısı (Firebase Hosting'deki hosting/public/grup.html). Uygulama yüklüyse gruba katılma
/// ekranını açar (ezansaati://app/grup?k=KOD), yüklü değilse Play Store'a götürür.
const kGroupLinkBase = 'https://ezansaati-premium-2026.web.app/grup';

String groupLink(String code) => '$kGroupLinkBase?k=$code';

const _codeChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Tahmin edilmesi zor 6 karakterlik grup kodu.
String newGroupCode([Random? r]) {
  final rnd = r ?? Random.secure();
  return List.generate(6, (_) => _codeChars[rnd.nextInt(_codeChars.length)]).join();
}

/// Kullanıcının yazdığı kodu sadeleştirir.
String normalizeCode(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Kodu okunaklı yazar: AB4 K7P
String formatCode(String code) => code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

/// WhatsApp'ta paylaşılan grup çağrısı.
String groupInviteMessage(PrayerGroup g) =>
    'Selamün aleyküm, Ezan Saati\'nde "${g.name}" dua grubuna seni de ekleyelim. '
    'Birlikte hatim, Yâsin ve salavat zincirleri okuyoruz. Katılmak için dokun:\n${groupLink(g.code)}';

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

DateTime _time(Object? v, [DateTime? fallback]) =>
    v is Timestamp ? v.toDate() : (fallback ?? DateTime.fromMillisecondsSinceEpoch(0));

class PrayerGroup {
  final String id;
  final String name;
  final String ownerUid;
  final String ownerName;
  final String code;
  final List<String> memberUids;

  /// uid → grupta görünen ad.
  final Map<String, String> members;

  const PrayerGroup({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.ownerName,
    required this.code,
    required this.memberUids,
    this.members = const {},
  });

  String nameOf(String uid) => members[uid] ?? (uid == ownerUid ? ownerName : 'Üye');
}

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

  /// Yalnız ben zincirinde null.
  final String? groupId;
  final String groupName;
  final String creatorUid;
  final String creatorName;
  final String type;
  final String name;
  final String unit;
  final String intent;
  final int total;

  /// 'pick': herkes kendi seçer · 'equal': eşit bölünür.
  final String mode;
  final DateTime created;
  final DateTime deadline;
  final Map<int, ChainSlot> slots;
  final Map<String, ChainClaim> claims;

  const GroupChain({
    required this.id,
    this.groupId,
    this.groupName = '',
    required this.creatorUid,
    required this.creatorName,
    required this.type,
    required this.name,
    required this.unit,
    this.intent = '',
    required this.total,
    this.mode = 'pick',
    required this.created,
    required this.deadline,
    this.slots = const {},
    this.claims = const {},
  });

  bool get solo => groupId == null;
  bool get isHatim => type == 'hatim';

  /// Okunan (hatimde okunan cüz sayısı).
  int get done => isHatim
      ? slots.values.where((s) => s.done).length
      : claims.values.fold(0, (a, c) => a + min(c.done, c.amount));

  /// Alınan (hatimde alınan cüz sayısı).
  int get taken => isHatim ? slots.length : claims.values.fold(0, (a, c) => a + c.amount);

  int get free => max(0, total - taken);
  bool get complete => done >= total;
  bool get expired => !complete && DateTime.now().isAfter(deadline);
  bool get active => !complete && !expired;
  double get progress => total == 0 ? 0 : min(1, done / total);

  List<int> partsOf(String uid) => (slots.entries.where((e) => e.value.uid == uid).map((e) => e.key).toList())..sort();
  ChainClaim? claimOf(String uid) => claims[uid];

  /// Son güne kalan gün (bugün biterse 0).
  int get daysLeft {
    final now = DateTime.now();
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(deadline.year, deadline.month, deadline.day);
    return max(0, b.difference(a).inDays);
  }

  GroupChain copyWith({Map<int, ChainSlot>? slots, Map<String, ChainClaim>? claims, String? groupName}) =>
      GroupChain(
        id: id,
        groupId: groupId,
        groupName: groupName ?? this.groupName,
        creatorUid: creatorUid,
        creatorName: creatorName,
        type: type,
        name: name,
        unit: unit,
        intent: intent,
        total: total,
        mode: mode,
        created: created,
        deadline: deadline,
        slots: slots ?? this.slots,
        claims: claims ?? this.claims,
      );

  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'type': type,
        'name': name,
        'unit': unit,
        'intent': intent,
        'total': total,
        'created': created.millisecondsSinceEpoch,
        'deadline': deadline.millisecondsSinceEpoch,
        'done': claims[GroupSync.soloUid]?.done ?? 0,
        'parts': [for (final e in slots.entries) if (e.value.done) e.key],
      };

  static GroupChain fromLocalJson(Map<String, dynamic> j) {
    final type = j['type'] as String? ?? 'ozel';
    final total = (j['total'] as num?)?.toInt() ?? 1;
    final parts = [for (final p in (j['parts'] as List<dynamic>? ?? const [])) (p as num).toInt()];
    return GroupChain(
      id: j['id'] as String? ?? '',
      creatorUid: GroupSync.soloUid,
      creatorName: 'Ben',
      type: type,
      name: j['name'] as String? ?? '',
      unit: j['unit'] as String? ?? 'adet',
      intent: j['intent'] as String? ?? '',
      total: total,
      created: DateTime.fromMillisecondsSinceEpoch((j['created'] as num?)?.toInt() ?? 0),
      deadline: DateTime.fromMillisecondsSinceEpoch((j['deadline'] as num?)?.toInt() ?? 0),
      slots: type == 'hatim'
          ? {for (var n = 1; n <= 30; n++) n: ChainSlot(uid: GroupSync.soloUid, name: 'Ben', done: parts.contains(n))}
          : const {},
      claims: type == 'hatim'
          ? const {}
          : {
              GroupSync.soloUid: ChainClaim(
                  uid: GroupSync.soloUid, name: 'Ben', amount: total, done: (j['done'] as num?)?.toInt() ?? 0),
            },
    );
  }
}

enum SyncState { off, connecting, ready, error }

/// Grupları ve zincirleri Firestore'dan dinler; yalnız ben zincirlerini telefonda tutar.
class GroupSync extends ChangeNotifier {
  GroupSync._();
  static final instance = GroupSync._();

  /// Yalnız ben zincirlerinde kişinin yerine geçen kimlik.
  static const soloUid = 'ben';

  static const _nameKey = 'cember_ad';
  static const _soloKey = 'yalniz_zincirler';

  FirebaseFirestore? _db;
  String? _uid;
  SharedPreferences? _p;
  SyncState state = SyncState.off;
  String error = '';
  Future<void>? _starting;
  bool _loaded = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groupsSub;
  final _subs = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final _groups = <String, PrayerGroup>{};
  final _members = <String, Map<String, String>>{};
  final _chains = <String, GroupChain>{}; // anahtar: gid/cid
  final _slots = <String, Map<int, ChainSlot>>{};
  final _claims = <String, Map<String, ChainClaim>>{};
  List<GroupChain> _solo = [];

  bool get ready => state == SyncState.ready;
  String? get uid => _uid;
  String get myName => _p?.getString(_nameKey) ?? '';

  List<PrayerGroup> get groups {
    final l = [
      for (final g in _groups.values)
        PrayerGroup(
          id: g.id,
          name: g.name,
          ownerUid: g.ownerUid,
          ownerName: g.ownerName,
          code: g.code,
          memberUids: g.memberUids,
          members: _members[g.id] ?? const {},
        ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return l;
  }

  PrayerGroup? group(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Bütün zincirler (gruplardakiler ve yalnız ben), yeniden eskiye.
  List<GroupChain> get chains {
    final l = <GroupChain>[
      for (final e in _chains.entries)
        e.value.copyWith(
          slots: _slots[e.key] ?? const {},
          claims: _claims[e.key] ?? const {},
          groupName: _groups[e.value.groupId]?.name ?? '',
        ),
      ..._solo,
    ]..sort((a, b) => b.created.compareTo(a.created));
    return l;
  }

  List<GroupChain> chainsOf(String groupId) => chains.where((c) => c.groupId == groupId).toList();

  GroupChain? chain(String? groupId, String id) {
    for (final c in chains) {
      if (c.groupId == groupId && c.id == id) return c;
    }
    return null;
  }

  /// Bu telefondaki kişinin zincirdeki kimliği.
  String meIn(GroupChain c) => c.solo ? soloUid : (_uid ?? '');

  // ---------------- Başlatma ----------------

  /// Telefonda tutulanları yükler (bir kez).
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _p ??= await SharedPreferences.getInstance();
    final raw = _p!.getString(_soloKey);
    if (raw != null) {
      try {
        _solo = [
          for (final e in jsonDecode(raw) as List<dynamic>) GroupChain.fromLocalJson(e as Map<String, dynamic>),
        ];
      } catch (_) {
        _solo = [];
      }
    }
    notifyListeners();
  }

  /// Firebase'e bağlanır (yalnız Android). Başarısız olursa yalnız ben zincirleri çalışmaya devam eder.
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
    _loaded = false;
    await load();
    await _attach(db, uid, prefs);
  }

  Future<void> _attach(FirebaseFirestore db, String uid, SharedPreferences prefs) async {
    await stop();
    _db = db;
    _uid = uid;
    _p = prefs;
    state = SyncState.ready;
    _groupsSub = db
        .collection('groups')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .listen(_onGroups, onError: _onError);
    notifyListeners();
  }

  /// Dinlemeleri kapatır (testler ve yeniden bağlanma için).
  Future<void> stop() async {
    await _groupsSub?.cancel();
    _groupsSub = null;
    for (final s in _subs.values) {
      await s.cancel();
    }
    _subs.clear();
    _groups.clear();
    _members.clear();
    _chains.clear();
    _slots.clear();
    _claims.clear();
    state = SyncState.off;
    _db = null;
    _uid = null;
    _starting = null;
  }

  @visibleForTesting
  void resetLocal() {
    _solo = [];
    _loaded = false;
    _p = null;
  }

  void _onError(Object e) {
    error = e is FirebaseException ? (e.message ?? e.code) : '$e';
    notifyListeners();
  }

  void _listen(String key, Query<Map<String, dynamic>> q, void Function(QuerySnapshot<Map<String, dynamic>>) on) {
    _subs[key] ??= q.snapshots().listen(on, onError: (_) {});
  }

  void _drop(String prefix) {
    for (final k in _subs.keys.where((k) => k.startsWith(prefix)).toList()) {
      _subs.remove(k)?.cancel();
    }
  }

  void _onGroups(QuerySnapshot<Map<String, dynamic>> snap) {
    final db = _db;
    if (db == null) return;
    final ids = <String>{};
    for (final d in snap.docs) {
      final m = d.data();
      ids.add(d.id);
      _groups[d.id] = PrayerGroup(
        id: d.id,
        name: m['name'] as String? ?? '',
        ownerUid: m['ownerUid'] as String? ?? '',
        ownerName: m['ownerName'] as String? ?? '',
        code: m['code'] as String? ?? '',
        memberUids: [for (final u in (m['memberUids'] as List<dynamic>? ?? const [])) '$u'],
      );
      final ref = db.collection('groups').doc(d.id);
      _listen('m:${d.id}', ref.collection('members'), (s) {
        _members[d.id] = {for (final x in s.docs) x.id: x.data()['name'] as String? ?? ''};
        notifyListeners();
      });
      _listen('c:${d.id}', ref.collection('chains').orderBy('created', descending: true).limit(20),
          (s) => _onChains(d.id, s));
    }
    for (final gid in _groups.keys.where((g) => !ids.contains(g)).toList()) {
      _groups.remove(gid);
      _members.remove(gid);
      _drop('m:$gid');
      _drop('c:$gid');
      _drop('p:$gid/');
      _chains.removeWhere((k, _) => k.startsWith('$gid/'));
    }
    notifyListeners();
  }

  void _onChains(String gid, QuerySnapshot<Map<String, dynamic>> snap) {
    final db = _db;
    if (db == null) return;
    final keys = <String>{};
    for (final d in snap.docs) {
      final m = d.data();
      final key = '$gid/${d.id}';
      keys.add(key);
      final type = m['type'] as String? ?? 'ozel';
      _chains[key] = GroupChain(
        id: d.id,
        groupId: gid,
        creatorUid: m['creatorUid'] as String? ?? '',
        creatorName: m['creatorName'] as String? ?? '',
        type: type,
        name: m['name'] as String? ?? '',
        unit: m['unit'] as String? ?? 'adet',
        intent: m['intent'] as String? ?? '',
        total: (m['total'] as num?)?.toInt() ?? 1,
        mode: m['mode'] as String? ?? 'pick',
        created: _time(m['created']),
        deadline: _time(m['deadline']),
      );
      final ref = d.reference;
      if (type == 'hatim') {
        _listen('p:$key', ref.collection('slots'), (s) {
          _slots[key] = {
            for (final x in s.docs)
              if (int.tryParse(x.id) != null)
                int.parse(x.id): ChainSlot(
                  uid: x.data()['uid'] as String? ?? '',
                  name: x.data()['name'] as String? ?? '',
                  done: x.data()['done'] == true,
                ),
          };
          notifyListeners();
        });
      } else {
        _listen('p:$key', ref.collection('claims'), (s) {
          _claims[key] = {
            for (final x in s.docs)
              x.id: ChainClaim(
                uid: x.id,
                name: x.data()['name'] as String? ?? '',
                amount: (x.data()['amount'] as num?)?.toInt() ?? 0,
                done: (x.data()['done'] as num?)?.toInt() ?? 0,
              ),
          };
          notifyListeners();
        });
      }
    }
    for (final key in _chains.keys.where((k) => k.startsWith('$gid/') && !keys.contains(k)).toList()) {
      _chains.remove(key);
      _slots.remove(key);
      _claims.remove(key);
      _drop('p:$key');
    }
    notifyListeners();
  }

  // ---------------- Profil ----------------

  Future<void> saveName(String name) async {
    _p ??= await SharedPreferences.getInstance();
    await _p!.setString(_nameKey, name.trim());
    final db = _db, uid = _uid;
    if (db != null && uid != null) {
      // Adı bütün gruplarımda güncelle.
      final b = db.batch();
      for (final g in _groups.values) {
        b.set(db.collection('groups').doc(g.id).collection('members').doc(uid),
            {'name': name.trim(), 'joinedAt': Timestamp.now()});
      }
      await b.commit();
    }
    notifyListeners();
  }

  // ---------------- Gruplar ----------------

  FirebaseFirestore _need() {
    final db = _db;
    if (db == null || _uid == null) {
      throw StateError('İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edip tekrar deneyin.');
    }
    return db;
  }

  Future<PrayerGroup> createGroup(String name) async {
    final db = _need();
    final uid = _uid!;
    var code = newGroupCode();
    for (var i = 0; i < 5; i++) {
      final ex = await db.collection('groupCodes').doc(code).get();
      if (!ex.exists) break;
      code = newGroupCode();
    }
    final ref = db.collection('groups').doc();
    final b = db.batch();
    final now = Timestamp.now();
    b.set(ref, {
      'ownerUid': uid,
      'ownerName': myName,
      'name': name.trim(),
      'code': code,
      'memberUids': [uid],
      'created': now,
      'updatedAt': now,
    });
    b.set(ref.collection('members').doc(uid), {'name': myName, 'joinedAt': now});
    b.set(db.collection('groupCodes').doc(code), {'gid': ref.id, 'name': name.trim(), 'ownerName': myName});
    await b.commit();
    final g = PrayerGroup(
        id: ref.id, name: name.trim(), ownerUid: uid, ownerName: myName, code: code, memberUids: [uid],
        members: {uid: myName});
    _groups[ref.id] = g;
    notifyListeners();
    return g;
  }

  /// Grup kodundan grup bilgisi: (gid, grup adı, kuran). Kod yoksa null.
  Future<(String, String, String)?> lookupCode(String code) async {
    final db = _need();
    final d = await db.collection('groupCodes').doc(normalizeCode(code)).get();
    final m = d.data();
    if (!d.exists || m == null) return null;
    return (m['gid'] as String? ?? '', m['name'] as String? ?? '', m['ownerName'] as String? ?? '');
  }

  bool isMember(String gid) => _groups.containsKey(gid);

  Future<void> joinGroup(String gid) async {
    final db = _need();
    final uid = _uid!;
    final ref = db.collection('groups').doc(gid);
    final b = db.batch();
    b.update(ref, {'memberUids': FieldValue.arrayUnion([uid]), 'updatedAt': Timestamp.now()});
    b.set(ref.collection('members').doc(uid), {'name': myName, 'joinedAt': Timestamp.now()});
    await b.commit();
  }

  /// Üye gruptan ayrılır; kurucu ayrılırsa grup silinir.
  Future<void> leaveGroup(PrayerGroup g) async {
    final db = _need();
    final uid = _uid!;
    final ref = db.collection('groups').doc(g.id);
    if (g.ownerUid == uid) {
      // Önce zincirler ve alt belgeleri, sonra grup.
      final chains = await ref.collection('chains').get();
      for (final c in chains.docs) {
        await _deleteChainDocs(c.reference);
      }
      final b = db.batch();
      for (final m in (await ref.collection('members').get()).docs) {
        b.delete(m.reference);
      }
      b.delete(db.collection('groupCodes').doc(g.code));
      b.delete(ref);
      await b.commit();
    } else {
      final b = db.batch();
      b.delete(ref.collection('members').doc(uid));
      b.update(ref, {'memberUids': FieldValue.arrayRemove([uid]), 'updatedAt': Timestamp.now()});
      await b.commit();
    }
    _groups.remove(g.id);
    notifyListeners();
  }

  /// Kurucu bir üyeyi gruptan çıkarır.
  Future<void> removeMember(PrayerGroup g, String memberUid) async {
    final db = _need();
    final ref = db.collection('groups').doc(g.id);
    final b = db.batch();
    b.delete(ref.collection('members').doc(memberUid));
    b.update(ref, {'memberUids': FieldValue.arrayRemove([memberUid]), 'updatedAt': Timestamp.now()});
    await b.commit();
  }

  // ---------------- Zincirler ----------------

  /// Zincir başlatır. [groupId] null ise yalnız ben zinciri (telefonda).
  Future<GroupChain> startChain({
    required String? groupId,
    required String type,
    required String name,
    required String unit,
    required int total,
    required String mode,
    required int days,
    String intent = '',
  }) async {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + days, 23, 59);
    final deadline = end.difference(now).inDays >= kChainMaxDays ? now.add(const Duration(days: kChainMaxDays)) : end;
    final hatim = type == 'hatim';
    if (hatim) total = 30;
    if (groupId == null) {
      await load();
      final c = GroupChain.fromLocalJson({
        'id': '${now.microsecondsSinceEpoch}',
        'type': type,
        'name': name,
        'unit': unit,
        'intent': intent,
        'total': total,
        'created': now.millisecondsSinceEpoch,
        'deadline': deadline.millisecondsSinceEpoch,
      });
      _solo.add(c);
      await _saveSolo();
      notifyListeners();
      return c;
    }
    final db = _need();
    final uid = _uid!;
    final g = group(groupId);
    final ref = db.collection('groups').doc(groupId).collection('chains').doc();
    final b = db.batch();
    b.set(ref, {
      'creatorUid': uid,
      'creatorName': myName,
      'type': type,
      'name': name.trim(),
      'unit': unit,
      'intent': intent.trim(),
      'total': total,
      'mode': mode,
      'created': Timestamp.fromDate(now),
      'deadline': Timestamp.fromDate(deadline),
    });
    if (mode == 'equal' && g != null && g.memberUids.isNotEmpty) {
      final ms = [...g.memberUids];
      final n = ms.length;
      for (var i = 0; i < n; i++) {
        final share = total ~/ n + (i < total % n ? 1 : 0);
        if (share == 0) continue;
        final who = ms[i];
        if (hatim) {
          final first = i * (total ~/ n) + min(i, total % n) + 1;
          for (var p = first; p < first + share; p++) {
            b.set(ref.collection('slots').doc('$p'), {'uid': who, 'name': g.nameOf(who), 'done': false});
          }
        } else {
          b.set(ref.collection('claims').doc(who), {'name': g.nameOf(who), 'amount': share, 'done': 0});
        }
      }
    }
    await b.commit();
    final c = GroupChain(
      id: ref.id,
      groupId: groupId,
      groupName: g?.name ?? '',
      creatorUid: uid,
      creatorName: myName,
      type: type,
      name: name.trim(),
      unit: unit,
      intent: intent.trim(),
      total: total,
      mode: mode,
      created: now,
      deadline: deadline,
    );
    _chains['$groupId/${ref.id}'] ??= c;
    notifyListeners();
    return c;
  }

  DocumentReference<Map<String, dynamic>> _chainRef(GroupChain c) =>
      _need().collection('groups').doc(c.groupId).collection('chains').doc(c.id);

  /// Hatimde cüz alır.
  Future<void> takeParts(GroupChain c, List<int> parts) async {
    if (c.solo) return;
    final db = _need();
    final ref = _chainRef(c);
    final b = db.batch();
    for (final p in parts) {
      b.set(ref.collection('slots').doc('$p'), {'uid': _uid, 'name': myName, 'done': false});
    }
    await b.commit();
  }

  /// Hatimde alınan cüzü bırakır.
  Future<void> releasePart(GroupChain c, int part) async {
    if (c.solo) return;
    await _chainRef(c).collection('slots').doc('$part').delete();
  }

  /// Cüzü okundu / okunmadı yapar.
  Future<void> markPart(GroupChain c, int part, bool done) async {
    if (c.solo) {
      final parts = {for (final e in c.slots.entries) if (e.value.done) e.key};
      done ? parts.add(part) : parts.remove(part);
      _updateSolo(c, parts: parts.toList());
      return;
    }
    await _chainRef(c).collection('slots').doc('$part').update({'done': done});
  }

  /// Sayılı zincirde pay alır ya da payını değiştirir.
  Future<void> setAmount(GroupChain c, int amount) async {
    if (c.solo) return;
    final uid = _uid;
    final mine = c.claimOf(uid ?? '');
    final ref = _chainRef(c).collection('claims').doc(uid);
    if (mine == null) {
      await ref.set({'name': myName, 'amount': amount, 'done': 0});
    } else if (amount <= 0 && mine.done == 0) {
      await ref.delete();
    } else {
      await ref.update({'amount': max(amount, mine.done)});
    }
  }

  /// Okunan adedi yazar (0 ile pay arasında).
  Future<void> setDone(GroupChain c, int done) async {
    if (c.solo) {
      _updateSolo(c, done: done.clamp(0, c.total));
      return;
    }
    final mine = c.claimOf(_uid ?? '');
    if (mine == null) return;
    await _chainRef(c).collection('claims').doc(_uid).update({'done': done.clamp(0, mine.amount)});
  }

  Future<void> _deleteChainDocs(DocumentReference<Map<String, dynamic>> ref) async {
    final db = _need();
    final b = db.batch();
    for (final s in (await ref.collection('slots').get()).docs) {
      b.delete(s.reference);
    }
    for (final s in (await ref.collection('claims').get()).docs) {
      b.delete(s.reference);
    }
    b.delete(ref);
    await b.commit();
  }

  /// Zinciri siler (başlatan ya da grup kurucusu).
  Future<void> deleteChain(GroupChain c) async {
    if (c.solo) {
      _solo.removeWhere((x) => x.id == c.id);
      await _saveSolo();
      notifyListeners();
      return;
    }
    await _deleteChainDocs(_chainRef(c));
  }

  bool canDelete(GroupChain c) =>
      c.solo || c.creatorUid == _uid || (group(c.groupId ?? '')?.ownerUid == _uid && _uid != null);

  void _updateSolo(GroupChain c, {int? done, List<int>? parts}) {
    final i = _solo.indexWhere((x) => x.id == c.id);
    if (i < 0) return;
    final j = _solo[i].toLocalJson();
    if (done != null) j['done'] = done;
    if (parts != null) j['parts'] = parts;
    _solo[i] = GroupChain.fromLocalJson(j);
    unawaited(_saveSolo());
    notifyListeners();
  }

  Future<void> _saveSolo() async {
    _p ??= await SharedPreferences.getInstance();
    await _p!.setString(_soloKey, jsonEncode([for (final c in _solo) c.toLocalJson()]));
  }
}
