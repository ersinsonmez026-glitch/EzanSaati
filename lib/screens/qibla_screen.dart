import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/compass.dart';
import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'city_picker_screen.dart';
import '../widgets/gold_icon.dart';

/// Telefonun pusulasıyla çalışan Kıble bulucu (onizleme/07-kible.html).
/// Kadran telefonla birlikte döner; ibrenin ucundaki Kâbe üstteki altın işareti
/// gösterdiğinde kıble yönündesiniz.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  static const double _kaabaLat = 21.4225;
  static const double _kaabaLng = 39.8262;

  /// Bu kadar derece içindeyken kıble yönünde sayılır.
  static const double alignTolerance = 4;

  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  StreamSubscription<CompassReading>? _sub;
  double? _heading; // yumuşatılmış yön
  int _accuracy = 3;
  String? _error;
  bool _wasAligned = false;
  bool _helpOpen = false;

  // Kadran ve ibre 359°→0° geçişinde ters yönde tam tur atmasın diye birikimli açı.
  double _shownDial = 0, _shownNeedle = 0;

  @override
  void initState() {
    super.initState();
    final loc = LocationStore.instance.current;
    if (loc != null) Compass.setLocation(loc.lat, loc.lng);
    _sub = Compass.stream().listen(
      _onReading,
      onError: (Object e) {
        if (!mounted) return;
        setState(() =>
            _error = e is PlatformException && e.message != null ? e.message : 'Bu cihazda pusula kullanılamıyor.');
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onReading(CompassReading r) {
    final prev = _heading;
    double next;
    if (prev == null) {
      next = r.heading;
    } else {
      // 359° -> 0° geçişinde zıplamasın diye en kısa farkla yumuşat.
      final diff = signedDiff(r.heading, prev);
      next = (prev + diff * 0.25) % 360;
      if (next < 0) next += 360;
    }
    if (!mounted) return;
    setState(() {
      _heading = next;
      _accuracy = r.accuracy;
    });
  }

  /// a - b farkını -180..180 aralığında verir.
  static double signedDiff(double a, double b) {
    var d = (a - b) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  static double _near(double cur, double target) => cur + signedDiff(target, cur);

  Future<void> _pickCity() async {
    await Navigator.of(context).push(AppRoute(builder: (_) => const CityPickerScreen()));
    final l = LocationStore.instance.current;
    if (l != null) Compass.setLocation(l.lat, l.lng);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loc = LocationStore.instance.current;
    return PageShell(
      title: 'Kıble',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: loc == null ? [_noLocation()] : _content(loc),
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
              'Kıble yönünü hesaplamak için önce şehrinizi seçin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _pal.ink, fontSize: 15),
            ),
            const SizedBox(height: 14),
            DarkButton(label: 'Şehir Seç', onTap: _pickCity),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(AppLocation loc) {
    final qibla = PrayerCalc.qiblaDirection(loc);
    final km = LocationStore.distanceKm(loc.lat, loc.lng, _kaabaLat, _kaabaLng);
    final heading = _heading;
    final diff = heading == null ? null : signedDiff(qibla, heading);
    final aligned = diff != null && diff.abs() < alignTolerance;

    if (aligned && !_wasAligned) HapticFeedback.mediumImpact();
    _wasAligned = aligned;

    _shownDial = _near(_shownDial, -(heading ?? 0));
    _shownNeedle = _near(_shownNeedle, qibla - (heading ?? 0));

    final String status;
    if (_error != null) {
      status = 'Pusula kullanılamıyor';
    } else if (heading == null) {
      status = 'Telefonu düz tutun';
    } else if (aligned) {
      status = 'Kıble yönündesiniz';
    } else {
      status = '${diff! > 0 ? 'Sağa' : 'Sola'} dönün · ${diff.abs().round()}°';
    }
    const gap = SizedBox(height: 10);

    return [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          gradient: _pal.paperGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: RC.gold(0.6), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x24281905), blurRadius: 12, offset: Offset(0, 3))],
        ),
        child: Column(
          children: [
            Semantics(
              liveRegion: true,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: aligned ? null : _pal.chip,
                  gradient: aligned ? RC.darkPanel : null,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: aligned ? RC.gold(0.8) : _pal.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (aligned) ...[
                      const GoldIcon(Icons.check_circle_rounded, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(status,
                        style: TextStyle(
                          color: aligned ? RC.goldText : _pal.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Sayfa kaydırmadan sığsın: pusula ekran yüksekliğine göre küçülür (kıble açısı alttaki bilgi satırında).
            SizedBox.square(dimension: _compassSize(context), child: FittedBox(child: _compass(aligned))),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _error ??
                    'İbrenin ucundaki Kâbe tam yukarıyı, yani üstteki altın işareti gösterene kadar kendi '
                        'etrafınızda dönün.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _pal.ink2, fontSize: 12, height: 1.45),
              ),
            ),
          ],
        ),
      ),
      if (_accuracy <= 1 && _error == null) ...[
        gap,
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF4D3A6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFC0762E)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: Color(0xFF6B3A0C)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pusula hassasiyeti düşük. Telefonu havada birkaç kez 8 çizer gibi çevirerek ayarlayın.',
                  style: TextStyle(color: Color(0xFF6B3A0C), fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
      gap,
      _infoRow(loc, qibla, km),
      gap,
      _help(),
      gap,
      SourceNote(
        pal: _pal,
        text: loc.fromGps
            ? 'Kıble açısı telefonun konumuna göre hesaplanır.'
            : 'Kıble açısı seçili şehrin merkezine göre hesaplanır.',
      ),
    ];
  }

  /// Başlık, bilgi satırı ve yardım dışında kalan yükseklik; en fazla 260, en az 170.
  static double _compassSize(BuildContext context) {
    final m = MediaQuery.of(context);
    final h = m.size.height - m.padding.top - m.padding.bottom;
    return (h - 470).clamp(170.0, 260.0);
  }

  Widget _compass(bool aligned) {
    return Center(
      child: SizedBox(
        width: 290,
        height: 290,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Kadran (telefonla birlikte döner) ve yön harfleri
            Positioned.fill(
              child: Transform.rotate(
                angle: _shownDial * math.pi / 180,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x4D1E1405), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: Image.asset('assets/images/kible/dial.webp')),
                      for (final (l, a) in const [('K', 0), ('D', 90), ('G', 180), ('B', 270)]) _letter(l, a),
                    ],
                  ),
                ),
              ),
            ),
            // Kâbe'yi gösteren ibre
            Positioned.fill(
              left: 8.5,
              top: 8.5,
              right: 8.5,
              bottom: 8.5,
              child: Transform.rotate(
                angle: _shownNeedle * math.pi / 180,
                child: Image.asset(
                  'assets/images/kible/needle.webp',
                  semanticLabel: 'Kâbe yönünü gösteren ibre',
                ),
              ),
            ),
            // Üstteki sabit işaret: telefonun baktığı yön
            Positioned(
              top: -11,
              left: 145 - 9,
              child: CustomPaint(
                size: const Size(18, 13),
                painter: _MarkPainter(aligned ? const Color(0xFF0B6B43) : const Color(0xFFB8892A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _letter(String l, int deg) {
    const r = 145 * 0.57;
    final a = deg * math.pi / 180;
    return Positioned(
      left: 145 + math.sin(a) * r - 12,
      top: 145 - math.cos(a) * r - 12,
      width: 24,
      height: 24,
      child: Transform.rotate(
        angle: a,
        child: Center(
          child: Text(
            l,
            style: TextStyle(
              color: l == 'K' ? const Color(0xFFFFD76A) : const Color(0xFFF3E6C0),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 2, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(AppLocation loc, double qibla, double km) {
    Widget cell(String v, String l) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(v,
                      maxLines: 1, style: TextStyle(color: _pal.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Text(l, style: TextStyle(color: _pal.ink2, fontSize: 11)),
              ],
            ),
          ),
        );
    Widget sep() => SizedBox(width: 1, child: CustomPaint(painter: _DashV(_pal.line)));
    final kmText = km.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return Container(
      decoration: BoxDecoration(
        gradient: _pal.paperGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _pal.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell(loc.name, 'Konum'),
            sep(),
            cell('${qibla.round()}°', 'Kıble açısı'),
            sep(),
            cell('$kmText km', "Kâbe'ye uzaklık"),
          ],
        ),
      ),
    );
  }

  Widget _help() {
    const tips = [
      'Telefonu havada birkaç kez 8 çizer gibi çevirerek pusulayı ayarlayın.',
      'Mıknatıslı kılıf, hoparlör, bilgisayar ve demir eşyalardan uzak durun.',
      'Telefonu yere paralel, düz tutun.',
      'Emin olmak için güneşin ya da bilinen bir caminin yönüyle karşılaştırın.',
    ];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: _pal.paperGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _helpOpen,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _helpOpen = !_helpOpen),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Pusula yanlış mı gösteriyor?',
                          style: TextStyle(color: _pal.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    AnimatedRotation(
                      turns: _helpOpen ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Text('›', style: TextStyle(color: _pal.gold, fontSize: 20, height: 1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_helpOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final t in tips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ', style: TextStyle(color: _pal.ink, fontSize: 13.5, height: 1.6)),
                          Expanded(
                            child: Text(t, style: TextStyle(color: _pal.ink, fontSize: 13.5, height: 1.6)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Dikey kesik çizgi (bilgi şeridindeki bölmeler).
class _DashV extends CustomPainter {
  final Color color;
  _DashV(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(0, math.min(y + 3, size.height)), p);
    }
  }

  @override
  bool shouldRepaint(_DashV old) => old.color != color;
}

/// Kadranın üstündeki aşağı bakan üçgen işaret.
class _MarkPainter extends CustomPainter {
  final Color color;
  _MarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 1.5, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
