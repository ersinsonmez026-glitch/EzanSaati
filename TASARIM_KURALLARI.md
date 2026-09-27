# Tasarım Kuralları (v2)

Dua Zinciri sayfasında belirlendi; bütün sayfalar buna uyar. Flutter'a aktarırken de bu değerler kullanılır.

## Renkler (yeşil tema)
- Sayfa zemini: çok koyu yeşil, ortası hafif aydınlık — radyal geçiş `#06281C → #011810 → #000A06`
- Kart / tuş zemini: `#0A3525 → #01170F → #000C07` (yukarıdan aşağı)
- Kenar: altın `#D4AF37` (%60-75 opaklık), ince
- Metin: krem `#F3ECD9`, ikincil `#B9CDC2`, başlık altını `#F3D27A`
- Seçili durum: bronz `#6E5114 → #4A3508 → #2A1C03`, kenar `#F0C75E`, hafif altın ışıma, yazı `#FFE08A`
- Ana eylem düğmesi (Paylaş, Kabul et vb.): altın `#E6C35A → #C29A2C`, yazı koyu
- İlerleme çubuğu: `#C9922E → #F9C265 → #FFE3A0`; tamamlanan: yeşil `#1C7A4A → #3FC57C`
- Liste içi kâğıt alanı: krem `#FDF0D2 → #F3DFB4`, koyu mürekkep `#2A1F10`

## Krem tema (gündüz)
Aynı düzen; zemin krem kâğıt. Seçili durum ve altın ayrıntılar yeşil temayla aynı kalır.

## Tuşlar
- Kabartma: üstte ince parlaklık (iç gölge beyazımsı 1 px), altta koyu iç gölge, dışta yumuşak gölge
- Köşeler 12-16 px yuvarlak

## Simgeler
- Emoji kullanılmaz. Tek tip altın simge seti (şimdilik çizim; sonra ChatGPT simge seti, bkz. CHATGPT_LISTESI.md)

## Başlık
- Ana ekran hariç tüm sayfalarda ortada logo (gündüz krem, gece yeşil zeminli), köşelerde levhalar

## Süsler
- Önemli kartlarda çift çerçeve ve altın köşe süsleri; başlık üstünde küçük "✦ ❖ ✦" süsü
- Büyük başlıklar altın geçişli yazı
- Başlık logosu küçük tutulur (yaklaşık 50 px), arkadaki cami kubbesi görünür kalmalı

## Sayaçların birbirine bağlanması
- Dua Zinciri'nde okunan her şey (salavat, Yasin, İhlas, istiğfar, hatim cüzü) Online Dua toplamına da eklenir.
- Zikir Sayacı'nda sayılan salavat / istiğfar vb., kişinin aynı türde aktif zincir görevi varsa o göreve ve
  Online Dua toplamına otomatik eklenir. Kapatma seçeneği yok: Zikir Sayacı'nda çekilen her zikir
  (salavat, istiğfar, tesbihat vb.) kimlik bilgisi olmadan genel toplama her zaman eklenir.

## Cami Bulucu haritası
- Uygulamada Google Haritalar'ın uydu (karma) görünümü kullanılacak (mobil harita gösterimi ücretsiz; API anahtarı gerekir).
- Camiler OpenStreetMap'ten, yol tarifi ücretsiz rota servisinden (OSRM / OpenRouteService) alınıp bizim tasarımımızla gösterilecek.
