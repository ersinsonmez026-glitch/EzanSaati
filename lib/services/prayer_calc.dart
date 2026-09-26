import 'package:adhan/adhan.dart';

import 'location_store.dart';

/// Tek bir vakit: adı ve saati.
class PrayerSlot {
  final String name;
  final DateTime time;

  const PrayerSlot(this.name, this.time);
}

/// Bir günün 6 vakti.
class DayPrayerTimes {
  final DateTime date;
  final List<PrayerSlot> slots; // İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı

  const DayPrayerTimes(this.date, this.slots);
}

/// Şu anki vakit, sıradaki vakit ve kalan süre.
class PrayerStatus {
  final PrayerSlot current;
  final PrayerSlot next;
  final Duration remaining;
  final DayPrayerTimes today;

  const PrayerStatus({
    required this.current,
    required this.next,
    required this.remaining,
    required this.today,
  });
}

/// Namaz vakitlerini internetsiz hesaplar.
/// Diyanet İşleri Başkanlığı yöntemi: İmsak 18°, Yatsı 17°, Şafii ikindi,
/// temkin farkları (Güneş -7, Öğle +5, İkindi +4, Akşam +7 dakika).
class PrayerCalc {
  static const List<String> names = ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];

  static DayPrayerTimes forDay(AppLocation loc, DateTime day) {
    final params = CalculationMethod.turkey.getParameters();
    params.madhab = Madhab.shafi;
    final pt = PrayerTimes(
      Coordinates(loc.lat, loc.lng),
      DateComponents(day.year, day.month, day.day),
      params,
    );
    final times = [pt.fajr, pt.sunrise, pt.dhuhr, pt.asr, pt.maghrib, pt.isha];
    return DayPrayerTimes(
      DateTime(day.year, day.month, day.day),
      [for (var i = 0; i < 6; i++) PrayerSlot(names[i], times[i])],
    );
  }

  static PrayerStatus status(AppLocation loc, DateTime now) {
    final today = forDay(loc, now);
    final slots = today.slots;

    // Gece yarısından imsaka kadar: önceki günün yatsısı içindeyiz.
    if (now.isBefore(slots.first.time)) {
      final yesterday = forDay(loc, now.subtract(const Duration(days: 1)));
      return PrayerStatus(
        current: yesterday.slots.last,
        next: slots.first,
        remaining: slots.first.time.difference(now),
        today: today,
      );
    }

    for (var i = 0; i < slots.length - 1; i++) {
      if (now.isBefore(slots[i + 1].time)) {
        return PrayerStatus(
          current: slots[i],
          next: slots[i + 1],
          remaining: slots[i + 1].time.difference(now),
          today: today,
        );
      }
    }

    // Yatsıdan sonra: sıradaki vakit yarının imsakı.
    final tomorrow = forDay(loc, now.add(const Duration(days: 1)));
    return PrayerStatus(
      current: slots.last,
      next: tomorrow.slots.first,
      remaining: tomorrow.slots.first.time.difference(now),
      today: today,
    );
  }

  /// Kâbe yönü (kuzeyden saat yönünde derece).
  static double qiblaDirection(AppLocation loc) {
    return Qibla(Coordinates(loc.lat, loc.lng)).direction;
  }
}

// ---------------------------------------------------------------------------
// Tarih / saat biçimlendirme (ek paket gerektirmeden Türkçe)
// ---------------------------------------------------------------------------

const _months = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];
const _weekdays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

String two(int n) => n.toString().padLeft(2, '0');

/// 18:22
String formatHm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

/// 01:24:36
String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return '${two(h)}:${two(m)}:${two(s)}';
}

/// 27 Eylül 2026
String formatDateTr(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Pazar
String weekdayTr(DateTime d) => _weekdays[d.weekday - 1];

/// 27 Eyl
String formatShortDateTr(DateTime d) => '${d.day} ${_months[d.month - 1].substring(0, 3)}';
