import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/dhikr_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Zikir Sayacı (onizleme/06-zikir-sayaci.html): solda zikir listesi, sağda tesbih taneli
/// sayaç kartı. Karta dokunmak sayar; hedef, geri alma, titreşim ve namaz sonrası tesbihat.
class DhikrScreen extends StatefulWidget {
  const DhikrScreen({super.key});

  @override
  State<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends State<DhikrScreen> with SingleTickerProviderStateMixin {
  final _pal = PagePalette.current();
  DhikrState? _s;
  late final AnimationController _beads = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  int _beadDir = -1; // -1: sayınca taneler sola kayar, +1: geri alınca sağa
  bool _hit = false;

  @override
  void initState() {
    super.initState();
    DhikrState.load().then((s) {
      if (mounted) setState(() => _s = s);
    });
  }

  @override
  void dispose() {
    _beads.dispose();
    super.dispose();
  }

  void _moveBeads(int dir) {
    _beadDir = dir;
    _beads.forward(from: 0);
  }

  void _buzz({bool strong = false}) {
    if (!(_s?.vibrate ?? false)) return;
    if (strong) {
      HapticFeedback.heavyImpact();
      Timer(const Duration(milliseconds: 160), HapticFeedback.heavyImpact);
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _add() {
    final s = _s;
    if (s == null) return;
    final z = s.current;
    final hit = s.add();
    if (hit == DhikrHit.ignored) return;
    _moveBeads(-1);
    setState(() => _hit = true);
    Timer(const Duration(milliseconds: 110), () {
      if (mounted) setState(() => _hit = false);
    });
    switch (hit) {
      case DhikrHit.round:
        _buzz(strong: true);
        showNote(context, '${z.title}: ${s.counter(z.id).rounds}. tur tamamlandı');
      case DhikrHit.tesbihatStep:
        _buzz(strong: true);
        showNote(context, s.tesbihat! < 3 ? 'Sıradaki: ${s.current.title}' : 'Son olarak tevhidi okuyun');
      default:
        _buzz();
    }
  }

  void _undo() {
    if (_s?.undo() ?? false) {
      _moveBeads(1);
      setState(() {});
    }
  }

  void _reset() {
    if (_s?.reset() ?? false) {
      setState(() {});
      showNote(context, 'Sayaç sıfırlandı');
    }
  }

  void _toggleTesbihat() {
    final s = _s!;
    setState(() {
      if (s.tesbihat == null) {
        s.startTesbihat();
      } else {
        s.stopTesbihat();
      }
    });
    if (s.tesbihat == null) showNote(context, 'Tesbihat yarıda bırakıldı');
  }

  void _finishTesbihat() {
    setState(() => _s!.stopTesbihat());
    showNote(context, 'Tesbihat tamamlandı. Allah kabul etsin.');
  }

  Future<void> _addCustom() async {
    final r = await showDialog<(String, int)>(context: context, builder: (_) => _AddDhikrDialog(pal: _pal));
    if (r == null || !mounted) return;
    setState(() => _s!.addCustom(r.$1, r.$2));
    showNote(context, '${r.$1} eklendi');
  }

  void _removeCustom(Dhikr z) {
    setState(() => _s!.removeCustom(z.id));
    showNote(context, 'Zikir silindi');
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return PageShell(
      title: 'Zikir Sayacı',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: s == null
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 108, child: _list(s)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _card(s),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                          child: Text(
                            'Bugün toplam ${s.todayTotal} zikir',
                            textAlign: TextAlign.right,
                            style: TextStyle(color: _pal.ink2, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SourceNote(
                pal: _pal,
                text: 'Sayılar bu cihazda saklanır. Namazdan sonra tesbihat: 33 Sübhânallâh, 33 Elhamdülillâh, '
                    '33 Allâhü ekber ve tevhid (Müslim, Mesâcid 146).',
              ),
            ],
    );
  }

  // ---------------------------------------------------------------- zikir listesi

  Widget _list(DhikrState s) {
    final ts = s.tesbihat != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _listItem('✦ Tesbihat', on: ts, onTap: _toggleTesbihat, semantic: ts ? 'Tesbihatı bitir' : 'Tesbihat'),
        for (final z in s.all)
          _listItem(
            z.label,
            on: !ts && z.id == s.selected,
            onTap: () => setState(() => s.select(z.id)),
            onRemove: z.custom ? () => _removeCustom(z) : null,
          ),
        _listItem('+ Ekle', dashed: true, onTap: _addCustom, semantic: 'Kendi zikrini ekle'),
      ],
    );
  }

  Widget _listItem(String label,
      {bool on = false, bool dashed = false, required VoidCallback onTap, VoidCallback? onRemove, String? semantic}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: on,
        label: semantic ?? label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 34),
            padding: EdgeInsets.fromLTRB(7, 6, onRemove != null ? 20 : 7, 6),
            decoration: BoxDecoration(
              gradient: on ? RC.bronze : RC.darkPanel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: on ? RC.bronzeBorder : RC.gold(0.75),
                width: on ? 1.5 : 1,
                style: dashed ? BorderStyle.none : BorderStyle.solid,
              ),
              boxShadow:
                  on ? RC.bronzeGlow : const [BoxShadow(color: Color(0x80000000), blurRadius: 5, offset: Offset(0, 2))],
            ),
            foregroundDecoration: dashed
                ? BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: RC.gold(0.5)))
                : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: dashed ? Alignment.center : Alignment.centerLeft,
                  child: _fitWord(
                    label,
                    TextStyle(
                      color: on ? RC.bronzeText : (dashed ? const Color(0xFFE9C96A) : RC.cream),
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onRemove != null)
                  Positioned(
                    right: -18,
                    top: -6,
                    child: Semantics(
                      button: true,
                      label: '$label zikrini sil',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onRemove,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Text('×', style: TextStyle(color: RC.cream, fontSize: 15, height: 1)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tek kelimelik uzun adlar (ör. Elhamdülillâh) bölünmesin, sığmazsa küçülsün.
  Widget _fitWord(String label, TextStyle style) {
    final text = Text(label, style: style, maxLines: label.contains(' ') ? null : 1);
    if (label.contains(' ')) return text;
    return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: text);
  }

  // ---------------------------------------------------------------- sayaç kartı

  Widget _card(DhikrState s) {
    final z = s.current, c = s.counter(z.id), t = s.targetOf(z.id);
    final tev = s.tesbihat == 3;
    return Semantics(
      button: true,
      label: 'Saymak için dokunun',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _add,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: _pal.paperGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RC.gold(0.6), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x24281905), blurRadius: 12, offset: Offset(0, 3))],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(46, 12, 46, 0),
                    child: Column(
                      children: [
                        if (s.tesbihat != null)
                          Text('TESBİHAT · ${s.tesbihat! + 1} / 4',
                              style: TextStyle(
                                  color: _pal.gold, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                        if (!tev && z.arabic.isNotEmpty)
                          Text(
                            z.arabic,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(fontFamily: kQuranFont, fontSize: 23, height: 1.8, color: _pal.gold),
                          ),
                        if (!tev)
                          Text(z.title,
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: _pal.ink, fontSize: 17, height: 1.3, fontWeight: FontWeight.w700)),
                        if (tev || z.meaning.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              tev ? 'Tesbihatın sonunda bir kez okunur.' : z.meaning,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _pal.ink2, fontSize: 12.5, height: 1.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (tev) _tevhid() else _count(s, c, t),
                  _tools(s, t),
                ],
              ),
              Positioned(top: 48, right: 6, child: _resetButton()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _count(DhikrState s, DhikrCounter c, int t) {
    return Column(
      children: [
        const SizedBox(height: 8),
        AnimatedScale(
          scale: _hit ? 1.05 : 1,
          duration: const Duration(milliseconds: 110),
          child: Text(
            '${c.n}',
            style: TextStyle(
              color: _pal.ink,
              fontSize: 60,
              height: 1,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t > 0 ? '${c.n}/$t' : '${c.n} · serbest',
          style: TextStyle(color: _pal.ink2, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        if (c.rounds > 0)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE6C35A), Color(0xFFC29A2C)],
              ),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('${c.rounds}. tur',
                style: const TextStyle(color: Color(0xFF1D1406), fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 4),
        ExcludeSemantics(
          child: _BeadString(
            animation: _beads,
            dir: _beadDir,
            image: _pal.night ? 'assets/images/zikir/b_krem.webp' : 'assets/images/zikir/b_yes.webp',
            color: _pal.gold,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Saymak için karta dokunun', style: TextStyle(color: _pal.ink2, fontSize: 11.5)),
        ),
      ],
    );
  }

  Widget _tevhid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          Text(
            kTesbihatTevhidArabic,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: kQuranFont, fontSize: 20, height: 2, color: _pal.ink),
          ),
          const SizedBox(height: 2),
          Text(
            kTesbihatTevhidReading,
            textAlign: TextAlign.center,
            style: TextStyle(color: _pal.ink2, fontSize: 13, height: 1.5, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _finishTesbihat,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE6C35A), Color(0xFFC29A2C)],
                ),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0xFF8A6414)),
              ),
              child: const Text('Okudum, bitir',
                  style: TextStyle(color: Color(0xFF1D1406), fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resetButton() {
    return Semantics(
      button: true,
      label: 'Sıfırla',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _reset,
        child: Container(
          width: 40,
          height: 46,
          decoration: BoxDecoration(
            color: _pal.chip,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xD9C9A23A), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x1F281905), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, size: 17, color: _pal.gold),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Sıfırla',
                    maxLines: 1, style: TextStyle(color: _pal.ink, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tools(DhikrState s, int t) {
    final ts = s.tesbihat != null;
    Widget iconBtn(IconData icon, String label, VoidCallback onTap, {bool on = false}) => Semantics(
          button: true,
          label: label,
          toggled: label == 'Titreşim' ? on : null,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 34,
              height: 32,
              decoration: BoxDecoration(
                color: on ? null : _pal.chip,
                gradient: on ? RC.bronze : null,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: on ? RC.bronzeBorder : _pal.line),
              ),
              child: Icon(icon, size: 17, color: on ? RC.bronzeText : _pal.gold),
            ),
          ),
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // araç şeridine dokunmak saymaz
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: _pal.line))),
        child: Row(
          children: [
            iconBtn(Icons.undo, 'Geri al', _undo),
            const SizedBox(width: 5),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _pal.chip,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _pal.line),
                ),
                child: Row(
                  children: [
                    for (final v in kDhikrTargets)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: v == t,
                          enabled: !ts,
                          label: v == 0 ? 'Hedef serbest' : 'Hedef $v',
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: ts ? null : () => setState(() => s.setTarget(v)),
                            child: Opacity(
                              opacity: ts ? 0.45 : 1,
                              child: Container(
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: v == t ? RC.bronze : null,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  v == 0 ? '∞' : '$v',
                                  style: TextStyle(
                                    color: v == t ? RC.bronzeText : _pal.ink,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            iconBtn(Icons.vibration, 'Titreşim', () {
              setState(() => s.toggleVibrate());
              showNote(context, s.vibrate ? 'Titreşim açık' : 'Titreşim kapalı');
              if (s.vibrate) HapticFeedback.mediumImpact();
            }, on: s.vibrate),
          ],
        ),
      ),
    );
  }
}

/// Sayınca sola kayan tesbih taneleri (ipte 14 tane, ortada boşluk).
class _BeadString extends StatelessWidget {
  final Animation<double> animation;
  final int dir;
  final String image;
  final Color color;

  const _BeadString({required this.animation, required this.dir, required this.image, required this.color});

  static const n = 14;
  static const d = 27.0; // taneler arası
  static const gap = 58.0; // ortadaki boşluk
  static const size = 34.0;
  static const height = 62.0;

  static double xOf(double s, double w) {
    final c = w / 2;
    const half = n / 2;
    if (s <= half - 1) return c - gap / 2 - (half - 1 - s) * d;
    if (s >= half) return c + gap / 2 + (s - half) * d;
    final a = c - gap / 2, b = c + gap / 2;
    return a + (b - a) * (s - (half - 1));
  }

  static double yOf(double x, double w) {
    final t = (x / w) * 2 - 1;
    return 22 + 14 * (1 - t * t);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => const LinearGradient(
            colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
            stops: [0, 0.12, 0.88, 1],
          ).createShader(r),
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              // Taneler bir sıra kayar; bitince aynı diziliş geri gelir (taneler birbirinin aynısı).
              final off = animation.isCompleted || animation.value == 0 ? 0.0 : dir * animation.value;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(child: CustomPaint(painter: _StringPainter(color))),
                  for (var i = -1; i <= n; i++) _bead(i + off, w),
                ],
              );
            },
          ),
        );
      }),
    );
  }

  Widget _bead(double s, double w) {
    final out = s < 0 ? -s : (s > n - 1 ? s - (n - 1) : 0.0);
    final opacity = (1 - out).clamp(0.0, 1.0);
    if (opacity == 0) return const SizedBox.shrink();
    final x = xOf(s, w), y = yOf(x, w);
    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      child: Opacity(
        opacity: opacity,
        child: Image.asset(image, width: size, height: size),
      ),
    );
  }
}

class _StringPainter extends CustomPainter {
  final Color color;
  _StringPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    for (var x = 0.0; x <= size.width; x += 6) {
      final y = _BeadString.yOf(x, size.width);
      x == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = color.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_StringPainter old) => old.color != color;
}

/// Kendi zikrini ekleme penceresi (ad + hedef).
class _AddDhikrDialog extends StatefulWidget {
  final PagePalette pal;
  const _AddDhikrDialog({required this.pal});

  @override
  State<_AddDhikrDialog> createState() => _AddDhikrDialogState();
}

class _AddDhikrDialogState extends State<_AddDhikrDialog> {
  final _name = TextEditingController();
  int _target = 100;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    Navigator.of(context).pop((n, _target));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kendi zikrini ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(labelText: 'Zikrin adı'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          const Text('Hedef'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final v in kDhikrTargets)
                ChoiceChip(
                  label: Text(v == 0 ? '∞' : '$v'),
                  selected: _target == v,
                  onSelected: (_) => setState(() => _target = v),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
        FilledButton(onPressed: _save, child: const Text('Ekle')),
      ],
    );
  }
}
