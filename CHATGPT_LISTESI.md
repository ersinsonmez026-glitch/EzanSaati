# ChatGPT'den Alınacaklar

Uygulamanın sonunda tek seferde hazırlatılacak görseller ve içerikler.
Her madde bitince [x] yapılır. Görsellerde yazı ve filigran OLMAYACAK (filigranı uygulama ekler).

## 1. Simge seti (tüm uygulama) — 28 Eylül 2026 güncel
Uygulamadaki simgeler şu an Flutter'ın standart çizgi simgeleri (Material); emoji yok. Hepsi aynı elden çıkmış,
premium bir sete geçirilecek. Tüm simgeler TEK SETTE ve AYNI TARZDA hazırlanmalı:

- Tarz: koyu yeşil (#0B3F2B) zemin üzerinde altın (#D4AF37 → #F3DC97 geçişli) ince kabartma çizgi; krem (#F3ECD9)
  vurgu; hafif İslami geometrik detay; emoji, çizgi film, renkli/oyuncak görünüm YOK.
- Teslim: her simge ayrı, 512×512 şeffaf PNG (ayrıca tek sayfada hepsinin önizlemesi). Yazı, çerçeve, filigran yok.
- Aynı çizgi kalınlığı, aynı ışık yönü (sol üst), aynı köşe yuvarlaklığı; küçük boyutta (24 px) da okunaklı.

### 1a. Ana ekran tuşları (12) — kart görselleri hazır; bu simgeler Krem/Yeşil tuş görünümü ve sayfa başlıkları için
- [ ] Namaz Vakitleri — saat kadranı, üstünde küçük hilal
- [ ] Sureler — rahle üzerinde açık Kur'an
- [ ] Dualar — açık dua eden eller
- [ ] Zikir Sayacı — tesbih (33 tane, püsküllü)
- [ ] Kıble Bulucu — pusula, ibrenin ucunda Kâbe
- [ ] Cami Bulucu — konum iğnesi içinde cami silueti
- [ ] Dua Çemberi — halka şeklinde birbirine bağlı kişiler / dua eden eller çemberi
- [ ] Hadisler — kapalı kitap üzerinde mühür / hat süsü
- [ ] Ramazan — Ramazan feneri, yanında hilal
- [ ] Namaz Öğren — seccade üzerinde namaz kılan figür silueti
- [ ] Dini Mesajlar — mühürlü zarf
- [ ] Ayarlar — İslami desenli dişli

### 1b. Namaz vakitleri (6)
- [ ] İmsak (hilal + yıldız, şafak çizgisi) · Güneş (ufuktan doğan güneş) · Öğle (tepe güneşi)
- [ ] İkindi (alçalmış güneş) · Akşam (batan güneş) · Yatsı (hilal)

### 1c. Sayfa içi genel simgeler
- [ ] Konum iğnesi, konumumu bul (hedef), takvim, hicrî takvim (hilalli takvim), kandil (asılı kandil lambası),
      bayram (cami kubbesi), kadir gecesi (yıldız), bildirim (çan), kum saati, onay rozeti
- [ ] Favori (kalp dolu/boş), kopyala, paylaş, sesli dinle (kulaklık), oynat/duraklat, önceki/sonraki,
      arama (büyüteç), geri al, sıfırla, titreşim, kapat, bilgi, uyarı
- [ ] Dua Çemberi: kişi ekle, kişi çıkar, kişi grubu, WhatsApp tarzı konuşma balonu, bağlantı (link), onaylı rozet
- [ ] Namaz Öğren: su damlası (abdest), seccade

## 1d. Ana ekran Ramazan kartı (isteğe bağlı yenileme)
Mevcut gece mavisi görsel uygulamada krem-bronz tona çevrildi (assets/images/tiles/ramazan.jpg). Daha iyisi istenirse:
- [ ] Ramazan kartı: krem ağırlıklı, zarif, az renkli; cami + mahya ("Hoş geldin ya şehri Ramazan") ya da Ramazan
      feneri; diğer 11 kartla aynı çekim tarzı (sıcak taş zemin, yumuşak ışık, bronz/altın detay, koyu yeşil vurgu).
      600×508 veya daha büyük aynı oran, yazısız (mahya yazısı hariç).

## 2. Dini Mesajlar içeriği (ZIP)
- [ ] Kategori klasörleri: cuma, kandil, ramazan, bayram, sabah, dua
- [ ] Her kategoride en az 10 kare (1080x1080) görsel, yazısız, sakin ışıklı, farklı renk ve konular
- [ ] Her klasörde mesajlar.csv: gorsel;baslik;mesaj;sure;ayet (en az 25 mesaj; ayetli mesajlarda sadece
      sure adı ve ayet numarası, ayet metni yazılmayacak; hadis metni yazılmayacak)

## 3. Başlık ve ana ekran görselleri (yeni kimlik)
- [ ] Başlık arka planı, gündüz + gece (3:1, 1800x600, aynı manzara, yazısız, logosuz)
- [ ] Ana ekran arka planı, gündüz + gece (16:9, 1920x1080, aynı manzara)
- [ ] Logonun sadece sembol hâli (hilal + cami, yazılı şerit yok), gerçek şeffaf PNG
- [ ] Allah levhası ve tam logo gerçek şeffaf PNG olarak (damalı desen resmin içinde olmasın)

## 4. İsteğe bağlı
- [ ] Namaz Öğren: aynı 12 duruşun tesettürlü kadın figürüyle hazırlanmış sürümü (uzun seccade, aynı tarz)
