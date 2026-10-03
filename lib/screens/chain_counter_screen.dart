import 'dart:async';

import 'package:flutter/material.dart';

import '../services/dhikr_store.dart';
import '../services/prayer_groups.dart';
import '../services/tesbih_sound.dart';
import '../services/vibration.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'dhikr_screen.dart';
import 'surah_read_screen.dart';

/// Zincirdeki payın sayacı: "12 / 50 salavat". Her dokunuş bir sayar; okunan sayı birkaç saniyede bir
/// zincire yazılır, zincirdeki herkes ilerlemeyi görür.
class ChainCounterScreen extends StatefulWidget {
  final String chainId;

  const ChainCounterScreen({super.key, required this.chainId});

  @override
  State<ChainCounterScreen> createState() => _ChainCounterScreenState();
}

class _ChainCounterScreenState extends State<ChainCounterScreen> with SingleTickerProviderStateMixin {
  PagePalette get _pal => PagePalette.current();
  GroupSync get _sync => GroupSync.instance;

  int? _n; // ekranda görünen sayı (zincire henüz yazılmamış olabilir)
  int _sent = -1;
  Timer? _flushTimer;
  late final AnimationController _beads = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  int _beadDir = -1;
  double _drag = 0;
  bool _sound = true, _vibrate = true; // Zikir Sayacı'ndaki ayarlar

  @override
  void initState() {
    super.initState();
    _sync.addListener(_changed);
    DhikrState.load().then((d) {
      if (!mounted) return;
      setState(() {
        _sound = d.sound;
        _vibrate = d.vibrate;
      });
    });
  }

  @override
  void dispose() {
    _sync.removeListener(_changed);
    _flushTimer?.cancel();
    _beads.dispose();
    _flush();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  GroupChain? get _chain => _sync.chain(widget.chainId);
  ChainClaim? get _mine => _chain?.claimOf(_sync.uid ?? '');

  /// Okunanı zincire yazar (dokunuşlar bitince ya da pay tamamlanınca).
  void _flush() {
    final c = _chain, n = _n;
    if (c == null || n == null || n == _sent) return;
    _sent = n;
    unawaited(_sync.setDone(c, n).catchError((_) {}));
  }

  void _tap() {
    final m = _mine;
    if (m == null) return;
    final n = (_n ?? m.done);
    if (n >= m.amount) return;
    final next = n + 1;
    setState(() => _n = next);
    _beadDir = -1;
    _beads.forward(from: 0);
    if (_sound) TesbihSound.play();
    _flushTimer?.cancel();
    if (next >= m.amount) {
      if (_vibrate) Vibration.heavy();
      _flush();
      showNote(context, 'Payınızı tamamladınız · Allah kabul etsin');
    } else {
      if (_vibrate) Vibration.light();
      _flushTimer = Timer(const Duration(seconds: 2), _flush);
    }
  }

  void _undo() {
    final m = _mine;
    final n = _n ?? m?.done ?? 0;
    if (m == null || n <= 0) return;
    setState(() => _n = n - 1);
    _beadDir = 1;
    _beads.forward(from: 0);
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 2), _flush);
  }

  /// Zincir türüne göre okunacak metin (Zikir Sayacı'ndaki metinlerle aynı).
  Dhikr? get _text => switch (_chain?.type) {
        'salavat' => kDhikrs.firstWhere((d) => d.id == 'salavat'),
        'istigfar' => kDhikrs.firstWhere((d) => d.id == 'istigfar'),
        _ => null,
      };

  int? get _surah => switch (_chain?.type) { 'yasin' => 36, 'ihlas' => 112, _ => null };

  @override
  Widget build(BuildContext context) {
    final p = _pal;
    final c = _chain, m = _mine;
    if (c == null || m == null) {
      return PageShell(title: 'Dua Zinciri', background: p.background, children: [
        const SizedBox(height: 40),
        Center(child: CircularProgressIndicator(color: p.gold)),
      ]);
    }
    final n = (_n ?? m.done).clamp(0, m.amount);
    final done = n >= m.amount;
    final text = _text, surah = _surah;
    return PageShell(
      title: c.name,
      subtitle: 'Zincirdeki payınız',
      background: p.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (surah != null) ...[
          DarkButton(
            label: surah == 36 ? 'Yâsin Sûresi\'ni aç' : 'İhlâs Sûresi\'ni aç',
            onTap: () => Navigator.of(context).push(AppRoute(builder: (_) => SurahReadScreen(surah: surah))),
          ),
          const SizedBox(height: 10),
        ],
        // Zikir Sayacı'ndaki kartın aynısı: metin, büyük sayı, "okunan/pay", tesbih taneleri.
        Semantics(
          button: true,
          label: 'Say: $n / ${m.amount}',
          child: GestureDetector(
            key: const Key('chainTap'),
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            onHorizontalDragStart: (_) => _drag = 0,
            onHorizontalDragUpdate: (d) {
              _drag += d.delta.dx.abs();
              while (_drag >= kSwipeStep) {
                _drag -= kSwipeStep;
                _tap();
              }
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: p.paperGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: RC.gold(0.6), width: 1.5),
                boxShadow: const [BoxShadow(color: Color(0x24281905), blurRadius: 12, offset: Offset(0, 3))],
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(children: [
                if (text != null) ...[
                  Text(text.arabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontFamily: kArabicFont, fontSize: 23, height: 1.8, color: p.gold)),
                  Text(text.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.ink, fontSize: 17, height: 1.3, fontWeight: FontWeight.w700)),
                  Text(text.meaning,
                      textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 12.5, height: 1.4)),
                ] else
                  Text(c.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.ink, fontSize: 17, height: 1.3, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('$n',
                    style: TextStyle(
                        color: p.ink,
                        fontSize: 60,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(height: 4),
                Text('$n/${m.amount}',
                    style: TextStyle(color: p.ink2, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: BeadString(
                    animation: _beads,
                    dir: _beadDir,
                    image: p.night ? 'assets/images/zikir/b_krem.webp' : 'assets/images/zikir/b_yes.webp',
                    color: p.gold,
                  ),
                ),
                Text(done ? 'Tamamlandı' : 'Saymak için karta dokunun ya da yana kaydırın',
                    style: TextStyle(
                        color: done ? p.gold : p.ink2, fontSize: 11.5, fontWeight: done ? FontWeight.w700 : null)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
              value: m.amount == 0 ? 0 : n / m.amount,
              minHeight: 8,
              backgroundColor: p.line.withValues(alpha: 0.25),
              color: p.gold),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text(
              done ? 'Payınızı tamamladınız · Allah kabul etsin' : 'Kalan: ${trNum(m.amount - n)}',
              style: TextStyle(color: done ? p.gold : p.ink2, fontSize: 13.5),
            ),
          ),
          TextButton.icon(
            onPressed: n > 0 ? _undo : null,
            icon: Icon(Icons.undo, size: 18, color: p.ink2),
            label: Text('Geri al', style: TextStyle(color: p.ink2)),
          ),
        ]),
        const SizedBox(height: 6),
        SourceNote(
          pal: p,
          text: 'Okuduğunuz sayı zincirdeki herkese görünür. Sayfadan çıkıp sonra Zikir Sayacı\'ndan ya da '
              'Dua Zinciri\'nden kaldığınız yerden devam edebilirsiniz.',
        ),
      ],
    );
  }
}
