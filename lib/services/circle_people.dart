import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dua_circle_store.dart';

/// Dua Zinciri kişilerim listesindeki bir kişi. Numara yalnız bu telefonda tutulur, sunucuya yazılmaz.
class CirclePerson {
  String name;
  String phone;

  /// Daveti uygulamadan kabul ettiyse uygulamayı kullanıyor demektir; sonraki davetler ona
  /// uygulama içinden gider (WhatsApp gerekmez).
  bool inApp;

  CirclePerson({required this.name, required this.phone, this.inApp = false});

  Map<String, dynamic> toJson() => {'n': name, 'p': phone, 'a': inApp};

  factory CirclePerson.fromJson(Map<String, dynamic> j) =>
      CirclePerson(name: j['n'] as String? ?? '', phone: j['p'] as String? ?? '', inApp: j['a'] as bool? ?? false);
}

/// "Kişilerim": rehberden bir kez eklenen, yeni zincirlerde tekrar seçilen kişiler.
class CirclePeople extends ChangeNotifier {
  CirclePeople._();
  static final instance = CirclePeople._();

  static const _key = 'cember_kisiler';

  SharedPreferences? _p;
  List<CirclePerson> _people = [];

  List<CirclePerson> get people => List.unmodifiable(_people);

  /// Listeyi bir kez yükler (sonraki çağrılar bir şey yapmaz).
  Future<void> load() => _loading ??= _load();
  Future<void>? _loading;

  Future<void> _load() async {
    _p ??= await SharedPreferences.getInstance();
    final raw = _p!.getString(_key);
    if (raw != null) {
      try {
        _people = [for (final e in jsonDecode(raw) as List<dynamic>) CirclePerson.fromJson(e as Map<String, dynamic>)];
      } catch (_) {
        _people = [];
      }
    }
    notifyListeners();
  }

  @visibleForTesting
  void replaceAll(List<CirclePerson> list) {
    _loading = Future.value();
    _people = [...list];
    notifyListeners();
  }

  void _save() {
    _p?.setString(_key, jsonEncode([for (final p in _people) p.toJson()]));
    notifyListeners();
  }

  CirclePerson? find(String phone) {
    final wa = waNumber(phone);
    if (wa.isEmpty) return null;
    for (final p in _people) {
      if (waNumber(p.phone) == wa) return p;
    }
    return null;
  }

  bool isInApp(String phone) => find(phone)?.inApp ?? false;

  /// Kişiyi listeye ekler; aynı numara zaten varsa adını günceller. Numarasız kişi eklenmez.
  void add(String name, String phone) {
    if (waNumber(phone).isEmpty) return;
    final old = find(phone);
    if (old != null) {
      if (name.isNotEmpty && old.name != name) {
        old.name = name;
        _save();
      }
      return;
    }
    _people.add(CirclePerson(name: name.isEmpty ? phone : name, phone: phone));
    _people.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _save();
  }

  void remove(CirclePerson p) {
    _people.remove(p);
    _save();
  }

  /// Zincirlerimde daveti uygulamadan kabul eden kişileri "uygulamada" olarak işaretler.
  void markInApp(Iterable<String> phones) {
    var changed = false;
    for (final ph in phones) {
      final p = find(ph);
      if (p != null && !p.inApp) {
        p.inApp = true;
        changed = true;
      }
    }
    if (changed) _save();
  }
}

/// Uygulamayı önerme mesajı (zincirsiz; yalnız indirme bağlantısı).
String appSuggestMessage() =>
    'Selamün aleyküm, dua zincirlerinde birlikte okumak için Ezan Saati uygulamasını kurmanı öneririm. '
    'Kurduktan sonra davetlerim sana doğrudan uygulamadan gelir.\n\n$kAppLink';
