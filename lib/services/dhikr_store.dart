import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'home_widgets.dart';

/// Zikir Sayacı'nın zikirleri ve sayım durumu (onizleme/06-zikir-sayaci.html).
/// Sayılar yalnızca bu cihazda saklanır.
class Dhikr {
  final String id;
  final String title;
  final String arabic;
  final String meaning;
  final String? short; // listede görünen kısa ad (ör. "Salavât")
  final int target; // önerilen hedef; 0 = serbest
  final bool custom;

  const Dhikr(this.id, this.title, this.arabic, this.meaning, this.target, {this.short, this.custom = false});

  String get label => short ?? title;

  Map<String, dynamic> toJson() => {'id': id, 't': title, 'h': target};

  static Dhikr fromJson(Map<String, dynamic> j) =>
      Dhikr(j['id'] as String, j['t'] as String, '', '', (j['h'] as num?)?.toInt() ?? 100, custom: true);
}

/// Onaylı önizlemedeki zikirler (metinler KONTROL_LISTESI.md 3. bölümde hoca kontrolünde).
const kDhikrs = <Dhikr>[
  Dhikr('subhan', 'Sübhânallâh', 'سُبْحَانَ اللّٰهِ', 'Allah her türlü noksanlıktan uzaktır.', 33),
  Dhikr('hamd', 'Elhamdülillâh', 'اَلْحَمْدُ لِلّٰهِ', "Hamd Allah'a mahsustur.", 33),
  Dhikr('tekbir', 'Allâhü ekber', 'اَللّٰهُ اَكْبَرُ', 'Allah en büyüktür.', 33),
  Dhikr('tevhid', 'Lâ ilâhe illallâh', 'لَا اِلٰهَ اِلَّا اللّٰهُ', "Allah'tan başka ilah yoktur.", 100),
  Dhikr('istigfar', 'Estağfirullâh', 'اَسْتَغْفِرُ اللّٰهَ', "Allah'tan bağışlanma dilerim.", 100),
  Dhikr('salavat', 'Allâhümme salli alâ Muhammed', 'اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ',
      "Allah'ım! Muhammed'e rahmet eyle.", 100,
      short: 'Salavât'),
];

/// Tesbihatın sonunda bir kez okunan tevhid.
const kTesbihatTevhidArabic = 'لَا اِلٰهَ اِلَّا اللّٰهُ وَحْدَهُ لَا شَرِيكَ لَهُ لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ '
    'وَهُوَ عَلٰى كُلِّ شَيْءٍ قَدِيرٌ';
const kTesbihatTevhidReading =
    "Lâ ilâhe illallâhü vahdehû lâ şerîke leh, lehü'l-mülkü ve lehü'l-hamdü ve hüve alâ külli şey'in kadîr.";

/// Tesbihat sırası: 33 Sübhânallâh, 33 Elhamdülillâh, 33 Allâhü ekber, ardından tevhid.
const kTesbihatSeq = ['subhan', 'hamd', 'tekbir'];

/// Seçilebilir hedefler; 0 = serbest (∞).
const kDhikrTargets = [33, 99, 100, 0];

/// Bir sayıma dokunulduğunda ne olduğu.
enum DhikrHit { counted, round, tesbihatStep, ignored }

class DhikrCounter {
  int n = 0; // bu turdaki sayı
  int rounds = 0; // tamamlanan tur
  DhikrCounter([this.n = 0, this.rounds = 0]);
}

class DhikrState {
  static const _key = 'zikir_v2';

  String selected = 'subhan';
  final Map<String, DhikrCounter> counts = {};
  final Map<String, int> targets = {}; // kullanıcının seçtiği hedef
  final List<Dhikr> custom = [];
  bool vibrate = true;
  String day = '';
  final Map<String, int> today = {}; // bugün çekilen (zikir başına)
  final Map<String, int> history = {}; // gün → o gün çekilen toplam (Takibim sayfası; son 120 gün)

  /// Tesbihat modu: null = kapalı, 0–2 = sıradaki zikir, 3 = tevhid.
  int? tesbihat;
  String? _beforeTesbihat;

  SharedPreferences? _p;
  final DateTime Function() _now;

  DhikrState({DateTime Function()? now}) : _now = now ?? DateTime.now;

  List<Dhikr> get all => [...kDhikrs, ...custom];

  Dhikr get current => byId(selected);

  Dhikr byId(String id) => all.firstWhere((z) => z.id == id, orElse: () => kDhikrs.first);

  DhikrCounter counter(String id) => counts.putIfAbsent(id, DhikrCounter.new);

  /// Seçili zikrin hedefi; tesbihatta her adım 33'tür.
  int targetOf(String id) => tesbihat != null ? 33 : (targets[id] ?? byId(id).target);

  int get todayTotal => today.values.fold(0, (a, b) => a + b);

  String _dayKey() => dayKeyOf(_now());

