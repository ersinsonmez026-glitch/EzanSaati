import 'package:flutter/material.dart';

import '../widgets/group_card.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Ayarlar > Hakkında ve Gizlilik: içerik kaynakları ve verilerin nerede tutulduğu.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final pal = PagePalette.current();
    const gap = SizedBox(height: 10);
    Widget para(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Text(t, style: TextStyle(color: pal.ink, fontSize: 13.5, height: 1.5)),
        );
    return PageShell(
      title: 'Hakkında',
      background: pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        GroupCard(
          pal: pal,
          icon: Icons.privacy_tip_outlined,
          title: 'Gizlilik',
          children: [
            para('Ezan Saati hesap açmanızı istemez, reklam ve kullanım takibi (analiz) içermez.'),
            para('Konum: Seçtiğiniz şehir ya da GPS konumunuz yalnızca bu telefonda saklanır. Namaz vakitleri, '
                'kıble ve takvim internetsiz olarak telefonda hesaplanır. Cami Bulucu açıldığında yakındaki camileri '
                'bulmak için konumunuz OpenStreetMap sunucusuna (Overpass) gönderilir; kimliğiniz gönderilmez.'),
            para('Zikir sayıları, favoriler, kaldığınız yer ve ayarlar yalnızca bu telefonda tutulur.'),
            para('Dua Çemberi: Ortak çemberler Google Firebase üzerinde anonim bir hesapla tutulur. Sunucuda çember '
                'adı, niyet, kişi adları ve okunan sayılar bulunur. Telefon numaraları sunucuya yazılmaz; davet '
                'eşleştirmesi için numaradan üretilen tek yönlü özet saklanır ve davet kabul edilince silinir. Rehber '
                'yalnızca davet edilecek kişiyi seçmek için kullanılır.'),
            para('Kur\'an sesleri internetten akışla çalınır (Islamic Network / alquran.cloud); bunun için hesap '
                'gerekmez ve kişisel bilgi gönderilmez.'),
          ],
        ),
        gap,
        GroupCard(
          pal: pal,
          icon: Icons.menu_book_outlined,
          title: 'Kaynaklar',
          children: [
            for (final (t, s) in const [
              ('Kur\'an-ı Kerim Arapça metni', 'Tanzil Projesi (CC BY 3.0)'),
              ('Türkçe meal', 'Ruvvâd Tercüme Merkezi, QuranEnc.com'),
              ('Kur\'an sesleri', 'Mişari Râşid el-Afâsî · Islamic Network / alquran.cloud'),
              ('Namaz vakitleri', 'Diyanet İşleri Başkanlığı hesaplama yöntemi (adhan kütüphanesi)'),
              ('Dinî günler', 'Diyanet İşleri Başkanlığı dinî günler takvimi'),
              ('Hicrî takvim', 'Ümmü\'l-Kurâ hesabı; Diyanet takviminden bir gün farklı olabilir'),
              ('Hadisler', 'HadeethEnc.com (Hadis Tercümeleri Ansiklopedisi), metinler değiştirilmeden'),
              ('Harita verisi', '© OpenStreetMap katkıcıları (ODbL)'),
              ('Arapça yazı tipi', 'Amiri (SIL Open Font License)'),
            ])
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t, style: TextStyle(color: pal.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(s, style: TextStyle(color: pal.ink2, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
          ],
        ),
        gap,
        SourceNote(pal: pal, text: 'Ezan Saati · Sürüm $version'),
      ],
    );
  }
}
