import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/premium.dart';
import '../widgets/gold_icon.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import '../services/app_theme.dart';

/// Premium tanıtım ve abonelik sayfası.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const _cream = Color(0xFFF3E4C0);
  static const _cream2 = Color(0xFFDCC697);
  bool _yearly = true;

  static const _features = [
    (Icons.insights, 'Takibim tam hâli', 'Aylık namaz tablosu, zikir geçmişi, kaza namazı ve kaza orucu takibi', false),
    (Icons.auto_stories, 'Hatim planı+', '7, 15, 60, 90 ve 180 günlük hatim planları', false),
    (Icons.volume_off_outlined, 'Cami modu', 'Namaz vakitlerinde telefon kendiliğinden sessize ya da titreşime geçer', false),
    (Icons.widgets_outlined, "Ana ekran widget'ları", "Kur'an çalar ve zikir sayacı widget'ı", false),
    (Icons.palette_outlined, 'Renk temaları', 'Zümrüt, Gece mavisi, Bordo ve Kahve', false),
  ];

  static const _free = [
    'Namaz vakitleri ve ezan bildirimleri',
    'Kıble ve cami bulucu',
    "Kur'an okuma ve 7 kârîden dinleme",
    'Dualar, hadisler, Esmâü’l-Hüsnâ, Ramazan',
  ];

  void _buy() => showNote(context, "Satın alma, uygulama Google Play'e yüklendiğinde açılacak");

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Premium.instance,
      builder: (context, _) {
        final active = Premium.instance.active;
        return PageShell(
          title: 'Premium',
          subtitle: 'İbadetlerinizi düzenli takip edin',
          background: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tc(0xFF062A1D), tc(0xFF010D08)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            _hero(active),
            const SizedBox(height: 14),
            for (final f in _features) _feature(f.$1, f.$2, f.$3, f.$4),
            const SizedBox(height: 14),
            if (!active) ...[
              _plan(
                yearly: true,
                title: 'Yıllık',
                price: '${Premium.yearlyPrice} / yıl',
                note: 'Ayda ${Premium.yearlyPerMonth} · ilk ${Premium.trialDays} gün ücretsiz',
                badge: '%50 avantajlı',
              ),
              const SizedBox(height: 8),
              _plan(yearly: false, title: 'Aylık', price: '${Premium.monthlyPrice} / ay', note: 'İstediğiniz ay bırakın'),
              const SizedBox(height: 14),
              _cta(),
              const SizedBox(height: 8),
              Text(
                _yearly
                    ? 'Deneme bitince yıllık ${Premium.yearlyPrice} alınır. Deneme süresinde iptal ederseniz ücret alınmaz. '
                        "Aboneliği istediğiniz zaman Google Play › Abonelikler'den iptal edebilirsiniz."
                    : "Her ay ${Premium.monthlyPrice} alınır. Aboneliği istediğiniz zaman Google Play › Abonelikler'den "
                        'iptal edebilirsiniz.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _cream2, fontSize: 11.5, height: 1.4),
              ),
              TextButton(
                onPressed: _buy,
                child: const Text('Satın alımları geri yükle', style: TextStyle(color: RC.bronzeText, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 6),
            _freeBox(),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              _testSwitch(active),
            ],
          ],
        );
      },
    );
  }

  Widget _hero(bool active) => Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tc(0xFF0E3A29), tc(0xFF04190F)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: RC.gold(0.8), width: 1.3),
        ),
        child: Column(children: [
          const GoldIcon(Icons.workspace_premium, size: 46),
          const SizedBox(height: 6),
          const Text('Ezan Saati Premium',
              style: TextStyle(color: _cream, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            active
                ? 'Premium açık. Desteğiniz için teşekkür ederiz.'
                : 'Namaz, zikir, oruç ve hatim takibinizi eksiksiz tutun; uygulamanın gelişmesine destek olun.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _cream2, fontSize: 13.5, height: 1.4),
          ),
        ]),
      );

  Widget _feature(IconData icon, String title, String text, bool soon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tc(0xFF0B3325),
              border: Border.all(color: RC.gold(0.6)),
            ),
            child: Icon(icon, size: 19, color: RC.bronzeText),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(title, style: const TextStyle(color: _cream, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                if (soon) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: RC.gold(0.55)),
                    ),
                    child: const Text('Yakında', style: TextStyle(color: _cream2, fontSize: 10.5)),
                  ),
                ],
              ]),
              Text(text, style: const TextStyle(color: _cream2, fontSize: 12.5, height: 1.35)),
            ]),
          ),
        ]),
      );

  Widget _plan({required bool yearly, required String title, required String price, required String note, String? badge}) {
    final on = _yearly == yearly;
    return Semantics(
      button: true,
      selected: on,
      label: '$title abonelik, $price',
      child: GestureDetector(
        onTap: () => setState(() => _yearly = yearly),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: on ? tc(0xFF123F2D) : tc(0xFF051C13),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? const Color(0xFFE6C35A) : RC.gold(0.35), width: on ? 2 : 1),
          ),
          child: Row(children: [
            Icon(on ? Icons.radio_button_checked : Icons.radio_button_off,
                color: on ? const Color(0xFFE6C35A) : _cream2, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(title, style: const TextStyle(color: _cream, fontSize: 16, fontWeight: FontWeight.w700)),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(gradient: RC.bronze, borderRadius: BorderRadius.circular(99)),
                      child: Text(badge,
                          style: const TextStyle(color: RC.bronzeText, fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
                Text(note, style: const TextStyle(color: _cream2, fontSize: 12)),
              ]),
            ),
            Text(price, style: const TextStyle(color: _cream, fontSize: 14.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _cta() => Semantics(
        button: true,
        child: GestureDetector(
          onTap: _buy,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEFD06A), Color(0xFFC29A2C)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8A6414)),
              boxShadow: const [BoxShadow(color: Color(0x55C29A2C), blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: Text(
              _yearly ? '${Premium.trialDays} gün ücretsiz başla' : 'Aylık abone ol',
              style: const TextStyle(color: Color(0xFF1D1406), fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );

  Widget _freeBox() => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: tc(0xFF041710),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RC.gold(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Her zaman ücretsiz',
              style: TextStyle(color: RC.bronzeText, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
          const SizedBox(height: 6),
          for (final t in _free)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                const Icon(Icons.check, size: 16, color: RC.bronzeText),
                const SizedBox(width: 6),
                Expanded(child: Text(t, style: const TextStyle(color: _cream2, fontSize: 13))),
              ]),
            ),
        ]),
      );

  Widget _testSwitch(bool active) => Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x66FFFFFF)),
        ),
        child: Row(children: [
          const Expanded(
            child: Text('Test: Premium açık (yalnız deneme sürümünde görünür)',
                style: TextStyle(color: _cream2, fontSize: 12.5)),
          ),
          Switch(
            value: active,
            activeThumbColor: RC.bronzeText,
            activeTrackColor: const Color(0xFF6E5114),
            onChanged: Premium.instance.setTest,
          ),
        ]),
      );
}
