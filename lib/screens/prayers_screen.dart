import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/cards.dart';
import '../widgets/page_shell.dart';

/// Kur'an-ı Kerim'den bir dua.
class _Dua {
  final String title;
  final String arabic;
  final String reading; // okunuşu
  final String meaning; // anlamı
  final String source;

  const _Dua(this.title, this.arabic, this.reading, this.meaning, this.source);
}

// Kur'an'daki dualar. Anlamlar Diyanet meali esas alınarak sadeleştirilmiştir.
// Yayından önce metinlerin bir kez daha kontrol edilmesi önerilir.
const List<_Dua> _duas = [
  _Dua(
    'Dünya ve Ahiret Duası',
    'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
    "Rabbenâ âtinâ fi'd-dünyâ haseneten ve fi'l-âhireti haseneten ve kınâ azâbe'n-nâr.",
    'Rabbimiz! Bize dünyada da iyilik ver, ahirette de iyilik ver ve bizi ateş azabından koru.',
    'Bakara Suresi, 201. ayet',
  ),
  _Dua(
    'İlim Duası',
    'رَبِّ زِدْنِي عِلْمًا',
    'Rabbi zidnî ilmâ.',
    'Rabbim! İlmimi artır.',
    'Tâhâ Suresi, 114. ayet',
  ),
  _Dua(
    'Anne-Baba İçin Dua',
    'رَبَّنَا اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ',
    "Rabbenağfir lî ve li-vâlideyye ve li'l-mü'minîne yevme yekûmü'l-hisâb.",
    'Rabbimiz! Hesap gününde beni, anamı-babamı ve bütün müminleri bağışla.',
    'İbrâhîm Suresi, 41. ayet',
  ),
  _Dua(
    'Hidayette Sebat Duası',
    'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا وَهَبْ لَنَا مِنْ لَدُنْكَ رَحْمَةً إِنَّكَ أَنْتَ الْوَهَّابُ',
    "Rabbenâ lâ tuziğ kulûbenâ ba'de iz hedeytenâ ve heb lenâ min ledünke rahmeh, inneke ente'l-vehhâb.",
    'Rabbimiz! Bizi doğru yola ilettikten sonra kalplerimizi kaydırma. Bize katından rahmet bağışla. '
        'Şüphesiz sen, lütfu en bol olansın.',
    'Âl-i İmrân Suresi, 8. ayet',
  ),
  _Dua(
    'Aile Duası',
    'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا',
    "Rabbenâ heb lenâ min ezvâcinâ ve zürriyyâtinâ kurrate a'yunin vec'alnâ li'l-müttakîne imâmâ.",
    'Rabbimiz! Bize gözümüzü aydınlatacak eşler ve nesiller bağışla ve bizi takva sahiplerine önder kıl.',
    'Furkân Suresi, 74. ayet',
  ),
  _Dua(
    'Tövbe Duası',
    'رَبَّنَا ظَلَمْنَا أَنْفُسَنَا وَإِنْ لَمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ الْخَاسِرِينَ',
    "Rabbenâ zalemnâ enfüsenâ ve in lem tağfir lenâ ve terhamnâ lenekûnenne mine'l-hâsirîn.",
    'Rabbimiz! Biz kendimize zulmettik. Eğer bizi bağışlamaz ve bize merhamet etmezsen '
        'mutlaka ziyana uğrayanlardan oluruz.',
    "A'râf Suresi, 23. ayet",
  ),
];

/// Dualar sayfası (okuma sayfası: krem kâğıt).
class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    // Günün duası: her gün sıradaki dua
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    _index = dayOfYear % _duas.length;
  }

  void _step(int delta) {
    setState(() => _index = (_index + delta) % _duas.length);
  }

  @override
  Widget build(BuildContext context) {
    final p = Parchment.of(context);
    final dua = _duas[(_index + _duas.length) % _duas.length];
    final isToday = _index ==
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays % _duas.length;

    return PageShell(
      title: 'Dualar',
      subtitle: 'Rabbimiz, dualarımızı kabul eyle...',
      children: [
        ParchmentCard(
          child: Column(
            children: [
              Row(
                children: [
                  _arrow(Icons.chevron_left, () => _step(-1), p),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          isToday ? 'Günün Duası' : 'Kur\'an\'dan Dualar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'serif',
                          ),
                        ),
                        Text(
                          dua.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.inkSoft, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  _arrow(Icons.chevron_right, () => _step(1), p),
                ],
              ),
              GoldDivider(color: p.line),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  dua.arabic,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 26,
                    height: 1.9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dua.reading,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.inkSoft, fontSize: 15, fontStyle: FontStyle.italic, height: 1.45),
              ),
              GoldDivider(color: p.line),
              Text(
                '“${dua.meaning}”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.ink,
                  fontSize: 18,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 10),
              Text(dua.source, style: TextStyle(color: p.inkSoft, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Kur\'an\'dan Dualar',
          style: TextStyle(
            color: AppColors.goldLight,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'serif',
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _duas.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DuaTile(
              number: i + 1,
              dua: _duas[i],
              selected: i == _index,
              onTap: () => setState(() => _index = i),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Günlük, namaz, yolculuk ve diğer dua kategorileri bir sonraki güncellemede eklenecek.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap, Parchment p) {
    return Material(
      color: Colors.transparent,
      shape: CircleBorder(side: BorderSide(color: p.line)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: p.inkSoft),
        ),
      ),
    );
  }
}

class _DuaTile extends StatelessWidget {
  final int number;
  final _Dua dua;
  final bool selected;
  final VoidCallback onTap;

  const _DuaTile({
    required this.number,
    required this.dua,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Parchment.of(context);
    return Material(
      color: selected ? AppColors.gold : p.paperLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          onTap();
          // Seçilen duayı görmek için en üste kaydır
          Scrollable.maybeOf(context)?.position.animateTo(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.black : AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: selected ? AppColors.gold : const Color(0xFF8A6414),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dua.title,
                      style: TextStyle(color: p.ink, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(dua.source, style: TextStyle(color: p.inkSoft, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: selected ? Colors.black : const Color(0xFF8A6414)),
            ],
          ),
        ),
      ),
    );
  }
}
