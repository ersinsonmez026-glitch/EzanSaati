import 'dart:math';

import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../services/dhikr_store.dart';
import '../services/fasting_log.dart';
import '../services/hatim_plan.dart';
import '../services/prayer_log.dart';
import '../widgets/hatim_card.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'dhikr_screen.dart';
import 'fasting_tracker_screen.dart';

/// Takibim: namaz takibi (seri, haftalık tablo, ay görünümü, özel gün), zikir çekiliyorsa zikir
/// tablosu, oruç özeti ve kaza borcu. Kayıtlar yalnız bu telefonda tutulur.
class TrackingScreen extends StatefulWidget {
  /// Testler için saat; verilmezse gerçek saat.
  final DateTime Function()? clock;

  const TrackingScreen({super.key, this.clock});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  final _log = PrayerLog.instance;
  final _hatim = HatimPlan.instance;
  List<Surah> _surahs = const [];
  DhikrState? _dhikr;
  FastingLog? _fast;
  RamazanData? _ramazan;

  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _log.addListener(_refresh);
    _log.load();
    _hatim.addListener(_refresh);
    _hatim.load();
    QuranData.load().then((q) {
      if (mounted) setState(() => _surahs = q.surahs);
    });
    _loadOthers();
  }

  Future<void> _loadOthers() async {
    final d = await DhikrState.load();
    final f = await FastingLog.get();
    RamazanData? r;
    try {
      r = await RamazanData.load();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _dhikr = d;
        _fast = f;
        _ramazan = r;
      });
    }
  }

  @override
  void dispose() {
    _log.removeListener(_refresh);
    _hatim.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- ortak parçalar

  Widget _section(IconData icon, String title, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
        child: Row(children: [
          Icon(icon, size: 19, color: _pal.gold),
          const SizedBox(width: 6),
          Expanded(child: Text(title, style: TextStyle(color: _pal.ink, fontSize: 17, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing,
        ]),
      );

  Widget _premiumChip() => Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
        decoration: BoxDecoration(
          gradient: RC.bronze,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: RC.bronzeBorder),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.workspace_premium, size: 13, color: RC.bronzeText),
          SizedBox(width: 3),
          Text('Premium', style: TextStyle(color: RC.bronzeText, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _stat(String big, String small, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _pal.chip,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _pal.line),
          ),
          child: Column(children: [
            Icon(icon, size: 18, color: _pal.gold),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(big, style: TextStyle(color: _pal.ink, fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            Text(small, style: TextStyle(color: _pal.ink2, fontSize: 11)),
          ]),
        ),
      );

  /// Zikir çekilmiş mi (son 30 gün ya da bugün)?
  bool get _hasDhikr {
    final d = _dhikr;
    if (d == null) return false;
    final today = DateTime(_now.year, _now.month, _now.day);
    for (var i = 0; i < 30; i++) {
      if (d.onDay(today.subtract(Duration(days: i))) > 0) return true;
    }
    return d.todayTotal > 0;
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 10);
    return PageShell(
      title: 'Takibim',
      subtitle: 'Namaz, zikir, oruç ve hatim takibiniz',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        ..._prayers(gap),
        if (_hasDhikr) ...[gap, ..._dhikrs(gap)],
        gap,
        ..._fasting(gap),
        gap,
        ..._hatims(gap),
        gap,
        ..._kaza(gap),
        gap,
        SourceNote(
          pal: _pal,
          text: 'Kayıtlar yalnız bu telefonda tutulur. Kılınan namaz Namaz Vakitleri sayfasında vaktin '
              'satırındaki "Kıldım mı?" düğmesiyle ya da buradaki tabloya dokunarak işaretlenir.',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- namaz

  List<Widget> _prayers(Widget gap) {
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final week = [for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i)];
    final (wDone, wTotal) = _log.range(monday, today);
    final (mDone, mTotal) = _log.range(DateTime(today.year, today.month), today);
    final pct = mTotal == 0 ? 0 : (mDone * 100 / mTotal).round();

    Widget cell(DateTime d, int p) {
      final future = d.isAfter(today);
      final on = _log.prayed(d, p);
      final paused = _log.paused(d);
      return Semantics(
        button: !future,
        label: '${PrayerLog.names[p]} ${d.day}. gün${on ? ', kılındı' : ''}',
        child: GestureDetector(
          onTap: future ? null : () => _log.toggle(d, p),
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: on ? RC.bronze : null,
              color: on ? null : (future || paused ? Colors.transparent : _pal.chip),
              border: Border.all(
                  color: on ? RC.bronzeBorder : _pal.line.withValues(alpha: future ? 0.35 : 1), width: on ? 1.2 : 1),
            ),
            child: on
                ? const Icon(Icons.check, size: 15, color: RC.bronzeText)
                : paused
                    ? Icon(Icons.pause, size: 13, color: _pal.ink2)
                    : null,
          ),
        ),
      );
    }

    final monthLen = DateTime(today.year, today.month + 1, 0).day;
    Widget dayBox(int day) {
      final d = DateTime(today.year, today.month, day);
      final future = d.isAfter(today);
      final n = _log.count(d);
      final paused = _log.paused(d);
      return Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: future
              ? Colors.transparent
              : paused
                  ? _pal.line.withValues(alpha: 0.25)
                  : n == 0
                      ? _pal.chip
                      : _pal.gold.withValues(alpha: 0.18 + 0.164 * n),
          border: Border.all(color: d == today ? _pal.gold : _pal.line.withValues(alpha: future ? 0.3 : 0.6)),
        ),
        child: Text('$day',
            style: TextStyle(
                color: n >= 4 && !future ? (_pal.night ? const Color(0xFF1B1203) : Colors.white) : _pal.ink2,
                fontSize: 9,
                fontWeight: FontWeight.w700)),
      );
    }

    return [
      _section(Icons.mosque, 'Namazlarım', trailing: _premiumChip()),
      PaperBox(
        pal: _pal,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(children: [
          Row(children: [
            _stat('${_log.streak(now)} gün', 'Seri', Icons.local_fire_department),
            const SizedBox(width: 6),
            _stat('$wDone/$wTotal', 'Bu hafta', Icons.date_range),
            const SizedBox(width: 6),
            _stat('%$pct', _months[today.month - 1], Icons.insights),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const SizedBox(width: 50),
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(children: [
                  Text(_days[i],
                      style: TextStyle(
                          color: week[i] == today ? _pal.gold : _pal.ink2,
                          fontSize: 11.5,
                          fontWeight: week[i] == today ? FontWeight.w800 : FontWeight.w600)),
                  Text('${week[i].day}', style: TextStyle(color: _pal.ink2, fontSize: 10)),
                ]),
              ),
          ]),
          const SizedBox(height: 4),
          for (var p = 0; p < 5; p++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(
                  width: 50,
                  child: Text(PrayerLog.names[p],
                      style: TextStyle(color: _pal.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                for (final d in week) Expanded(child: Center(child: cell(d, p))),
              ]),
            ),
        ]),
      ),
      gap,
      PaperBox(
        pal: _pal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_months[today.month - 1]} ${today.year}',
              style: TextStyle(color: _pal.ink, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, children: [for (var d = 1; d <= monthLen; d++) dayBox(d)]),
          const SizedBox(height: 8),
          Row(children: [
            Text('Az', style: TextStyle(color: _pal.ink2, fontSize: 11)),
            const SizedBox(width: 4),
            for (var n = 1; n <= 5; n++)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _pal.gold.withValues(alpha: 0.18 + 0.164 * n),
                ),
              ),
            Text('5/5', style: TextStyle(color: _pal.ink2, fontSize: 11)),
            const Spacer(),
            Icon(Icons.pause, size: 13, color: _pal.ink2),
            Text(' özel gün', style: TextStyle(color: _pal.ink2, fontSize: 11)),
          ]),
          const SizedBox(height: 4),
          DashedLine(color: _pal.line),
          Row(children: [
            Icon(Icons.pause_circle_outline, size: 20, color: _pal.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Özel gün (bugün)', style: TextStyle(color: _pal.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
                Text('Açıkken bugün sayılmaz, seriniz bozulmaz', style: TextStyle(color: _pal.ink2, fontSize: 11.5)),
              ]),
            ),
            Switch(
              value: _log.paused(today),
              activeThumbColor: RC.bronzeText,
              activeTrackColor: const Color(0xFF6E5114),
              onChanged: (v) => _log.setPaused(today, v),
            ),
          ]),
        ]),
      ),
    ];
  }

  // ---------------------------------------------------------------- zikir

  List<Widget> _dhikrs(Widget gap) {
    final d = _dhikr!;
    final today = DateTime(_now.year, _now.month, _now.day);
    final last7 = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final counts = [for (final x in last7) d.onDay(x)];
    final week = counts.fold(0, (a, b) => a + b);
    var month = 0;
    for (var i = 1; i <= today.day; i++) {
      month += d.onDay(DateTime(today.year, today.month, i));
    }
    final peak = max(1, counts.fold(0, max));
    final todays = d.today.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));

    return [
      _section(Icons.blur_circular, 'Zikirlerim'),
      PaperBox(
        pal: _pal,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _stat(_trNum(d.onDay(today)), 'Bugün', Icons.today),
            const SizedBox(width: 6),
            _stat(_trNum(week), 'Son 7 gün', Icons.date_range),
            const SizedBox(width: 6),
            _stat(_trNum(month), _months[today.month - 1], Icons.insights),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (counts[i] > 0)
                      Text(_trNum(counts[i]), style: TextStyle(color: _pal.ink2, fontSize: 9.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Container(
                      width: 18,
                      height: max(3.0, 58.0 * counts[i] / peak),
                      decoration: BoxDecoration(
                        gradient: counts[i] > 0 ? RC.bronze : null,
                        color: counts[i] > 0 ? null : _pal.chip,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: counts[i] > 0 ? RC.bronzeBorder : _pal.line),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(_days[last7[i].weekday - 1],
                        style: TextStyle(
                            color: last7[i] == today ? _pal.gold : _pal.ink2,
                            fontSize: 10.5,
                            fontWeight: last7[i] == today ? FontWeight.w800 : FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
          if (todays.isNotEmpty) ...[
            const SizedBox(height: 8),
            DashedLine(color: _pal.line),
            const SizedBox(height: 6),
            Text('Bugün çektikleriniz', style: TextStyle(color: _pal.ink2, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in todays.take(6))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _pal.chip,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: _pal.line),
                  ),
                  child: Text('${d.byId(e.key).label} · ${_trNum(e.value)}',
                      style: TextStyle(color: _pal.ink, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ]),
          ],
          const SizedBox(height: 10),
          DarkButton(
            label: 'Zikir Sayacı',
            height: 38,
            onTap: () async {
              await Navigator.of(context).push(AppRoute(builder: (_) => const DhikrScreen()));
              _loadOthers();
            },
          ),
        ]),
      ),
    ];
  }

  // ---------------------------------------------------------------- oruç

  List<Widget> _fasting(Widget gap) {
    final r = _ramazan;
    final f = _fast;
    final today = DateTime(_now.year, _now.month, _now.day);
    final List<Widget> body;
    if (r == null || f == null) {
      body = [
        Text('Ramazan bilgisi yükleniyor…', style: TextStyle(color: _pal.ink2, fontSize: 13)),
      ];
    } else {
      final kept = f.days(r.year).length;
      final dayNo = r.dayNumber(today);
      final before = dayNo < 1;
      final passed = before ? 0 : min(dayNo, r.days);
      body = [
        Row(children: [
          Expanded(
            child: Text('Ramazan ${r.year}',
                style: TextStyle(color: _pal.ink, fontSize: 15.5, fontWeight: FontWeight.w700)),
          ),
          Text(
            before ? "Ramazan'a ${r.start.difference(today).inDays} gün" : '$kept / ${r.days} gün tutuldu',
            style: TextStyle(color: _pal.gold, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: r.days == 0 ? 0 : kept / r.days,
            minHeight: 8,
            backgroundColor: _pal.line.withValues(alpha: 0.25),
            color: _pal.gold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          before
              ? 'Ramazan başlayınca tuttuğunuz oruçları buradan işaretleyebilirsiniz.'
              : 'Geçen ${_trNum(passed)} günün ${_trNum(kept)} gününde oruç tuttunuz.',
          style: TextStyle(color: _pal.ink2, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        DarkButton(
          label: 'Oruç Takibi',
          height: 38,
          onTap: () async {
            await Navigator.of(context).push(AppRoute(builder: (_) => FastingTrackerScreen(data: r)));
            if (mounted) setState(() {});
          },
        ),
      ];
    }
    return [
      _section(Icons.nightlight_round, 'Oruçlarım'),
      PaperBox(
        pal: _pal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
      ),
    ];
  }

  // ---------------------------------------------------------------- hatim

  List<Widget> _hatims(Widget gap) {
    final h = _hatim;
    final now = _now;
    final List<Widget> body;
    if (!h.active) {
      body = [
        Text(
          h.completed > 0
              ? 'Şimdiye kadar ${h.completed} hatim tamamladınız. Yeni bir plan başlatabilirsiniz.'
              : "Kur'an'ı seçtiğiniz sürede, her gün bir bölüm okuyarak hatmedin.",
          style: TextStyle(color: _pal.ink2, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 10),
        DarkButton(label: 'Hatim planı başlat', height: 38, onTap: () => showHatimSetup(context)),
      ];
    } else {
      final next = h.next ?? 0;
      final behind = h.behind(now);
      final pct = (h.done.length * 100 / h.days).round();
      body = [
        Row(children: [
          _stat('${h.completed}', 'Hatim', Icons.workspace_premium),
          const SizedBox(width: 6),
          _stat('%$pct', '${h.days} günlük plan', Icons.auto_stories),
          const SizedBox(width: 6),
          _stat(behind > 0 ? '$behind' : '✓', behind > 0 ? 'Geride' : 'Plana uygun', Icons.schedule),
        ]),
        const SizedBox(height: 10),
        if (h.days <= 60)
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (var i = 0; i < h.days; i++)
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: h.done.contains(i) ? RC.bronze : null,
                  color: h.done.contains(i) ? null : _pal.chip,
                  border: Border.all(
                      color: i == h.dayIndex(now) ? _pal.gold : (h.done.contains(i) ? RC.bronzeBorder : _pal.line)),
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                        color: h.done.contains(i) ? RC.bronzeText : _pal.ink2, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
          ])
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: h.done.length / h.days,
              minHeight: 8,
              backgroundColor: _pal.line.withValues(alpha: 0.25),
              color: _pal.gold,
            ),
          ),
        if (_surahs.length == 114) ...[
          const SizedBox(height: 10),
          Text('Sıradaki bölüm', style: TextStyle(color: _pal.ink2, fontSize: 12)),
          Text(hatimRangeText(_surahs, h.portion(next)),
              style: TextStyle(color: _pal.ink, fontSize: 15, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DarkButton(label: 'Oku', height: 38, onTap: () => hatimOpen(context, next))),
          const SizedBox(width: 8),
          Expanded(
            child: PillButton(
              pal: _pal,
              selected: true,
              height: 38,
              radius: 12,
              onTap: () => hatimMarkRead(context, next),
              child: const Text('Okudum', style: TextStyle(fontSize: 14)),
            ),
          ),
        ]),
      ];
    }
    return [
      _section(Icons.auto_stories, 'Hatimlerim'),
      PaperBox(
        pal: _pal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
      ),
    ];
  }

  // ---------------------------------------------------------------- kaza

  Widget _kazaRow(String name, int value, VoidCallback onDone, VoidCallback onAdd, String doneLabel) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(name, style: TextStyle(color: _pal.ink, fontSize: 14.5))),
          Text(_trNum(value), style: TextStyle(color: _pal.ink, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          PillButton(pal: _pal, selected: false, height: 30, onTap: onDone, child: Text(doneLabel)),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onAdd,
            icon: Icon(Icons.add_circle_outline, size: 20, color: _pal.gold),
            tooltip: '$name: bir ekle',
          ),
        ]),
      );

  List<Widget> _kaza(Widget gap) {
    return [
      _section(Icons.history, 'Kaza borcum'),
      PaperBox(
        pal: _pal,
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Namaz', style: TextStyle(color: _pal.gold, fontSize: 13, fontWeight: FontWeight.w700))),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text('Toplam ${_trNum(_log.kazaTotal)}',
                  style: TextStyle(color: _pal.gold, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ]),
          for (var p = 0; p < 5; p++) ...[
            if (p > 0) DashedLine(color: _pal.line),
            _kazaRow(PrayerLog.names[p], _log.kaza[p], () => _log.setKaza(p, _log.kaza[p] - 1),
                () => _log.setKaza(p, _log.kaza[p] + 1), 'Kıldım −1'),
          ],
          const SizedBox(height: 6),
          Text('Oruç', style: TextStyle(color: _pal.gold, fontSize: 13, fontWeight: FontWeight.w700)),
          _kazaRow('Kaza orucu', _log.kazaOruc, () => _log.setKazaOruc(_log.kazaOruc - 1),
              () => _log.setKazaOruc(_log.kazaOruc + 1), 'Tuttum −1'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: DarkButton(label: 'Namaz borcunu hesapla', height: 40, onTap: _askKaza),
          ),
        ]),
      ),
    ];
  }

  /// Kaza namazı borcu: kılınmayan süre (yıl ve ay) girilir, her farz için gün sayısı kadar yazılır.
  Future<void> _askKaza() async {
    final y = TextEditingController(), m = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaza borcunu hesapla'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Namaz kılmadığınız süreyi yazın; her vakit için gün sayısı kadar kaza borcu yazılır.',
              style: TextStyle(fontSize: 13.5, height: 1.4)),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: y, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Yıl'))),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
                    controller: m, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ay'))),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hesapla')),
        ],
      ),
    );
    final days = ((int.tryParse(y.text) ?? 0) * 365.25 + (int.tryParse(m.text) ?? 0) * 30.44).round();
    y.dispose();
    m.dispose();
    if (ok != true || days <= 0) return;
    for (var p = 0; p < 5; p++) {
      _log.setKaza(p, days);
    }
  }
}

/// 1.234 biçiminde sayı.
String _trNum(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}
