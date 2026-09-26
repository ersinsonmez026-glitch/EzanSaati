import 'dart:async';

import 'package:flutter/material.dart';

import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../theme.dart';
import 'city_picker_screen.dart';

/// Günün namaz vakitleri + önümüzdeki 30 günün imsakiyesi.
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  Timer? _ticker;
  final _location = LocationStore.instance;

  // 30 günlük tablo her saniye yeniden hesaplanmasın diye saklanır.
  String? _tableKey;
  List<DayPrayerTimes> _table = const [];

  List<DayPrayerTimes> _monthDays(AppLocation loc, DateTime start) {
    final key = '${loc.lat},${loc.lng},${start.year}-${start.month}-${start.day}';
    if (key != _tableKey) {
      _tableKey = key;
      _table = [
        // Saat değişimi olan günlerde kaymasın diye takvim günüyle ilerle.
        for (var i = 0; i < 30; i++)
          PrayerCalc.forDay(loc, DateTime(start.year, start.month, start.day + i)),
      ];
    }
    return _table;
  }

  @override
  void initState() {
    super.initState();
    _location.addListener(_onChange);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onChange());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _location.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _changeCity() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CityPickerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final loc = _location.current;

    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      appBar: goldAppBar('Namaz Vakitleri', actions: [
        IconButton(
          tooltip: 'Şehir değiştir',
          icon: const Icon(Icons.location_on),
          onPressed: _changeCity,
        ),
      ]),
      body: loc == null ? _noLocation() : _content(loc),
    );
  }

  Widget _noLocation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, color: AppColors.gold, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Vakitleri gösterebilmek için önce şehrinizi seçin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _changeCity,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Şehir Seç'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AppLocation loc) {
    final now = DateTime.now();
    final status = PrayerCalc.status(loc, now);
    final today = status.today;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Üst bilgi kartı
        InkWell(
          onTap: _changeCity,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.name,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatDateTr(now)}, ${weekdayTr(now)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${status.next.name} vaktine kalan',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        formatDuration(status.remaining),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 2),
                  ),
                  child: const Icon(Icons.access_time_filled, color: AppColors.mint, size: 30),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Günün 6 vakti
        for (final slot in today.slots)
          _prayerRow(slot, isCurrent: slot.time == status.current.time),

        const SizedBox(height: 24),
        const Text(
          'Önümüzdeki 30 Gün',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'serif',
          ),
        ),
        const SizedBox(height: 8),
        _monthTable(loc, now),
        const SizedBox(height: 16),
        const Text(
          'Vakitler Diyanet İşleri Başkanlığı\'nın hesaplama yöntemiyle, internet '
          'bağlantısı gerektirmeden hesaplanır. Resmî takvimle 1-2 dakikalık fark olabilir.',
          style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _prayerRow(PrayerSlot slot, {required bool isCurrent}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.gold : AppColors.green,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: isCurrent ? 1 : 0.5)),
      ),
      child: Row(
        children: [
          Text(
            slot.name,
            style: TextStyle(
              color: isCurrent ? Colors.black : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'ŞU AN',
                style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          ],
          const Spacer(),
          Text(
            formatHm(slot.time),
            style: TextStyle(
              color: isCurrent ? Colors.black : AppColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthTable(AppLocation loc, DateTime now) {
    const headStyle = TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700);
    const cellStyle = TextStyle(color: Colors.white, fontSize: 12);
    final start = DateTime(now.year, now.month, now.day);

    Widget cell(String text, TextStyle style, {int flex = 2}) => Expanded(
          flex: flex,
          child: Text(text, textAlign: TextAlign.center, style: style),
        );

    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          cell('Tarih', headStyle, flex: 3),
          for (final n in PrayerCalc.names) cell(n, headStyle),
        ]),
      ),
    ];

    final days = _monthDays(loc, start);
    for (var i = 0; i < days.length; i++) {
      final t = days[i];
      final day = t.date;
      rows.add(Container(
        color: i.isEven ? Colors.white.withValues(alpha: 0.04) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          cell(formatShortDateTr(day), i == 0 ? headStyle : cellStyle, flex: 3),
          for (final s in t.slots) cell(formatHm(s.time), cellStyle),
        ]),
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.greenSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(children: rows),
    );
  }
}