  static String dayKeyOf(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// O gün çekilen toplam zikir.
  int onDay(DateTime d) => history[dayKeyOf(d)] ?? 0;

  void _rollDay() {
    final k = _dayKey();
    if (day != k) {
      day = k;
      today.clear();
    }
  }

  // ------------------------------------------------------------------ sayım

  DhikrHit add() {
    if (tesbihat == 3) return DhikrHit.ignored;
    _rollDay();
    final z = current, c = counter(z.id), t = targetOf(z.id);
    if (t > 0 && c.n >= t) c.n = 0;
    c.n++;
    today[z.id] = (today[z.id] ?? 0) + 1;
    history[day] = (history[day] ?? 0) + 1;
    var hit = DhikrHit.counted;
    if (t > 0 && c.n == t) {
      c.rounds++;
      hit = DhikrHit.round;
      if (tesbihat != null) {
        _nextStep();
        hit = DhikrHit.tesbihatStep;
      }
    }
    save();
    return hit;
  }

  bool undo() {
    final c = counter(selected);
    if (c.n == 0) return false;
    c.n--;
    today[selected] = ((today[selected] ?? 0) - 1).clamp(0, 1 << 30);
    history[day] = ((history[day] ?? 0) - 1).clamp(0, 1 << 30);
    save();
    return true;
  }

  bool reset() {
    final c = counter(selected);
    if (c.n == 0 && c.rounds == 0) return false;
    c
      ..n = 0
      ..rounds = 0;
    save();
    return true;
  }

  void setTarget(int t) {
    if (tesbihat != null) return;
    targets[selected] = t;
    save();
  }

  void select(String id) {
    if (tesbihat != null) stopTesbihat();
    selected = id;
    save();
  }

  void toggleVibrate() {
    vibrate = !vibrate;
    save();
  }

  Dhikr addCustom(String name, int target) {
    final z = Dhikr('c${_now().microsecondsSinceEpoch}', name.trim(), '', '', target, custom: true);
    custom.add(z);
    if (tesbihat != null) stopTesbihat();
    selected = z.id;
    save();
    return z;
  }

  void removeCustom(String id) {
    custom.removeWhere((z) => z.id == id);
    counts.remove(id);
    targets.remove(id);
    if (selected == id) selected = 'subhan';
    save();
  }

  // ------------------------------------------------------------------ tesbihat

  void startTesbihat() {
    _beforeTesbihat = selected;
    tesbihat = 0;
    for (final id in kTesbihatSeq) {
      counter(id)
        ..n = 0
        ..rounds = 0;
    }
    selected = kTesbihatSeq.first;
    save();
  }

  void _nextStep() {
    final s = tesbihat! + 1;
    tesbihat = s;
    if (s < 3) {
      selected = kTesbihatSeq[s];
      counter(selected).n = 0;
    }
  }

  void stopTesbihat() {
    tesbihat = null;
    if (_beforeTesbihat != null) selected = _beforeTesbihat!;
    _beforeTesbihat = null;
    save();
  }

  // ------------------------------------------------------------------ kayıt

  static Future<DhikrState> load({DateTime Function()? now}) async {
    final s = DhikrState(now: now);
    s._p = await SharedPreferences.getInstance();
    final raw = s._p!.getString(_key);
    if (raw != null) {
      try {
        s._fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Bozuk kayıt: baştan başla.
      }
    }
    s._rollDay();
    return s;
  }

  void _fromJson(Map<String, dynamic> j) {
    for (final c in (j['custom'] as List? ?? const [])) {
      custom.add(Dhikr.fromJson((c as Map).cast<String, dynamic>()));
    }
    selected = j['sel'] as String? ?? 'subhan';
    if (!all.any((z) => z.id == selected)) selected = 'subhan';
    (j['c'] as Map? ?? const {}).forEach((k, v) {
      final l = (v as List).cast<num>();
      counts[k as String] = DhikrCounter(l[0].toInt(), l[1].toInt());
    });
    (j['tg'] as Map? ?? const {}).forEach((k, v) => targets[k as String] = (v as num).toInt());
    vibrate = j['vib'] as bool? ?? true;
    day = j['day'] as String? ?? '';
    (j['dn'] as Map? ?? const {}).forEach((k, v) => today[k as String] = (v as num).toInt());
    (j['h'] as Map? ?? const {}).forEach((k, v) => history[k as String] = (v as num).toInt());
  }

  Map<String, dynamic> toJson() => {
        'sel': selected,
        'c': {
          for (final e in counts.entries) e.key: [e.value.n, e.value.rounds]
        },
        'tg': targets,
        'custom': [for (final z in custom) z.toJson()],
        'vib': vibrate,
        'day': day,
        'dn': today,
        'h': _recentHistory(),
      };

  Map<String, int> _recentHistory() {
    final limit = _now().subtract(const Duration(days: 120));
    return {
      for (final e in history.entries)
        if (() {
          final p = e.key.split('-').map(int.tryParse).toList();
          return p.length == 3 && p.every((x) => x != null) && DateTime(p[0]!, p[1]!, p[2]!).isAfter(limit);
        }())
          e.key: e.value,
    };
  }

  void save() {
    _p?.setString(_key, jsonEncode(toJson()));
    HomeWidgets.refresh(); // ana ekrandaki zikir widget'ı aynı sayıyı gösterir
  }
}
