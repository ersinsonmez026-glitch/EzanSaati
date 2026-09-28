import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'circle_sync.dart';

/// Dua Çemberi: bir görevi (salavat, Yasin, hatim…) kişilere bölüştürme.
///
/// İki tür çember vardır:
/// * Telefonda tutulan çemberler (1. aşama; Firebase bağlantısı yokken de kurulur).
/// * Ortak çemberler (2. aşama): Firebase'de tutulur, davet/kabul ve ilerleme
///   herkes için eşitlenir. Bkz. circle_sync.dart.

/// Dua türü. [key] 'ozel' ise duanın adını kişi kendisi yazar.
class DuaType {
  final String key;
  final String title;
  final String unit;
  final int defaultTotal;

  const DuaType(this.key, this.title, this.unit, this.defaultTotal);
}

const kDuaTypes = [
  DuaType('salavat', 'Salavat', 'salavat', 110),
  DuaType('yasin', 'Yasin', 'Yasin', 41),
  DuaType('hatim', 'Hatim', 'cüz', 30),
  DuaType('ihlas', 'İhlas', 'İhlas', 1000),
  DuaType('istigfar', 'İstiğfar', 'istiğfar', 1000),
  DuaType('ozel', 'Özel', 'adet', 100),
];

/// Önerilen hazır çemberler: (tür, ad, toplam).
const kCircleTemplates = [
  ('yasin', '41 Yasin', 41),
  ('ihlas', '1000 İhlas', 1000),
  ('salavat', '110 Salavat', 110),
  ('hatim', 'Hatim', 30),
  ('istigfar', '100 İstiğfar', 100),
  ('ozel', '70.000 Kelime-i Tevhid', 70000),
];

/// Çemberin en uzun süresi (gün) ve davete yanıt süresi.
const kCircleMaxDays = 30;
const kInviteHours = 24;

/// Davet mesajındaki uygulama indirme bağlantısı. Uygulama Play Store'a
/// çıkınca buraya yazılacak; boşken mesaja bağlantı eklenmez.
const kAppLink = '';

/// [me]: çemberi kuran kişi (adı eski kayıtlarla uyum için korunuyor).
enum MemberStatus { me, pending, accepted, declined }

class CircleMember {
  String key; // ortak çemberde belge kimliği (kurucu: uid, davetli: davet kodu)
  String name;
  String phone; // yalnız bu telefonda tutulur, sunucuya yazılmaz
  int share; // bu kişiye düşen adet
  int done; // okuduğu adet
  MemberStatus status;
  DateTime invitedAt;
  String? uid; // ortak çemberde katılan kişinin kimliği
  bool self; // bu telefondaki kişi mi

  CircleMember({
    this.key = '',
    required this.name,
    this.phone = '',
    this.share = 0,
    this.done = 0,
    this.status = MemberStatus.pending,
    DateTime? invitedAt,
    this.uid,
    bool? self,
  })  : invitedAt = invitedAt ?? DateTime.now(),
        self = self ?? status == MemberStatus.me;

  /// Bu telefondaki kişi ("Sen").
  bool get isMe => self;
  bool get isOwner => status == MemberStatus.me;
  bool get isPending => status == MemberStatus.pending;
  bool get isDeclined => status == MemberStatus.declined;

  /// Davetin bitişine kalan süre (bekleyenler için).
  Duration inviteLeft(DateTime now) => invitedAt.add(const Duration(hours: kInviteHours)).difference(now);

  Map<String, dynamic> toJson() => {
        'n': name,
        'p': phone,
        's': share,
        'd': done,
        'st': status.name,
        'i': invitedAt.toIso8601String(),
        if (key.isNotEmpty) 'k': key,
        if (uid != null) 'u': uid,
        'sf': self,
      };

