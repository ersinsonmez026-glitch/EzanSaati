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
| Sureler, Dualar, Namaz Öğren | 🟡 örnek içerik |
| Ezan sesi / bildirim | ⏳ sırada |
| Hadisler, Dini Mesajlar, Dua Çemberi, Ramazan | ⏳ |

## Klasörler

- `lib/screens/` – her sayfa ayrı dosya
- `lib/services/` – vakit hesaplama, konum, pusula
- `lib/data/cities.dart` – 81 ilin koordinatları
- `assets/images/` – tuş ve arka plan görselleri
- `android/app/src/main/kotlin/.../MainActivity.kt` – Android pusula sensörü
