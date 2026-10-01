import 'dart:async';

import 'package:flutter/material.dart';

import '../services/dhikr_store.dart';
import '../services/prayer_groups.dart';
import '../services/vibration.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'surah_read_screen.dart';

/// Zincirdeki payın sayacı: "12 / 50 salavat". Her dokunuş bir sayar; okunan sayı birkaç saniyede bir
/// zincire yazılır, zincirdeki herkes ilerlemeyi görür.
class ChainCounterScreen extends StatefulWidget {
  final String chainId;

  const ChainCounterScreen({super.key, required this.chainId});

  @override
  State<ChainCounterScreen> createState() => _ChainCounterScreenState();
}

class _ChainCounterScreenState extends State<ChainCounterScreen> {
  PagePalette get _pal => PagePalette.current();
  GroupSync get _sync => GroupSync.instance;

  int? _n; // ekranda görünen sayı (zincire henüz yazılmamış olabilir)
  int _sent = -1;
  Timer? _flushTimer;

  @override
  void initState() {
    super.initState();
    _sync.addListener(_changed);
  }

  @override
  void dispose() {
    _sync.removeListener(_changed);
    _flushTimer?.cancel();
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
    _flushTimer?.cancel();
    if (next >= m.amount) {
      Vibration.heavy();
      _flush();
      showNote(context, 'Payınızı tamamladınız · Allah kabul etsin');
    } else {
      Vibration.light();
      _flushTimer = Timer(const Duration(seconds: 2), _flush);
    }
  }

  void _undo() {
    final m = _mine;
    final n = _n ?? m?.done ?? 0;
    if (m == null || n <= 0) return;
    setState(() => _n = n - 1);
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
        if (text != null)
          PaperBox(
            pal: p,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(children: [
              Text(text.arabic,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: kArabicFont, fontSize: 24, height: 1.6, color: p.gold)),
              Text(text.title, textAlign: TextAlign.center, style: TextStyle(color: p.ink, fontSize: 15, fontWeight: FontWeight.w700)),
              Text(text.meaning, textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 12.5)),
            ]),
          )
        else if (surah != null)
          DarkButton(
            label: surah == 36 ? 'Yâsin Sûresi\'ni aç' : 'İhlâs Sûresi\'ni aç',
            onTap: () => Navigator.of(context).push(AppRoute(builder: (_) => SurahReadScreen(surah: surah))),
          ),
        const SizedBox(height: 16),
        Center(
          child: Semantics(
            button: true,
            label: 'Say: $n / ${m.amount}',
            child: GestureDetector(
              key: const Key('chainTap'),
              onTap: _tap,
              child: Container(
                width: 230,
                height: 230,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [p.gold.withValues(alpha: 0.30), p.gold.withValues(alpha: 0.08)]),
                  border: Border.all(color: p.gold, width: 2),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$n', style: TextStyle(color: p.ink, fontSize: 64, fontWeight: FontWeight.w700, height: 1)),
                  Text('/ ${trNum(m.amount)} ${c.unit}', style: TextStyle(color: p.ink2, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(done ? 'Tamamlandı' : (surah != null ? 'Okudukça dokunun' : 'Dokunarak sayın'),
                      style: TextStyle(color: p.gold, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
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
