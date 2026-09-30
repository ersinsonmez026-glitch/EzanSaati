import 'package:flutter/material.dart';

import '../screens/premium_screen.dart';
import '../services/premium.dart';
import 'gold_icon.dart';
import 'page_shell.dart';
import 'reading_ui.dart';

/// Altın zeminli küçük "Premium" rozeti.
class PremiumChip extends StatelessWidget {
  final bool lock;
  const PremiumChip({super.key, this.lock = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
        decoration: BoxDecoration(
          gradient: RC.bronze,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: RC.bronzeBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(lock ? Icons.lock : Icons.workspace_premium, size: 12, color: RC.bronzeText),
          const SizedBox(width: 3),
          const Text('Premium', style: TextStyle(color: RC.bronzeText, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Premium sayfasını açar.
Future<void> openPremium(BuildContext context) =>
    Navigator.of(context).push(AppRoute(builder: (_) => const PremiumScreen()));

/// Premium açıksa true; değilse Premium sayfasını açar ve false döner.
bool requirePremium(BuildContext context) {
  if (Premium.instance.active) return true;
  openPremium(context);
  return false;
}

/// Premium değilse içeriği soluk ve dokunulmaz gösterir, üstüne "Premium ile açılır" kartı koyar.
class PremiumLocked extends StatelessWidget {
  final Widget child;
  final String text;

  const PremiumLocked({super.key, required this.child, required this.text});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Premium.instance,
        builder: (context, _) {
          if (Premium.instance.active) return child;
          final pal = PagePalette.current();
          return Stack(children: [
            IgnorePointer(child: Opacity(opacity: 0.28, child: ExcludeSemantics(child: child))),
            Positioned.fill(
              child: Center(
                child: Semantics(
                  button: true,
                  label: '$text. Premium ile açılır',
                  child: GestureDetector(
                    onTap: () => openPremium(context),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: pal.paper,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: RC.gold(0.8), width: 1.2),
                        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 4))],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const PremiumChip(lock: true),
                        const SizedBox(height: 6),
                        Text(text,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: pal.ink, fontSize: 14, fontWeight: FontWeight.w700, height: 1.3)),
                        const SizedBox(height: 4),
                        Text('${Premium.trialDays} gün ücretsiz deneyin',
                            style: TextStyle(color: pal.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]);
        },
      );
}

/// Ayarlar'ın başındaki Premium şeridi.
class PremiumBanner extends StatelessWidget {
  const PremiumBanner({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Premium.instance,
        builder: (context, _) {
          final on = Premium.instance.active;
          return Semantics(
            button: true,
            label: 'Ezan Saati Premium',
            child: GestureDetector(
              onTap: () => openPremium(context),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0E3A29), Color(0xFF03170F)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RC.gold(0.8), width: 1.2),
                ),
                child: Row(children: [
                  const GoldIcon(Icons.workspace_premium, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Ezan Saati Premium',
                          style: TextStyle(color: Color(0xFFF3E4C0), fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(on ? 'Premium açık' : '${Premium.trialDays} gün ücretsiz deneyin',
                          style: const TextStyle(color: Color(0xFFDCC697), fontSize: 12.5)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: RC.bronzeText),
                ]),
              ),
            ),
          );
        },
      );
}