  factory CircleMember.fromJson(Map<String, dynamic> j) => CircleMember(
        name: j['n'] as String,
        phone: j['p'] as String? ?? '',
        share: j['s'] as int,
        done: j['d'] as int? ?? 0,
        status: MemberStatus.values.firstWhere((s) => s.name == j['st'], orElse: () => MemberStatus.pending),
        invitedAt: DateTime.parse(j['i'] as String),
        key: j['k'] as String? ?? '',
        uid: j['u'] as String?,
        self: j['sf'] as bool?,
      );

  CircleMember copy() => CircleMember.fromJson(toJson());
}

class DuaCircle {
  final String id;
  String type;
  String name;
  String intent;
  int total;
  DateTime created;
  DateTime end; // son gün (gün sonuna kadar)
  List<CircleMember> members;
  String notice; // kurucuya bilgi (ör. yanıt vermeyenin payı döndü)
  bool remote; // ortak (Firebase) çember mi
  bool mine; // bu telefondaki kişi mi kurdu
  String ownerUid;
  String ownerName;

  DuaCircle({
    required this.id,
    required this.type,
    required this.name,
    this.intent = '',
    required this.total,
    required this.created,
    required this.end,
    required this.members,
    this.notice = '',
    this.remote = false,
    this.mine = true,
    this.ownerUid = '',
    this.ownerName = '',
  });

  DuaType get duaType => kDuaTypesByKey[type] ?? kDuaTypes.last;
  String get unit => duaType.unit;

  /// Bu telefondaki kişinin kaydı ("Senin görevin").
  CircleMember get me => members.firstWhere((m) => m.isMe);
  CircleMember? get meOrNull {
    for (final m in members) {
      if (m.isMe) return m;
    }
    return null;
  }

  CircleMember get owner => members.firstWhere((m) => m.isOwner);

  /// Kabul etmiş olanlar ve kurucu.
  List<CircleMember> get active => members.where((m) => m.isOwner || m.status == MemberStatus.accepted).toList();
  List<CircleMember> get pending => members.where((m) => m.isPending).toList();

  int get done => active.fold(0, (s, m) => s + m.done);
  int get remaining => (total - done).clamp(0, total);
  bool get isComplete => done >= total;
  int get percent => total == 0 ? 0 : (done * 100 ~/ total).clamp(0, 100);

  /// Bitiş gününün ertesi başlangıcı.
  DateTime get deadline => DateTime(end.year, end.month, end.day + 1);

  Map<String, dynamic> toJson() => {
        'id': id,
        't': type,
        'n': name,
        'in': intent,
        'tot': total,
        'c': created.toIso8601String(),
        'e': end.toIso8601String(),
        'm': members.map((m) => m.toJson()).toList(),
        'no': notice,
      };

  factory DuaCircle.fromJson(Map<String, dynamic> j) => DuaCircle(
        id: j['id'] as String,
        type: j['t'] as String,
        name: j['n'] as String,
        intent: j['in'] as String? ?? '',
        total: j['tot'] as int,
        created: DateTime.parse(j['c'] as String),
        end: DateTime.parse(j['e'] as String),
        members: [for (final m in j['m'] as List) CircleMember.fromJson(m as Map<String, dynamic>)],
        notice: j['no'] as String? ?? '',
      );
}

final kDuaTypesByKey = {for (final t in kDuaTypes) t.key: t};

/// [total] adedi [count] kişiye eşit böler; artanlar baştakilere verilir.
List<int> splitEvenly(int total, int count) {
  if (count <= 0) return const [];
  final base = total ~/ count, rest = total - base * count;
  return [for (var i = 0; i < count; i++) base + (i < rest ? 1 : 0)];
}

/// WhatsApp için telefon numarası: yalnız rakam, ülke koduyla (Türkiye varsayılır).
/// Geçersizse boş döner.
String waNumber(String phone) {
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('00')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = '90${d.substring(1)}';
  if (d.length == 10 && d.startsWith('5')) d = '90$d';
  return d.length >= 10 ? d : '';
}

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık'
];

String trDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';
String trDateShort(DateTime d) => '${d.day} ${_months[d.month - 1].substring(0, 3)}';

/// Sayıyı binlik ayraçla yazar: 70000 → 70.000
String trNum(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// Davet mesajı.
String inviteMessage(DuaCircle c, CircleMember m) {
  final first = m.name.trim().split(RegExp(r'\s+')).first;
  final b = StringBuffer()
    ..write('Selamün aleyküm $first, "${c.name}" dua çemberine seni davet ediyorum. ')
    ..write('Sana düşen: ${trNum(m.share)} ${c.unit}.');
  if (c.intent.isNotEmpty) b.write('\nNiyet: ${c.intent}');
  b.write('\nSon gün: ${trDate(c.end)}. Davet $kInviteHours saat geçerlidir.');
  if (c.remote && m.key.isNotEmpty) {
    b.write('\nDavet kodun: ${formatCode(m.key)}');
    b.write('\nEzan Saati uygulamasında Dua Çemberi > Davetler bölümüne bu kodu yazarak katılabilirsin.');
  } else {
    b.write('\nEzan Saati uygulamasındaki Dua Çemberi bölümünden katılabilirsin.');
  }
  if (kAppLink.isNotEmpty) b.write('\nUygulama yüklü değilse: $kAppLink');
  return b.toString();
}

/// Çemberlerin kaydı. Telefondaki çemberler SharedPreferences'ta (JSON) tutulur;
/// ortak çemberler [CircleSync] tarafından Firestore'dan gelir.
class DuaCircleStore extends ChangeNotifier {
  DuaCircleStore._();
  static final instance = DuaCircleStore._();

  static const _key = 'cember_v1';

  SharedPreferences? _p;
  List<DuaCircle> _circles = [];
  List<DuaCircle> _remote = [];
  String _lastCleanup = '';

  /// Ortak ve telefondaki çemberler, yeniden eskiye.
  List<DuaCircle> get circles =>
      List.unmodifiable([..._remote, ..._circles]..sort((a, b) => b.created.compareTo(a.created)));

  /// Son temizlikte silinen çemberlerin adları (bir kez gösterilir).
  String takeCleanupNote() {
    final s = _lastCleanup;
    _lastCleanup = '';
    return s;
  }

  bool get loaded => _p != null;

  Future<void> load() async {
    _p ??= await SharedPreferences.getInstance();
    final raw = _p!.getString(_key);
    _circles = [];
    if (raw != null) {
      try {
        _circles = [for (final j in jsonDecode(raw) as List) DuaCircle.fromJson(j as Map<String, dynamic>)];
      } catch (_) {
        _circles = [];
      }
    }
    if (cleanup(DateTime.now())) _save();
    notifyListeners();
  }

  /// Ortak çemberler (CircleSync'ten).
  void setRemote(List<DuaCircle> list) {
    _remote = list;
    notifyListeners();
  }

  void notifyRemoteChanged() => notifyListeners();

  /// Süre kurallarını telefondaki çemberlere uygular (ortak çemberlerde CircleSync uygular):
  /// * 24 saat içinde yanıt vermeyen davetlinin payı kurucuya döner.
  /// * Son günü geçen ve tamamlanmamış çemberler silinir; tamamlananlar saklanır.
  /// Değişiklik olduysa true döner.
  @visibleForTesting
  bool cleanup(DateTime now) {
    var changed = false;
    final removed = <String>[];
    _circles.removeWhere((c) {
      if (!c.isComplete && !now.isBefore(c.deadline)) {
        removed.add(c.name);
        return true;
      }
      return false;
    });
    if (removed.isNotEmpty) {
      changed = true;
      _lastCleanup =
          'Süresi dolan ${removed.length == 1 ? '"${removed.first}" çemberi' : '${removed.length} çember'} silindi.';
    }
    for (final c in _circles) {
      final late = c.pending.where((m) => m.inviteLeft(now) <= Duration.zero).toList();
      if (late.isEmpty) continue;
      for (final m in late) {
        c.owner.share += m.share;
        c.members.remove(m);
      }
      final names = late.map((m) => m.name).join(', ');
      final sum = late.fold(0, (s, m) => s + m.share);
      c.notice = '$names $kInviteHours saat içinde yanıt vermedi. ${trNum(sum)} ${c.unit} size döndü; '
          'dilerseniz Kişi Ekle ile başkasına verebilirsiniz.';
      changed = true;
    }
    return changed;
  }

  DuaCircle? byId(String id) {
    for (final c in circles) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Telefondaki çemberi ekler ya da günceller.
  void upsert(DuaCircle c) {
    final i = _circles.indexWhere((x) => x.id == c.id);
    if (i < 0) {
      _circles.insert(0, c);
    } else {
      _circles[i] = c;
    }
    _save();
  }

  /// Formdan gelen çemberi kaydeder. Firebase bağlıysa yeni çember ortak kurulur;
  /// telefondaki (1. aşama) çemberler telefonda kalır.
  Future<DuaCircle> save(DuaCircle c, {required bool isNew}) async {
    final sync = CircleSync.instance;
    if (c.remote) {
      await sync.updateCircle(c);
      notifyListeners();
      return c;
    }
    if (isNew && sync.ready) return sync.createCircle(c);
    upsert(c);
    return c;
  }

  Future<void> delete(DuaCircle c) async {
    if (c.remote) return CircleSync.instance.deleteCircle(c);
    _circles.removeWhere((x) => x.id == c.id);
    _save();
  }

  /// Kendi okumamı ekler (adet sınırı: payım).
  Future<void> addMine(DuaCircle c, int n) async {
    final me = c.me;
    final v = (me.done + n).clamp(0, me.share);
    if (c.remote) return CircleSync.instance.setDone(c, me, v);
    me.done = v;
    _save();
  }

  Future<void> setDone(DuaCircle c, CircleMember m, int value) async {
    if (c.remote) return CircleSync.instance.setDone(c, m, value);
    m.done = value.clamp(0, m.share);
    _save();
  }

  Future<void> accept(DuaCircle c, CircleMember m) async {
    if (c.remote) return CircleSync.instance.markAccepted(c, m);
    m.status = MemberStatus.accepted;
    _save();
  }

  /// Henüz okumaya başlamamış kişiyi çıkarır; payı kurucuya döner.
  Future<void> removeMember(DuaCircle c, CircleMember m) async {
    if (m.isOwner || m.done > 0) return;
    if (c.remote) return CircleSync.instance.removeMember(c, m);
    c.owner.share += m.share;
    c.members.remove(m);
    _save();
  }

  Future<void> dismissNotice(DuaCircle c) async {
    if (c.remote) return CircleSync.instance.dismissNotice(c);
    c.notice = '';
    _save();
  }

  void _save() {
    _p?.setString(_key, jsonEncode([for (final c in _circles) c.toJson()]));
    notifyListeners();
  }

  @visibleForTesting
  void replaceAll(List<DuaCircle> list) {
    _circles = list;
  }
}

/// Telefonun kendi kişi seçicisi (rehber izni gerekmez; yalnız seçilen kişi gelir).
class ContactPicker {
  static const _ch = MethodChannel('ezan_saati/contacts');

  /// (ad, numara) döner. Vazgeçilirse null.
  /// Bu cihazda desteklenmiyorsa [UnsupportedError] fırlatır.
  static Future<(String, String)?> pick() async {
    if (kIsWeb) throw UnsupportedError('web');
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('pick');
      if (r == null) return null;
      return ((r['name'] as String? ?? '').trim(), (r['phone'] as String? ?? '').trim());
    } on MissingPluginException {
      throw UnsupportedError('no-channel');
    } on PlatformException {
      throw UnsupportedError('failed');
    }
  }
}
