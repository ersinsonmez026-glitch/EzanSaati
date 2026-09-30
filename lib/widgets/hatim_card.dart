import 'package:flutter/material.dart';

import '../screens/surah_read_screen.dart';
import '../services/content_store.dart';
import '../services/ezan_notifications.dart';
import '../services/hatim_plan.dart';
import '../services/premium.dart';
import '../services/quran_audio.dart';
import 'page_shell.dart';
import 'premium_ui.dart';
import 'reading_ui.dart';

/// "Bakara 142 – Bakara 252"
String hatimRangeText(List<Surah> surahs, (int, int) p) {
  final (s1, a1) = ayahOfGlobal(p.$1);
  final (s2, a2) = ayahOfGlobal(p.$2);
  return '${surahs[s1 - 1].name} $a1 – ${surahs[s2 - 1].name} $a2';
}

/// Günde okunacak yaklaşık miktar: "Günde ~208 ayet (≈ 1 cüz)".
String hatimDailyText(int days) {
  final ayah = (kTotalAyahs / days).round();
  final cuz = 30 / days;
  final c = cuz >= 1 ? (cuz == cuz.roundToDouble() ? '${cuz.round()}' : cuz.toStringAsFixed(1).replaceAll('.', ',')) : '1/${(days / 30).round()}';
  return 'Günde ~$ayah ayet (≈ $c cüz)';
}

/// Plan başlatma / değiştirme penceresi.
Future<void> showHatimSetup(BuildContext context) async {
  final plan = HatimPlan.instance;
  var days = plan.active && (Premium.instance.active || plan.days == HatimPlan.freeDays) ? plan.days : HatimPlan.freeDays;
  var remind = plan.remind;
  var time = TimeOfDay(hour: plan.remindHour, minute: plan.remindMinute);
  final pal = PagePalette.current();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: pal.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Hatim planı', style: TextStyle(color: pal.ink, fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text("Kur'an kaç günde hatmedilsin? Her gün eşit bir bölüm okunur.",
                style: TextStyle(color: pal.ink2, fontSize: 13)),
            const SizedBox(height: 12),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final d in HatimPlan.durations)
                IntrinsicWidth(
                  child: PillButton(
                    pal: pal,
                    selected: days == d,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    onTap: () {
                      if (d == HatimPlan.freeDays || requirePremium(ctx)) set(() => days = d);
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('$d gün', style: const TextStyle(fontSize: 14)),
                      if (d != HatimPlan.freeDays && !Premium.instance.active) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.lock, size: 13, color: pal.gold),
                      ],
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Text(hatimDailyText(days), style: TextStyle(color: pal.gold, fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            DashedLine(color: pal.line),
            Row(children: [
              Icon(Icons.notifications_active_outlined, color: pal.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Her gün hatırlat', style: TextStyle(color: pal.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
              if (remind)
                TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: ctx, initialTime: time);
                    if (t != null) set(() => time = t);
                  },
                  child: Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: pal.gold, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              Switch(
                value: remind,
                activeThumbColor: RC.bronzeText,
                activeTrackColor: const Color(0xFF6E5114),
                onChanged: (v) => set(() => remind = v),
              ),
            ]),
            const SizedBox(height: 10),
            PillButton(
              pal: pal,
              selected: true,
              height: 44,
              radius: 12,
              onTap: () => Navigator.pop(ctx, true),
              child: Text(plan.active ? 'Planı yeniden başlat' : 'Planı başlat', style: const TextStyle(fontSize: 15)),
            ),
            if (plan.active) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  plan.stop();
                  Navigator.pop(ctx, false);
                },
                child: Text('Planı bitir', style: TextStyle(color: pal.ink2)),
              ),
            ],
          ]),
        ),
      ),
    ),
  );
  if (ok == true) {
    plan.setReminder(remind, hour: time.hour, minute: time.minute);
    plan.begin(days, DateTime.now());
    if (remind) await EzanNotifications.instance.requestPermissions();
  }
  await EzanNotifications.instance.reschedule(); // hatırlatma kurulur ya da kaldırılır
}

