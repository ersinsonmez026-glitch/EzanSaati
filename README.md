# Ezan Saati

Namaz vakitleri, Kıble bulucu, sureler, dualar ve daha fazlası. Flutter ile yazıldı (Android, ileride iOS).

## Çalıştırma

1. GitHub'da **Code → Download ZIP** ile son hâli indir, klasörü çıkar.
2. Klasörü VS Code ile aç.
3. Telefonu USB ile bağla (Geliştirici seçenekleri → USB hata ayıklama açık olmalı).
4. Terminale yaz:

```
flutter pub get
flutter run
```

## Neler hazır

| Bölüm | Durum |
|---|---|
| Ana ekran, 12 tuş, canlı geri sayım | ✅ |
| Namaz Vakitleri (Diyanet yöntemi, internetsiz, 30 günlük liste) | ✅ |
| Şehir seçimi (81 il) + GPS ile konum | ✅ |
| Kıble Bulucu (telefon pusulası, Android) | ✅ |
| Cami Bulucu (harita uygulamasını açar) | ✅ |
| Zikir Sayacı | ✅ (basit) |
| Ayarlar | ✅ (temel) |
| Sureler (114 sure, Arapça + meal, günün ayeti, favoriler, kaldığın yer) | ✅ |
| Sesli sûre okuma (114 sûre, Mişari Râşid el-Afâsî; internetten akış, uygulamaya gömülü değil) | ✅ |
| Dualar (106 dua, günün duası, arama, favoriler) | ✅ |
| Namaz Öğren (rekât rekât anlatım, duruş görselleri, abdest/gusül/teyemmüm) | ✅ |
| Ezan sesi / bildirim | ⏳ sırada |
| Dini Mesajlar (30 mesaj, günün mesajı, arama, kategori, favori, görsel paylaşma) | ✅ |
| Ramazan (geri sayım, şehre göre imsakiye, niyet ve dualar, 2027 önemli günler) | ✅ |
| Dini Hikâyeler (Kur'an'daki 9 kıssa, Ruvvâd meali, kaynak gösterimi) | ✅ |
| Bebek İsimleri (Kur'an'da geçen 32 isim ayetleriyle, 18 İslami isim; arama ve favori) | ✅ |
| Dua Çemberi – 1. aşama (çember kurma, rehberden kişi seçme, paylaştırma, WhatsApp daveti; veriler telefonda) | ✅ |
| Dua Çemberi – 2. aşama (Firebase: uygulama içi davet/kabul/ret, ortak ilerleme ve tamamlanma) | ✅ (konsol ayarı gerekli, aşağıda) |
| Dua Çemberi – Online Dua genel toplamı, uygulama kapalıyken bildirim | ⏳ |
| Hadisler (kaynak doğrulaması bekliyor), İlahiler (eser listesi bekliyor) | ⏳ |

## Klasörler

- `lib/screens/` – her sayfa ayrı dosya
- `lib/services/` – vakit hesaplama, konum, pusula
- `lib/data/cities.dart` – 81 ilin koordinatları
- `lib/data/namaz_ogren.dart` – Namaz Öğren anlatımı
- `assets/data/` – Kur'an metni ve meali, dualar, namaz duaları
- `assets/fonts/` – Arapça yazı tipleri (Amiri, Amiri Quran; SIL OFL)
- `assets/images/` – tuş ve arka plan görselleri
- `android/app/src/main/kotlin/.../MainActivity.kt` – Android pusula sensörü

## Dua Çemberi — Firebase (ücretsiz Spark planı)

Paket adı: `com.ezansaati.app`. Yapılandırma: `android/app/google-services.json`,
`lib/firebase_options.dart`. Yalnızca **Anonim Giriş** ve **Cloud Firestore** kullanılır
(Analytics, Messaging, Functions, Storage eklenmedi).

Firebase konsolunda bir kez yapılacaklar:

1. **Authentication → Sign-in method → Anonymous**: etkinleştir.
2. **Firestore Database → Create database** (production mode, ör. `eur3` / `europe-west`).
3. **Firestore → Rules**: `firestore.rules` dosyasının içeriğini yapıştırıp yayınla
   (ya da `firebase deploy --only firestore`).
4. **Firestore → Indexes → Single field → Add exemption**: koleksiyon grubu `members`,
   alan `phoneHash`, *Collection group* kapsamında artan (Ascending) dizin
   (`firebase deploy --only firestore` bunu `firestore.indexes.json`'dan kurar).

Gizlilik: telefon numaraları sunucuya yazılmaz; davet eşleştirmesi için numaradan üretilen
tek yönlü özet (SHA-256) saklanır ve davet kabul edilince silinir. Davet kodu yalnız WhatsApp
mesajında paylaşılır.

Testler: `flutter test` (eşitleme akışı `test/circle_sync_test.dart`), güvenlik kuralları
emülatörde: `cd test_rules && npm install && npm test` (Java gerekir).

## Sesli sûre okuma — ses kaynağı

Sûreler internetten akışla çalınır; APK'ya ses dosyası eklenmez (`lib/services/quran_audio.dart`).

- Kârî: Mişari Râşid el-Afâsî (murattal), 128 kbps; 114 sûrenin tamamı erişilebilir (doğrulandı).
- Kaynak: Islamic Network / Al Quran Cloud ses CDN'i — https://alquran.cloud/cdn
- Kullanım şartları (https://alquran.cloud/terms-and-conditions, 14 Haziran 2026): kârîler
  kayıtları ücretsiz, ticari olmayan yeniden dağıtım için lisanslamıştır; "kişisel ve eğitim
  amaçlı akış, gömme ve indirme" serbesttir. Telif kârîye aittir; kârî kaldırılmasını isteyebilir.
- Değerlendirilip kullanılmayanlar: Diyanet (kamuya açık kullanım şartı/izin bulunamadı),
  Quran.com (yalnız kişisel kullanım; dağıtım için yazılı izin gerekir), mp3quran / EveryAyah /
  QuranicAudio (açık kullanım şartı yok).
