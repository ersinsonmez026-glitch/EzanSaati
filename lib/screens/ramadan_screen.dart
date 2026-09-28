import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'city_picker_screen.dart';

/// Ramazan: geri sayım, şehre göre imsakiye, oruç niyeti ve dualar, önemli günler.
/// Tasarım: onizleme/11-ramazan.html · Veri: assets/data/ramazan.json
class RamadanScreen extends StatefulWidget {
  const RamadanScreen({super.key});

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

enum _Tab { imsakiye, dua, gunler }

class _RamadanScreenState extends State<RamadanScreen> {
  final _pal = PagePalette.current();
  final _location = LocationStore.instance;
  RamazanData? _data;
  _Tab _tab = _Tab.imsakiye;
  Timer? _ticker;

  // İmsakiye her saniye yeniden hesaplanmasın.
  String? _tableKey;
  List<DayPrayerTimes> _table = const [];

  @override
  void initState() {
    super.initState();
    _location.addListener(_refresh);
    RamazanData.load().then((d) {
      if (mounted) setState(() => _data = d);
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _location.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<DayPrayerTimes> _imsakiye(RamazanData d, AppLocation loc) {
    final key = '${loc.lat},${loc.lng},${d.start}';
    if (key != _tableKey) {
      _tableKey = key;
      _table = [for (var i = 1; i <= d.days; i++) PrayerCalc.forDay(loc, d.dateOf(i))];
    }
    return _table;
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return PageShell(
      title: 'Ramazan',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: d == null
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : _content(d),
    );
  }

  List<Widget> _content(RamazanData d) {
    const gap = SizedBox(height: 10);
    return [
      _panel(d),
      gap,
      _tabs(),
      gap,
      switch (_tab) {
        _Tab.imsakiye => _imsakiyeView(d),
        _Tab.dua => _duaView(d),
        _Tab.gunler => _daysView(d),
      },
      gap,
      SourceNote(
        pal: _pal,
        text: 'İmsakiye seçili şehre göre Diyanet yöntemiyle hesaplanır. Tarihler Diyanet İşleri Başkanlığı '
            '${d.year} dini günler takvimine göredir.',
      ),
    ];
  }

  // ---------------------------------------------------------------- geri sayım paneli

  Widget _panel(RamazanData d) {
    final now = DateTime.now();
    final loc = _location.current;
    final today = loc == null ? null : PrayerCalc.forDay(loc, now);
    final k = d.dayNumber(now);

    String label, big, sub, chip;
    double progress;
    if (k < 1) {
      final left = 1 - k;
      label = 'On bir ayın sultanına';
      big = '$left gün';
      sub = 'kaldı';
      chip = "Ramazan ${d.start.day} ${_monthTr(d.start.month)} ${d.start.year}'de başlıyor";
      progress = math.max(2, 100 - left / 2) / 100;
    } else if (k <= d.days) {
      if (today == null) {
        label = "Ramazan'ın $k. günü";
        big = '--:--:--';
      } else {
        final sahur = today.slots[0].time, iftar = today.slots[4].time;
        DateTime target;
        if (now.isBefore(sahur)) {
          target = sahur;
          label = 'Sahura (imsaka) kalan';
        } else if (now.isBefore(iftar)) {
          target = iftar;
          label = 'İftara kalan';
        } else {
          target = PrayerCalc.forDay(loc!, now.add(const Duration(days: 1))).slots[0].time;
          label = 'Sahura (imsaka) kalan';
        }
        big = formatDuration(target.difference(now));
      }
      sub = "Ramazan'ın $k. günü";
      final isKadir = DateTime(now.year, now.month, now.day) == d.kadir;
      chip = isKadir ? 'Bu gece Kadir Gecesi' : 'Hayırlı Ramazanlar';
      progress = k / d.days;
    } else {
      label = 'Ramazan tamamlandı';
      big = 'Bayram';
      sub = 'Ramazan Bayramınız mübarek olsun';
      chip = d.bayramLabel;
      progress = 1;
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.goldBorder, width: 1.5),
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.3,
          colors: [Color(0xFF0A3323), Color(0xFF021A11), Color(0xFF000C07)],
          stops: [0, 0.5, 1],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x59000000), spreadRadius: 3),
          BoxShadow(color: Color(0x73D4AF37), spreadRadius: 4.5),
          BoxShadow(color: Color(0x73000000), blurRadius: 22, offset: Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(left: 3, top: 3, child: _CornerOrnament()),
          const Positioned(right: 3, top: 3, child: _CornerOrnament(flip: true)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                child: Column(
                  children: [
                    const _HeroOrnament(),
                    const SizedBox(height: 4),
                    Text(label, style: const TextStyle(color: Color(0xFFC9D8CF), fontSize: 12.5)),
                    const SizedBox(height: 2),
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFF1C4), Color(0xFFE6C35A), Color(0xFFB78A26)],
                        stops: [0, 0.55, 1],
                      ).createShader(r),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          big,
                          style: const TextStyle(
                            fontSize: 48,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    Text(sub,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFF3D27A), fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x4D000000),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0x80E2C26E)),
                      ),
                      child: Text(chip,
                          style: const TextStyle(color: Color(0xFFE7DDC4), fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Container(
                height: 10,
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0x1FFFFFFF),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0x66E2C26E)),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFC9922E), Color(0xFFF9C265), Color(0xFFFFE3A0)],
                        stops: [0, 0.6, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0x4D000000),
                  border: Border(top: BorderSide(color: Color(0x4DD4AF37))),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _timeCell(Icons.nightlight_round, 'Sahur (İmsak)',
                            today == null ? '--:--' : formatHm(today.slots[0].time)),
                      ),
                      Container(width: 1, color: const Color(0x40D4AF37)),
                      Expanded(
                        child: _timeCell(Icons.wb_twilight, 'İftar (Akşam)',
                            today == null ? '--:--' : formatHm(today.slots[4].time)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeCell(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Column(
        children: [
          Icon(icon, size: 22, color: const Color(0xFFE9C96A)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: RC.creamSoft, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                color: RC.cream,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- sekmeler

  Widget _tabs() {
    Widget tab(_Tab t, IconData icon, String label) {
      final on = _tab == t;
      final fg = on ? RC.bronzeText : RC.cream;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _tab = t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              decoration: BoxDecoration(
                gradient: on ? RC.bronze : RC.darkPanel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: on ? RC.bronzeBorder : RC.gold(0.7)),
                boxShadow: on
                    ? RC.bronzeGlow
                    : const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Column(
                children: [
                  Icon(icon, size: 24, color: on ? RC.bronzeText : const Color(0xFFE9C96A)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(_Tab.imsakiye, Icons.calendar_month, 'İmsakiye'),
        const SizedBox(width: 8),
        tab(_Tab.dua, Icons.back_hand_outlined, 'Niyet ve Dua'),
        const SizedBox(width: 8),
        tab(_Tab.gunler, Icons.star, 'Önemli Günler'),
      ],
    );
  }

  // ---------------------------------------------------------------- imsakiye

  Widget _imsakiyeView(RamazanData d) {
    final loc = _location.current;
    if (loc == null) {
      return PaperBox(
        pal: _pal,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('İmsakiyeyi gösterebilmek için önce şehrinizi seçin.',
                textAlign: TextAlign.center, style: TextStyle(color: _pal.ink, fontSize: 14)),
            const SizedBox(height: 12),
            DarkButton(
              label: 'Şehir Seç',
              height: 40,
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CityPickerScreen())),
            ),
          ],
        ),
      );
    }

    final days = _imsakiye(d, loc);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const headStyle = TextStyle(color: RC.goldText, fontSize: 12, fontWeight: FontWeight.w700);

    Widget row({required Widget n, required Widget date, required Widget a, required Widget b}) => Row(
          children: [
            SizedBox(width: 40, child: n),
            Expanded(child: date),
            SizedBox(width: 62, child: Center(child: a)),
            SizedBox(width: 62, child: Center(child: b)),
          ],
        );

    final rows = <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A3525), Color(0xFF01170F)],
          ),
        ),
        child: row(
          n: const Text('Gün', style: headStyle),
          date: const Text('Tarih', style: headStyle),
          a: const Text('Sahur', style: headStyle),
          b: const Text('İftar', style: headStyle),
        ),
      ),
    ];
    for (var i = 0; i < days.length; i++) {
      final t = days[i];
      final date = t.date;
      final isToday = date == today;
      final isPast = date.isBefore(today);
      final isKadir = date == d.kadir;
      final ink = isToday ? RC.bronzeText : _pal.ink;
      final small = isToday ? RC.bronzeText : (isKadir ? const Color(0xFFC9922E) : _pal.ink2);
      final timeStyle = TextStyle(
        color: ink,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      rows.add(Opacity(
        opacity: isPast ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: isToday ? RC.bronze : _pal.paperGradient,
            border: Border(top: BorderSide(color: _pal.line)),
          ),
          child: row(
            n: Text('${i + 1}',
                style: TextStyle(color: isToday ? RC.bronzeText : _pal.gold, fontWeight: FontWeight.w700)),
            date: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${date.day} ${_monthTr(date.month)}', style: TextStyle(color: ink, fontSize: 13.5)),
                Text(isKadir ? 'Kadir Gecesi' : weekdayTr(date),
                    style: TextStyle(
                        color: small, fontSize: 10.5, fontWeight: isKadir ? FontWeight.w700 : FontWeight.normal)),
              ],
            ),
            a: Text(formatHm(t.slots[0].time), style: timeStyle),
            b: Text(formatHm(t.slots[4].time), style: timeStyle),
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('İmsakiye', style: TextStyle(color: _pal.ink, fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              Text('${loc.name} · ${d.year}', style: TextStyle(color: _pal.ink2, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RC.gold(0.6)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- niyet ve dua

  Widget _duaView(RamazanData d) {
    Widget head(String t) => Text(t,
        style: TextStyle(color: _pal.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6));
    Widget card(List<Widget> children) => PaperBox(
          pal: _pal,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card([
          head(d.niyetTitle),
          const SizedBox(height: 4),
          Text('"${d.niyet}"',
              textAlign: TextAlign.center, style: TextStyle(color: _pal.ink, fontSize: 14, height: 1.55)),
          const SizedBox(height: 4),
          Text(d.niyetNote, textAlign: TextAlign.center, style: TextStyle(color: _pal.ink2, fontSize: 11.5)),
        ]),
        for (final p in d.prayers) ...[
          const SizedBox(height: 10),
          card([
            head(p.title),
            const SizedBox(height: 4),
            Text(p.arabic,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: kQuranFont, fontSize: 21, height: 2, color: _pal.ink)),
            Text(p.reading,
                textAlign: TextAlign.center,
                style: TextStyle(color: _pal.ink2, fontSize: 13.5, height: 1.5, fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Text(p.meaning, textAlign: TextAlign.center, style: TextStyle(color: _pal.ink, fontSize: 14, height: 1.55)),
            if (p.source.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(p.source, textAlign: TextAlign.center, style: TextStyle(color: _pal.ink2, fontSize: 11.5)),
            ],
          ]),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- önemli günler

  Widget _daysView(RamazanData d) {
    return PaperBox(
      pal: _pal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: withDividers([
          for (final (name, date) in d.importantDays)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(name, style: TextStyle(color: _pal.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Text(date, style: TextStyle(color: _pal.ink2, fontSize: 12.5)),
                ],
              ),
            ),
        ], _pal.line),
      ),
    );
  }
}

String _monthTr(int m) => const [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ][m - 1];

/// Panelin üstündeki "✦ ❖ ✦" süsü (yazı tipinden bağımsız çizim).
class _HeroOrnament extends StatelessWidget {
  const _HeroOrnament();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 16,
      child: CustomPaint(painter: _HeroOrnamentPainter()),
    );
  }
}

class _HeroOrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const gold = RC.goldBorder;
    final cy = size.height / 2, cx = size.width / 2;
    final paint = Paint()..color = gold;
    void star(double x, double r) {
      final k = r * 0.28;
      canvas.drawPath(
        Path()
          ..moveTo(x, cy - r)
          ..quadraticBezierTo(x + k, cy - k, x + r, cy)
          ..quadraticBezierTo(x + k, cy + k, x, cy + r)
          ..quadraticBezierTo(x - k, cy + k, x - r, cy)
          ..quadraticBezierTo(x - k, cy - k, x, cy - r)
          ..close(),
        paint,
      );
    }

    star(cx - 22, 6);
    star(cx + 22, 6);
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - 6)
        ..lineTo(cx + 6, cy)
        ..lineTo(cx, cy + 6)
        ..lineTo(cx - 6, cy)
        ..close(),
      paint,
    );
    final line = Paint()
      ..shader = const LinearGradient(colors: [Color(0x00D4AF37), gold]).createShader(Rect.fromLTWH(0, cy, cx - 40, 1))
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx - 150, cy), Offset(cx - 40, cy), line);
    final line2 = Paint()
      ..shader =
          const LinearGradient(colors: [gold, Color(0x00D4AF37)]).createShader(Rect.fromLTWH(cx + 40, cy, 110, 1))
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx + 40, cy), Offset(cx + 150, cy), line2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Panel köşesindeki altın köşebent.
class _CornerOrnament extends StatelessWidget {
  final bool flip;

  const _CornerOrnament({this.flip = false});

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: flip,
      child: const SizedBox(width: 42, height: 42, child: CustomPaint(painter: _CornerPainter())),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = RC.goldBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(
      Path()
        ..moveTo(4, size.height - 4)
        ..lineTo(4, 4)
        ..lineTo(size.width - 4, 4),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(10, size.height - 10)
        ..lineTo(10, 10)
        ..lineTo(size.width - 16, 10),
      p..strokeWidth = 1,
    );
    canvas.drawCircle(const Offset(10, 10), 3, Paint()..color = RC.goldBorder);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => false;
}
