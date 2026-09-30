// Takvim günü hesapları. Yaz saati geçişi olan ülkelerde bir gün 23 ya da 25 saat sürer;
// bu yüzden gün farkı saat üzerinden değil, UTC tarihleri üzerinden hesaplanır.

/// [from] ile [to] arasındaki takvim günü farkı.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Bir önceki takvim gününün başı.
DateTime previousDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);
