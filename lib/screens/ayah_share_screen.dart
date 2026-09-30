import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../services/content_store.dart';
import '../widgets/reading_ui.dart';

/// Karta sığmayacak kadar uzun ayetler görsel yerine metin olarak paylaşılır (ayet kısaltılmaz).
const kShareMaxChars = 1000;

bool ayahFitsCard(Ayah a) => a.arabic.length + a.plainMeal.length <= kShareMaxChars;

/// Ayeti seçilen arka planlı bir kart olarak paylaşır.
class AyahShareScreen extends StatefulWidget {
  final Surah surah;
  final int ayahNo;
  final Ayah ayah;

  const AyahShareScreen({super.key, required this.surah, required this.ayahNo, required this.ayah});

  @override
  State<AyahShareScreen> createState() => _AyahShareScreenState();
}

class _AyahShareScreenState extends State<AyahShareScreen> {
  static const _cream = Color(0xFFF3E4C0);
  final _cardKey = GlobalKey();
  bool _arabic = true;
  bool _meal = true;
  bool _sharing = false;

  String get _ref => '${widget.surah.name} Sûresi, ${widget.ayahNo}. ayet';

  String get _text => '${widget.ayah.arabic}\n\n${widget.ayah.plainMeal}\n(${widget.surah.name}, ${widget.ayahNo})'
      '\n\n— Ezan Saati uygulamasından gönderildi';

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('görsel üretilemedi');
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png', name: 'ayet.png')],
        fileNameOverrides: const ['ayet.png'],
      ));
    } catch (_) {
      if (mounted) showNote(context, 'Görsel paylaşılamadı');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020F0A),
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 52,
            child: Row(children: [
              IconButton(
                tooltip: 'Geri',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: _cream),
              ),
              const Expanded(
                child: Text('Ayeti paylaş',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: RC.bronzeText, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 48),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: RC.gold(0.7), width: 1.2),
                    ),
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: AyahShareCard(
                        arabic: _arabic ? widget.ayah.arabic : null,
                        meal: _meal ? widget.ayah.plainMeal : null,
                        reference: _ref,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _toggle('Arapça', _arabic, () {
                if (_arabic && !_meal) return; // en az biri kalsın
                setState(() => _arabic = !_arabic);
              }),
              const SizedBox(width: 8),
              _toggle('Meal', _meal, () {
                if (_meal && !_arabic) return;
                setState(() => _meal = !_meal);
              }),
              const Spacer(),
              TextButton(
                onPressed: () => shareText(context, _text),
                child: const Text('Metin olarak', style: TextStyle(color: RC.bronzeText, fontSize: 13.5)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Semantics(
              button: true,
              label: 'Görsel olarak paylaş',
              child: GestureDetector(
                onTap: _shareImage,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE6C35A), Color(0xFFC29A2C)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8A6414)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.ios_share, size: 18, color: Color(0xFF1D1406)),
                    const SizedBox(width: 6),
                    Text(_sharing ? 'Hazırlanıyor…' : 'Paylaş',
                        style: const TextStyle(color: Color(0xFF1D1406), fontSize: 15.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _toggle(String label, bool on, VoidCallback onTap) => Semantics(
        button: true,
        toggled: on,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: on ? RC.bronze : null,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: on ? RC.bronzeBorder : RC.gold(0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(on ? Icons.check : Icons.add, size: 15, color: on ? RC.bronzeText : _cream),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(color: on ? RC.bronzeText : _cream, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

/// Paylaşılan kartın kendisi (4:5): koyu yeşil zemin, altın çerçeve; ayet, meal, kaynak ve altta Ezan Saati logosu.
class AyahShareCard extends StatelessWidget {
  final String? arabic;
  final String? meal;
  final String reference;

  const AyahShareCard({super.key, this.arabic, this.meal, required this.reference});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final u = w / 360; // tasarım birimi: 360 genişliğe göre
      const gold = Color(0xFFD8B45A);
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.1,
            colors: [Color(0xFF0F4A33), Color(0xFF062618), Color(0xFF021309)],
            stops: [0, 0.6, 1],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(12 * u),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: gold.withValues(alpha: 0.85), width: 1.4 * u),
              borderRadius: BorderRadius.circular(10 * u),
            ),
            child: Padding(
              padding: EdgeInsets.all(4 * u),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: gold.withValues(alpha: 0.35), width: 0.8 * u),
                  borderRadius: BorderRadius.circular(7 * u),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16 * u, 14 * u, 16 * u, 10 * u),
                  child: Column(children: [
                    OrnamentStar(color: gold, lineWidth: 60 * u),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: w - 88 * u,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              if (arabic != null)
                                Text(
                                  arabic!,
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                      fontFamily: kQuranFont,
                                      fontSize: 21 * u,
                                      height: 1.9,
                                      color: const Color(0xFFF6E7B8)),
                                ),
                              if (arabic != null && meal != null)
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8 * u),
                                  child: Container(height: 1 * u, width: 70 * u, color: gold.withValues(alpha: 0.6)),
                                ),
                              if (meal != null)
                                Text(
                                  '“$meal”',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14 * u, height: 1.5, color: Colors.white),
                                ),
                              SizedBox(height: 10 * u),
                              Text(reference,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12 * u, fontWeight: FontWeight.w700, color: const Color(0xFFE6C35A))),
                              if (meal != null)
                                Text('Meal: Ruvvâd Tercüme Merkezi',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 8.5 * u, color: const Color(0xB3F3E4C0))),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    Image.asset('assets/images/logo_ezan_saati.webp', height: 44 * u, filterQuality: FilterQuality.high),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
