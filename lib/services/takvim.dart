import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';

/// Hicrî aylar (Diyanet yazımı).
const kHijriMonthsTr = [
  'Muharrem', 'Safer', 'Rebiülevvel', 'Rebiülahir', 'Cemaziyelevvel', 'Cemaziyelahir', //
  'Recep', 'Şaban', 'Ramazan', 'Şevval', 'Zilkade', 'Zilhicce',
];

/// Hicrî tarih (Ümmü'l-Kurâ hesabı). Diyanet takviminden bir gün farklı olabilir.
class HijriDate {
  final int day, month, year;
  const HijriDate(this.day, this.month, this.year);

  factory HijriDate.of(DateTime d) {
    final h = HijriCalendar.fromDate(DateTime(d.year, d.month, d.day));
    return HijriDate(h.hDay, h.hMonth, h.hYear);
  }

  String get monthName => kHijriMonthsTr[month - 1];

  @override
  String toString() => '$day $monthName $year';
}

/// Bir tarihin içinde bulunduğu hicrî ayın ilk günü (miladi).
DateTime hijriMonthStart(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return DateTime(day.year, day.month, day.day - HijriDate.of(day).day + 1);
}

/// Hicrî ayın gün sayısı (29 ya da 30).
int hijriMonthLength(DateTime monthStart) {
  var n = 1;
  while (n < 31 && HijriDate.of(DateTime(monthStart.year, monthStart.month, monthStart.day + n)).day != 1) {
    n++;
  }
  return n;
}

/// Dinî gün (Diyanet takvimi).
class ReligiousDay {
  final DateTime date;
  final String name;
  final String hijri;
  final String icon; // moon, lamp, star, mosque
  const ReligiousDay(this.date, this.name, this.hijri, this.icon);
}

/// Miladi takvimde gösterilen gün: r = resmî tatil, h = yarım gün (arife), d = dinî gün.
class CalendarDay {
  final DateTime date;
  final String name;
  final String kind;
  const CalendarDay(this.date, this.name, this.kind);

  bool get holiday => kind == 'r';
  bool get half => kind == 'h';
  bool get religious => kind == 'd';
}

/// assets/data/takvim.json (onaylı Namaz Vakitleri önizlemesinden).
class TakvimData {
  final List<ReligiousDay> religious;
  final List<CalendarDay> days;
  const TakvimData(this.religious, this.days);

  static Future<TakvimData>? _loading;
  static Future<TakvimData> load() => _loading ??= rootBundle.loadString('assets/data/takvim.json').then(parse);

  static TakvimData parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    DateTime d(Object? s) => DateTime.parse(s as String);
    return TakvimData(
      [
        for (final e in j['dini'] as List)
          ReligiousDay(d(e['tarih']), e['ad'] as String, e['hicri'] as String, e['simge'] as String),
      ],
      [for (final e in j['miladi'] as List) CalendarDay(d(e['tarih']), e['ad'] as String, e['tur'] as String)],
    );
  }

  Set<DateTime> get religiousDates => {for (final e in religious) e.date};

  List<CalendarDay> on(DateTime day) => [
        for (final e in days)
          if (e.date.year == day.year && e.date.month == day.month && e.date.day == day.day) e,
      ];

  /// Bugünden itibaren (bugün dahil) yaklaşan dinî günler.
  List<ReligiousDay> upcomingReligious(DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    return [
      for (final e in religious)
        if (!e.date.isBefore(t)) e
    ];
  }
}
