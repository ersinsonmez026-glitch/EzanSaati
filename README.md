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
| Dualar (106 dua, günün duası, arama, favoriler) | ✅ |
| Namaz Öğren (rekât rekât anlatım, duruş görselleri, abdest/gusül/teyemmüm) | ✅ |
| Ezan sesi / bildirim | ⏳ sırada |
| Dini Mesajlar (30 mesaj, günün mesajı, arama, kategori, favori, görsel paylaşma) | ✅ |
| Ramazan (geri sayım, şehre göre imsakiye, niyet ve dualar, 2027 önemli günler) | ✅ |
| Hadisler (kaynak doğrulaması bekliyor), Dua Çemberi, İlahiler, Dini Hikâyeler | ⏳ |

## Klasörler

- `lib/screens/` – her sayfa ayrı dosya
- `lib/services/` – vakit hesaplama, konum, pusula
- `lib/data/cities.dart` – 81 ilin koordinatları
- `lib/data/namaz_ogren.dart` – Namaz Öğren anlatımı
- `assets/data/` – Kur'an metni ve meali, dualar, namaz duaları
- `assets/fonts/` – Arapça yazı tipleri (Amiri, Amiri Quran; SIL OFL)
- `assets/images/` – tuş ve arka plan görselleri
- `android/app/src/main/kotlin/.../MainActivity.kt` – Android pusula sensörü