/// Okudum: bölümü işaretler; hatim bittiyse tebrik eder.
Future<void> hatimMarkRead(BuildContext context, int i) async {
  final finished = HatimPlan.instance.markRead(i);
  if (!context.mounted) return;
  if (finished) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hatminiz tamamlandı'),
        content: Text('Allah kabul etsin. Bu, ${HatimPlan.instance.completed}. hatminiz.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
      ),
    );
    await EzanNotifications.instance.reschedule();
  } else {
    showNote(context, 'Allah kabul etsin');
  }
}

void hatimOpen(BuildContext context, int i) {
  final (s, a) = ayahOfGlobal(HatimPlan.instance.portion(i).$1);
  Navigator.of(context).push(AppRoute(builder: (_) => SurahReadScreen(surah: s, startAyah: a)));
}

/// Sureler sayfasındaki hatim planı kartı.
class HatimCard extends StatefulWidget {
  final List<Surah> surahs;

  /// Testler için saat.
  final DateTime Function()? clock;

  const HatimCard({super.key, required this.surahs, this.clock});

  @override
  State<HatimCard> createState() => _HatimCardState();
}

class _HatimCardState extends State<HatimCard> {
  final _plan = HatimPlan.instance;

  @override
  void initState() {
    super.initState();
    _plan.addListener(_changed);
    _plan.load();
  }

  @override
  void dispose() {
    _plan.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pal = PagePalette.current();
    final now = (widget.clock ?? DateTime.now)();
    if (!_plan.active) {
      return PaperBox(
        pal: pal,
        radius: 14,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(children: [
          Icon(Icons.auto_stories, color: pal.gold, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_plan.completed > 0 ? 'Hatim planı · ${_plan.completed} hatim' : 'Hatim planı',
                  style: TextStyle(color: pal.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
              Text("Kur'an'ı seçtiğiniz sürede, günde bir bölüm okuyarak hatmedin",
                  style: TextStyle(color: pal.ink2, fontSize: 11.5)),
            ]),
          ),
          const SizedBox(width: 8),
          PillButton(
            pal: pal,
            selected: true,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onTap: () => showHatimSetup(context),
            child: const Text('Başlat'),
          ),
        ]),
      );
    }
    final next = _plan.next ?? 0;
    final p = _plan.portion(next);
    final day = _plan.dayIndex(now) + 1;
    final behind = _plan.behind(now);
    return PaperBox(
      pal: pal,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.auto_stories, color: pal.gold, size: 20),
          const SizedBox(width: 6),
          Text('Hatim planım', style: TextStyle(color: pal.ink, fontSize: 15.5, fontWeight: FontWeight.w700)),
          Text(' · ${_plan.days} günde', style: TextStyle(color: pal.ink2, fontSize: 13)),
          const Spacer(),
          GestureDetector(
            onTap: () => showHatimSetup(context),
            child: Icon(Icons.tune, color: pal.ink2, size: 20),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: _plan.done.length / _plan.days,
            minHeight: 8,
            backgroundColor: pal.line.withValues(alpha: 0.25),
            color: pal.gold,
          ),
        ),
        const SizedBox(height: 5),
        Row(children: [
          Text('Gün $day/${_plan.days}', style: TextStyle(color: pal.ink2, fontSize: 12)),
          const Spacer(),
          Icon(behind > 0 ? Icons.schedule : Icons.check_circle, size: 14, color: pal.gold),
          const SizedBox(width: 3),
          Text(behind > 0 ? '$behind bölüm geridesiniz' : 'Plana uygun',
              style: TextStyle(color: pal.gold, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        DashedLine(color: pal.line),
        const SizedBox(height: 6),
        Text(next < day - 1 ? 'Sıradaki bölüm (${next + 1}. gün)' : 'Bugünkü bölüm',
            style: TextStyle(color: pal.ink2, fontSize: 12)),
        Text(hatimRangeText(widget.surahs, p), style: TextStyle(color: pal.ink, fontSize: 16, fontWeight: FontWeight.w700)),
        Text('${p.$2 - p.$1 + 1} ayet', style: TextStyle(color: pal.ink2, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: DarkButton(label: 'Oku', height: 38, onTap: () => hatimOpen(context, next))),
          const SizedBox(width: 8),
          Expanded(
            child: PillButton(
              pal: pal,
              selected: true,
              height: 38,
              radius: 12,
              onTap: () => hatimMarkRead(context, next),
              child: const Text('Okudum', style: TextStyle(fontSize: 14)),
            ),
          ),
        ]),
      ]),
    );
  }
}
