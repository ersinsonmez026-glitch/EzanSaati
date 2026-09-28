import 'dart:async';

import 'package:flutter/material.dart';

import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../services/takvim.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'city_picker_screen.dart';
import '../widgets/gold_icon.dart';

enum _View { main, imsakiye, hicri, miladi }

/// Namaz Vakitleri (onizleme/02-namaz-vakitleri.html): şimdiki vakit ve kalan süre, gün gün
/// vakitler, İmsakiye, Hicrî ve Miladi takvim.
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  final _pal = PagePalette.current();
  final _location = LocationStore.instance;
  final _scroll = ScrollController();
  Timer? _ticker;
  TakvimData? _takvim;

  _View _view = _View.main;
  int _offset = 0; // gösterilen gün: bugünden kaç gün ileri/geri
  DateTime _hAnchor = hijriMonthStart(DateTime.now()); // hicrî takvimde gösterilen ayın ilk günü
  DateTime _mAnchor = DateTime(DateTime.now().year, DateTime.now().month); // miladi takvimde gösterilen ay

  /// İmsakiyede gösterilen gün sayısı: bugün + sonraki 6 gün.
  static const imsakiyeDays = 7;

  // İmsakiye her saniye yeniden hesaplanmasın.
  String? _tableKey;
  List<DayPrayerTimes> _table = const [];

  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  @override
  void initState() {
    super.initState();
    _location.addListener(_refresh);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    TakvimData.load().then((t) {
      if (mounted) setState(() => _takvim = t);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _location.removeListener(_refresh);
    _scroll.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _go(_View v) {
    final now = DateTime.now();
    setState(() {
      _view = v;
      _hAnchor = hijriMonthStart(now);
      _mAnchor = DateTime(now.year, now.month);
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _changeCity() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CityPickerScreen()));
  }

  String get _title => switch (_view) {
        _View.main => 'Namaz Vakitleri',
        _View.imsakiye => 'İmsakiye',
        _View.hicri => 'Hicri Takvim',
        _View.miladi => 'Miladi Takvim',
      };

  @override
  Widget build(BuildContext context) {
    final loc = _location.current;
    const gap = SizedBox(height: 10);
    final List<Widget> children;
    if (loc == null) {
      children = [_noLocation()];
    } else {
      children = switch (_view) {
        _View.main => _main(loc, gap),
        _View.imsakiye => _imsakiye(loc, gap),
        _View.hicri => _hicri(gap),
        _View.miladi => _miladi(gap),
      };
    }
    // Alt sayfalarda geri tuşu önce Namaz Vakitleri'ne döner.
    return PopScope(
      canPop: _view == _View.main,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_View.main);
      },
      child: PageShell(
        title: _title,
        background: _pal.background,
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: children,
      ),
    );
  }

  Widget _noLocation() {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: PaperBox(
        pal: _pal,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GoldIcon(Icons.location_off, size: 44, light: !_pal.night),
            const SizedBox(height: 10),
            Text(
              'Vakitleri gösterebilmek için önce şehrinizi seçin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _pal.ink, fontSize: 15),
            ),
            const SizedBox(height: 14),
            DarkButton(label: 'Şehir Seç', onTap: _changeCity),
          ],
        ),
      ),
    );
  }

  // ================================================================= ana görünüm

  List<Widget> _main(AppLocation loc, Widget gap) {
    final now = DateTime.now();
    final status = PrayerCalc.status(loc, now);
    final shown = DateTime(now.year, now.month, now.day + _offset);
    final day = _offset == 0 ? status.today : PrayerCalc.forDay(loc, shown);
    final ci = PrayerCalc.names.indexOf(status.current.name);
    final beforeImsak = now.isBefore(status.today.slots.first.time);
    final total = status.next.time.difference(status.current.time).inSeconds;
    final done = now.difference(status.current.time).inSeconds;

    return [
      _hero(
        image: 'assets/images/vakit_kapak.jpg',
        imageAlign: const Alignment(-0.6, 0.2),
        label: 'Şimdi',
        trailing: _cityChip(loc),
        children: [
          Text(status.current.name,
              style: const TextStyle(color: Colors.white, fontSize: 34, height: 1.05, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('${status.next.name} vaktine kalan süre',
              style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12.5)),
          Text(
            formatDuration(status.remaining),
            style: const TextStyle(
              color: RC.goldText,
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: 0.62,
            child: _progress(total <= 0 ? 0 : done / total),
          ),
        ],
      ),
      gap,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child:
                  Text('${formatDateTr(shown)}, ${weekdayTr(shown)}', style: TextStyle(color: _pal.ink2, fontSize: 12)),
            ),
            Text('${HijriDate.of(shown)}',
                style: TextStyle(color: _pal.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      gap,
      _dayButtons(shown),
      gap,
      for (var i = 0; i < 6; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: _row(i, day.slots[i], now, ci, beforeImsak, status),
        ),
      const SizedBox(height: 3),
      Row(
        children: [
          Expanded(
            child: _link(Icons.notifications_active, 'Bildirimler', 'Ezan ayarları',
                () => showNote(context, 'Ezan bildirimleri bir sonraki adımda eklenecek.')),
          ),
          const SizedBox(width: 8),
          Expanded(child: _link(Icons.nightlight_round, 'Hicri Takvim', 'Dini günler', () => _go(_View.hicri))),
          const SizedBox(width: 8),
          Expanded(child: _link(Icons.calendar_month, 'Miladi Takvim', 'Resmî tatiller', () => _go(_View.miladi))),
        ],
      ),
      gap,
      OrnamentStar(color: _pal.gold, lineWidth: 70),
      gap,
      _verse(
        arabic: 'إِنَّ ٱلصَّلَوٰةَ كَانَتْ عَلَى ٱلْمُؤْمِنِينَ كِتَٰبًا مَّوْقُوتًا',
        meal: 'Namaz şüphesiz iman edenlere belirli vakitlerde farz kılınmıştır.',
        ref: 'Nisâ Sûresi, 103',
      ),
      gap,
      SourceNote(
        pal: _pal,
        text: 'Vakitler Diyanet İşleri Başkanlığı\'nın hesaplama yöntemiyle, internet bağlantısı gerektirmeden '
            'hesaplanır; resmî takvimle 1-2 dakikalık fark olabilir. Meal: Ruvvâd Tercüme Merkezi (QuranEnc.com).',
      ),
    ];
  }

  Widget _cityChip(AppLocation loc) {
    return Semantics(
      button: true,
      label: 'Şehir: ${loc.name}. Değiştir',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _changeCity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x59000000),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: RC.gold(0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GoldIcon(Icons.place, size: 12),
              const SizedBox(width: 3),
              Flexible(
                child: Text('${loc.name} ›',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress(double v) {
    return Container(
      height: 7,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: RC.gold(0.5)),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: v.clamp(0.0, 1.0),
        child: const DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFC29A2C), Color(0xFFF3DC97)])),
        ),
      ),
    );
  }

  Widget _dayButtons(DateTime shown) {
    final label = switch (_offset) {
      0 => 'Bugün',
      -1 => 'Dün',
      1 => 'Yarın',
      _ => '${shown.day} ${_months[shown.month - 1].substring(0, 3)}',
    };
    Widget btn(Widget child, VoidCallback onTap, {bool on = false, String? semantic}) => Semantics(
          button: true,
          label: semantic,
          selected: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? null : _pal.chip,
                gradient: on ? RC.bronze : null,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: on ? RC.bronzeBorder : _pal.line),
                boxShadow: on ? RC.bronzeGlow : null,
              ),
              child: child,
            ),
          ),
        );
    final ink = TextStyle(color: _pal.ink, fontSize: 12.5, fontWeight: FontWeight.w600);
    return Row(
      children: [
        SizedBox(
          width: 38,
          child: btn(Icon(Icons.chevron_left, size: 18, color: _pal.ink), () => setState(() => _offset--),
              semantic: 'Önceki gün'),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 10,
          child: btn(
            Text(label, style: _offset == 0 ? ink.copyWith(color: RC.bronzeText) : ink),
            () => setState(() => _offset = 0),
            on: _offset == 0,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: btn(Icon(Icons.chevron_right, size: 18, color: _pal.ink), () => setState(() => _offset++),
              semantic: 'Sonraki gün'),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 11,
          child: btn(
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_view_month, size: 15, color: _pal.ink),
              const SizedBox(width: 5),
              Text('İmsakiye', style: ink),
            ]),
            () => _go(_View.imsakiye),
          ),
        ),
      ],
    );
  }

  static const _icons = [
    Icons.wb_twilight, // İmsak: ufuktan doğan ışık
    Icons.wb_sunny, // Güneş
    Icons.mosque, // Öğle
    Icons.wb_cloudy, // İkindi
    Icons.wb_twilight, // Akşam: batan güneş
    Icons.nightlight_round, // Yatsı: hilal
  ];

  Widget _row(int i, PrayerSlot slot, DateTime now, int ci, bool beforeImsak, PrayerStatus st) {
    final cur = _offset == 0 && i == ci && !(i == 5 && beforeImsak);
    final past = _offset < 0 || (_offset == 0 && !slot.time.isAfter(now) && !cur);
    const curInk = Color(0xFF231805);
    Widget? pill;
    if (cur) {
      pill = Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.hourglass_bottom, size: 16, color: curInk),
        const SizedBox(width: 3),
        Text(formatDuration(st.remaining)),
      ]);
    } else if (past) {
      pill = Icon(Icons.check_circle, size: 18, color: _pal.night ? const Color(0xFF4FE0A6) : const Color(0xFF1D8A5C));
    } else if (_offset == 0) {
      pill = Text(formatDuration(slot.time.difference(now)));
    }
    return Semantics(
      label: '${slot.name} ${formatHm(slot.time)}${cur ? ', şimdiki vakit' : ''}',
      excludeSemantics: true,
      child: Container(
        height: 46,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: cur ? const LinearGradient(colors: [Color(0xFFF2D27A), Color(0xFFD9AE45)]) : _pal.paperGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cur ? const Color(0xB3A06E14) : _pal.line),
          boxShadow: [
            cur
                ? const BoxShadow(color: Color(0x4D78500A), blurRadius: 10, offset: Offset(0, 3))
                : const BoxShadow(color: Color(0x1F3C280A), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: cur
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFE0B84E), Color(0xFFB68A25)])
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0B3F2B), Color(0xFF062A1C)]),
                border: Border(right: BorderSide(color: RC.gold(0.5))),
              ),
              child: cur
                  ? Icon(_icons[i], size: 24, color: const Color(0xFF1D1406))
                  : GoldIcon(_icons[i], size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Opacity(
                opacity: past ? 0.55 : 1,
                child: Text(slot.name,
                    style: TextStyle(color: cur ? curInk : _pal.ink, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            Opacity(
              opacity: past ? 0.55 : 1,
              child: SizedBox(
                width: 56,
                child: Text(
                  formatHm(slot.time),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cur ? curInk : _pal.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 92),
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              margin: const EdgeInsets.only(right: 8),
              alignment: Alignment.center,
              decoration: pill == null
                  ? null
                  : BoxDecoration(
                      color: cur ? const Color(0x8CFFF8E1) : _pal.pill,
                      borderRadius: BorderRadius.circular(99),
                      border: cur ? Border.all(color: const Color(0x595A3C0A)) : null,
                    ),
              child: pill == null
                  ? null
                  : DefaultTextStyle.merge(
                      style: TextStyle(
                        color: cur ? curInk : _pal.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      child: pill,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _link(IconData icon, String title, String sub, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
          decoration: BoxDecoration(
            gradient: RC.darkPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RC.gold(0.7), width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x33000000),
                  border: Border.all(color: RC.goldBorder, width: 1.5),
                ),
                child: GoldIcon(icon, size: 21),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(title,
                    maxLines: 1, style: const TextStyle(color: RC.cream, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(sub, maxLines: 1, style: const TextStyle(color: RC.creamSoft, fontSize: 10.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _verse({required String arabic, required String meal, required String ref}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: _pal.paperGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pal.line),
      ),
      child: Column(
        children: [
          Text(arabic,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: kQuranFont, fontSize: 22, height: 1.9, color: _pal.gold)),
          const SizedBox(height: 4),
          Text('“$meal”',
              textAlign: TextAlign.center,
              style: TextStyle(color: _pal.ink, fontSize: 14, height: 1.5, fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          Text(ref, style: TextStyle(color: _pal.ink2, fontSize: 11.5)),
        ],
      ),
    );
  }

  /// Üstteki fotoğraflı koyu kart (önizlemedeki "show").
  Widget _hero({
    required String image,
    required Alignment imageAlign,
    required List<Widget> children,
    String? label,
    Widget? trailing,
    Widget? leading,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF062A1C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.gold(0.75), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x40281905), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: 0.7,
              child: Image.asset(image, fit: BoxFit.cover, alignment: imageAlign),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF062A1C), Color(0xD9062A1C), Color(0x26062A1C), Color(0x0D062A1C)],
                  stops: [0.3, 0.45, 0.75, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) leading,
                if (label != null || trailing != null)
                  Row(
                    children: [
                      if (label != null) ...[
                        const GoldIcon(Icons.brightness_2, size: 13),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: RC.goldText, fontSize: 12)),
                        ),
                      ],
                      if (label == null) const Spacer(),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 170), child: trailing),
                      ],
                    ],
                  ),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================= imsakiye

  List<DayPrayerTimes> _days(AppLocation loc, DateTime start) {
    final key = '${loc.lat},${loc.lng},${start.year}-${start.month}-${start.day}';
    if (key != _tableKey) {
      _tableKey = key;
      _table = [
        // Saat değişimi olan günlerde kaymasın diye takvim günüyle ilerle.
        for (var i = 0; i < imsakiyeDays; i++) PrayerCalc.forDay(loc, DateTime(start.year, start.month, start.day + i)),
      ];
    }
    return _table;
  }

  List<Widget> _imsakiye(AppLocation loc, Widget gap) {
    final now = DateTime.now();
    final days = _days(loc, DateTime(now.year, now.month, now.day));
    const head = TextStyle(color: RC.goldText, fontSize: 11.5, fontWeight: FontWeight.w700);
    Widget cell(String t, TextStyle s, {int flex = 2}) =>
        Expanded(flex: flex, child: Text(t, textAlign: TextAlign.center, style: s));
    return [
      _hero(
        image: 'assets/images/vakit_kapak.jpg',
        imageAlign: const Alignment(-0.6, 0.2),
        label: 'Bugün ve sonraki 6 gün',
        trailing: _cityChip(loc),
        children: [
          const Text('İmsakiye',
              style: TextStyle(color: Colors.white, fontSize: 30, height: 1.1, fontWeight: FontWeight.w800)),
          Text('${formatDateTr(days.first.date)} – ${formatDateTr(days.last.date)}',
              style: const TextStyle(color: RC.goldText, fontSize: 13)),
        ],
      ),
      gap,
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: _pal.paperGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _pal.line),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                gradient: RC.darkPanel,
                border: Border(bottom: BorderSide(color: RC.gold(0.6), width: 1.5)),
              ),
              child: Row(children: [
                cell('Tarih', head, flex: 3),
                for (final n in PrayerCalc.names) cell(n, head),
              ]),
            ),
            for (var i = 0; i < days.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  gradient: i == 0 ? RC.bronze : null,
                  border: i == 0 ? null : Border(top: BorderSide(color: _pal.line)),
                ),
                child: Row(children: [
                  cell(
                    formatShortDateTr(days[i].date),
                    TextStyle(color: i == 0 ? RC.bronzeText : _pal.gold, fontSize: 12, fontWeight: FontWeight.w700),
                    flex: 3,
                  ),
                  for (final s in days[i].slots)
                    cell(
                      formatHm(s.time),
                      TextStyle(
                        color: i == 0 ? RC.bronzeText : _pal.ink,
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ]),
              ),
          ],
        ),
      ),
      gap,
      SourceNote(
        pal: _pal,
        text: 'Vakitler Diyanet İşleri Başkanlığı\'nın hesaplama yöntemiyle seçili şehre göre hesaplanır; resmî '
            'takvimle 1-2 dakikalık fark olabilir.',
      ),
    ];
  }

  // ================================================================= hicri takvim

  List<Widget> _hicri(Widget gap) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final h = HijriDate.of(today);
    final start = _hAnchor, len = hijriMonthLength(start), mh = HijriDate.of(start);
    final end = DateTime(start.year, start.month, start.day + len - 1);
    final t = _takvim;
    final evDates = t?.religiousDates ?? const <DateTime>{};
    final lead = (start.weekday + 6) % 7;
    final tail = (7 - (lead + len) % 7) % 7;
    final cells = <Widget>[
      for (var i = -lead; i < len + tail; i++)
        () {
          final d = DateTime(start.year, start.month, start.day + i);
          return _dayCell(
            big: '${HijriDate.of(d).day}',
            small: '${d.day} ${_months[d.month - 1].substring(0, 3)}',
            out: i < 0 || i >= len,
            today: d == today,
            event: evDates.contains(d),
            friday: d.weekday == DateTime.friday,
          );
        }(),
    ];
    final upcoming = t?.upcomingReligious(today) ?? const <ReligiousDay>[];

    return [
      _hero(
        image: 'assets/images/okuma_kapak.jpg',
        imageAlign: const Alignment(-0.2, 0),
        label: 'Bugünün Tarihi',
        children: [
          Text('$h',
              style: const TextStyle(color: RC.goldText, fontSize: 28, height: 1.1, fontWeight: FontWeight.w800)),
          Text('${formatDateTr(today)} ${weekdayTr(today)}', style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: 0.64,
            child: Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: RC.gold(0.45)))),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('“Biz her şeyi bir kaderle yarattık.”',
                      style: TextStyle(color: Colors.white, fontSize: 12, height: 1.45, fontStyle: FontStyle.italic)),
                  SizedBox(height: 2),
                  Text('Kamer Sûresi, 49', style: TextStyle(color: RC.goldText, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
      gap,
      _calendar(
        title: '${mh.monthName} ${mh.year}',
        sub: '${start.day} ${_months[start.month - 1].substring(0, 3)} – '
            '${end.day} ${_months[end.month - 1].substring(0, 3)} ${end.year}',
        onPrev: () => setState(() => _hAnchor = hijriMonthStart(start.subtract(const Duration(days: 2)))),
        onNext: () => setState(() => _hAnchor = hijriMonthStart(start.add(const Duration(days: 32)))),
        cells: cells,
      ),
      gap,
      _group(
        Icons.nightlight_round,
        'Önemli Dinî Günler',
        [
          for (var i = 0; i < upcoming.length; i++)
            _event(
              icon: _eventIcon(upcoming[i].icon),
              title: upcoming[i].name,
              sub: '${formatDateTr(upcoming[i].date)}, ${weekdayTr(upcoming[i].date)} · ${upcoming[i].hijri}',
              left: _left(upcoming[i].date, today),
              highlight: i == 0,
            ),
        ],
      ),
      gap,
      SourceNote(
        pal: _pal,
        text: 'Dinî gün tarihleri Diyanet İşleri Başkanlığı takviminden alınmıştır. Kandiller, belirtilen günün '
            'akşamı idrak edilir. Takvimdeki hicrî günler hesapla bulunur; Diyanet takviminden bir gün farklı '
            'olabilir. Meal: Ruvvâd Tercüme Merkezi (QuranEnc.com).',
      ),
    ];
  }

  IconData _eventIcon(String k) => switch (k) {
        'moon' => Icons.nightlight_round,
        'lamp' => Icons.light_outlined,
        'star' => Icons.star_outline,
        _ => Icons.mosque_outlined,
      };

  String _left(DateTime d, DateTime today) {
    final n = DateTime(d.year, d.month, d.day).difference(today).inDays;
    return n < 0 ? 'Geçti' : (n == 0 ? 'Bugün' : '$n gün');
  }

  // ================================================================= miladi takvim

  List<Widget> _miladi(Widget gap) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hp = HijriDate.of(today);
    final y = _mAnchor.year, m = _mAnchor.month;
    final first = DateTime(y, m), n = DateTime(y, m + 1, 0).day;
    final h1 = HijriDate.of(first), h2 = HijriDate.of(DateTime(y, m, n));
    final t = _takvim;
    final lead = (first.weekday + 6) % 7;
    final count = ((lead + n) / 7).ceil() * 7;
    final cells = <Widget>[
      for (var i = 0; i < count; i++)
        () {
          final d = DateTime(y, m, 1 - lead + i);
          final ev = t?.on(d) ?? const <CalendarDay>[];
          final q = HijriDate.of(d);
          return _dayCell(
            big: '${d.day}',
            small: q.day == 1 ? '1 ${q.monthName.substring(0, 4)}.' : '${q.day}',
            out: d.month != m,
            today: d == today,
            event: ev.any((e) => e.religious),
            holiday: ev.any((e) => e.holiday),
            half: !ev.any((e) => e.holiday) && ev.any((e) => e.half),
          );
        }(),
    ];

    var list = [
      for (final e in t?.days ?? const <CalendarDay>[])
        if (e.date.year == y && e.date.month == m) e,
    ];
    var title = 'Bu Ayın Önemli Günleri';
    if (list.isEmpty) {
      list = [
        for (final e in t?.days ?? const <CalendarDay>[])
          if (!e.date.isBefore(today)) e,
      ].take(5).toList();
      title = 'Yaklaşan Önemli Günler';
    }

    return [
      _hero(
        image: 'assets/images/vakit_kapak.jpg',
        imageAlign: const Alignment(-0.6, 0.2),
        label: 'Bugünün Tarihi',
        children: [
          Text(formatDateTr(today),
              style: const TextStyle(color: RC.goldText, fontSize: 28, height: 1.1, fontWeight: FontWeight.w800)),
          Text('${weekdayTr(today)} · $hp', style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
      gap,
      _calendar(
        title: '${_months[m - 1]} $y',
        sub: h1.month == h2.month ? '${h1.monthName} ${h1.year}' : '${h1.monthName} – ${h2.monthName} ${h2.year}',
        onPrev: () => setState(() => _mAnchor = DateTime(y, m - 1)),
        onNext: () => setState(() => _mAnchor = DateTime(y, m + 1)),
        cells: cells,
        legend: true,
      ),
      gap,
      _group(Icons.calendar_month, title, [
        for (final e in list)
          _event(
            icon: e.religious ? Icons.light_outlined : Icons.event,
            title: e.name.replaceAll(' (yarım gün)', ''),
            sub: '${e.date.day} ${_months[e.date.month - 1]}, ${weekdayTr(e.date)}',
            tag: e.holiday ? 'Resmî tatil' : (e.half ? 'Yarım gün' : 'Dinî gün'),
            tagRed: !e.religious,
            left: _left(e.date, today),
          ),
      ]),
      gap,
      SourceNote(
        pal: _pal,
        text: 'Resmî tatiller 2429 sayılı kanuna göredir. Dinî bayram ve kandil tarihleri Diyanet İşleri '
            'Başkanlığı takviminden alınmıştır.',
      ),
    ];
  }

  // ================================================================= ortak takvim parçaları

  Widget _calendar({
    required String title,
    required String sub,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required List<Widget> cells,
    bool legend = false,
  }) {
    Widget arrow(IconData icon, String label, VoidCallback onTap) => Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: RC.goldBorder, width: 1.5)),
              child: GoldIcon(icon, size: 18),
            ),
          ),
        );
    const wd = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cts', 'Paz'];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: _pal.paperGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pal.line),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: RC.darkPanel,
              border: Border(bottom: BorderSide(color: RC.gold(0.6), width: 1.5)),
            ),
            child: Row(
              children: [
                arrow(Icons.chevron_left, 'Önceki ay', onPrev),
                Expanded(
                  child: Column(
                    children: [
                      Text(title, style: const TextStyle(color: RC.cream, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(sub, style: const TextStyle(color: RC.goldIcon, fontSize: 11.5)),
                    ],
                  ),
                ),
                arrow(Icons.chevron_right, 'Sonraki ay', onNext),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: GridView.count(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.9,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final w in wd)
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _pal.pill, borderRadius: BorderRadius.circular(8)),
                    child: Text(w, style: TextStyle(color: _pal.ink, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ...cells,
              ],
            ),
          ),
          if (legend)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _legend(const Color(0x59C0392B), 'Resmî tatil'),
                  _legend(const Color(0xFFC9A133), 'Dinî gün', circle: true),
                  _legend(const Color(0xFF0F5A3C), 'Bugün'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label, {bool circle = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: c,
              shape: circle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circle ? null : BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: _pal.ink2, fontSize: 11)),
        ],
      );

  Widget _dayCell({
    required String big,
    required String small,
    bool out = false,
    bool today = false,
    bool event = false,
    bool friday = false,
    bool holiday = false,
    bool half = false,
  }) {
    const red = Color(0xFFB0392B), redNight = Color(0xFFFF8F7F);
    Color bigColor = _pal.ink;
    if (holiday) bigColor = _pal.night ? redNight : red;
    if (friday) bigColor = _pal.night ? const Color(0xFF4FE0A6) : const Color(0xFF1D8A5C);
    if (today) bigColor = RC.goldText;
    return Opacity(
      opacity: out ? 0.35 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: today
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F5A3C), Color(0xFF083826)])
              : (half
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x1FC0392B), Color(0x1FC0392B), Colors.transparent, Colors.transparent],
                      stops: [0, 0.5, 0.5, 1])
                  : null),
          color: today || half
              ? null
              : (holiday ? const Color(0x1AC0392B) : (_pal.night ? const Color(0x08FFFFFF) : const Color(0x2EFFFFFF))),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: today ? RC.goldBorder : (holiday ? const Color(0x73C0392B) : _pal.line),
            width: today ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(big, style: TextStyle(color: bigColor, fontSize: 16, height: 1.1, fontWeight: FontWeight.w700)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child:
                        Text(small, maxLines: 1, style: TextStyle(color: today ? RC.cream : _pal.ink2, fontSize: 9.5)),
                  ),
                ],
              ),
            ),
            if (event)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Color(0xFFC9A133), shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _group(IconData icon, String title, List<Widget> items) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: _pal.paperGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pal.line),
        boxShadow: const [BoxShadow(color: Color(0x1F3C280A), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: RC.darkPanel,
              border: Border(bottom: BorderSide(color: RC.gold(0.6), width: 1.5)),
            ),
            child: Row(
              children: [
                GoldIcon(icon, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      Text(title, style: const TextStyle(color: RC.cream, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          ...withDividers(items, _pal.line),
        ],
      ),
    );
  }

  Widget _event({
    required IconData icon,
    required String title,
    required String sub,
    required String left,
    String? tag,
    bool tagRed = false,
    bool highlight = false,
  }) {
    return Container(
      color: highlight ? RC.gold(0.14) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: _pal.pill, borderRadius: BorderRadius.circular(10)),
            child: GoldIcon(icon, size: 19, light: !_pal.night),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: _pal.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: sub),
                    if (tag != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                            color: tagRed ? const Color(0x26C0392B) : RC.gold(0.2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color:
                                  tagRed ? (_pal.night ? const Color(0xFFFF8F7F) : const Color(0xFFB0392B)) : _pal.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ]),
                  style: TextStyle(color: _pal.ink2, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(left, style: TextStyle(color: _pal.gold, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
