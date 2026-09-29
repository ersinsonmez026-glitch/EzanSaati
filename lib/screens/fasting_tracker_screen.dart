import 'package:flutter/material.dart';

import '../services/content_store.dart';
import '../services/fasting_log.dart';
import '../theme.dart';
import '../widgets/gold_icon.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Ramazan oruç takibi: Ramazan günleri takvimde; tutulan günler işaretlenir. Bugüne kadarki günler
/// işaretlenebilir, ileri günler kapalıdır. Altta tutulan, kaçırılan ve kalan günlerin özeti.
class FastingTrackerScreen extends StatefulWidget {
  final RamazanData data;

  /// Testler için saat; verilmezse gerçek saat.
  final DateTime Function()? clock;

  const FastingTrackerScreen({super.key, required this.data, this.clock});

  @override
  State<FastingTrackerScreen> createState() => _FastingTrackerScreenState();
}

class _FastingTrackerScreenState extends State<FastingTrackerScreen> {
  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  FastingLog? _log;

  static const _weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const _months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

  RamazanData get _d => widget.data;
  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    FastingLog.get().then((l) {
      if (mounted) setState(() => _log = l);
    });
  }

  /// Bugün Ramazan'ın kaçıncı günü (öncesinde 0 ve altı).
  int get _today => _d.dayNumber(_now);

  Future<void> _toggle(int day) async {
    final log = _log;
    if (log == null) return;
    final on = log.toggle(_d.year, day);
    setState(() {});
    if (!on) {
      showNote(context, '$day. günün işareti kaldırıldı');
      return;
    }
    final count = log.days(_d.year).length;
    final text = day == _d.days
        ? 'Bu yıl son orucunuzu tutuyorsunuz.\nBu Ramazan toplam $count oruç tuttunuz.'
        : count == 1
            ? 'İlk orucunuzu tuttunuz.'
            : 'Bu Ramazan $count oruç tuttunuz.';
    await showDialog<void>(
      context: context,
      builder: (context) => _BlessingDialog(text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final log = _log;
    final kept = log?.days(_d.year) ?? const <int>{};
    final today = _today;
    final pastDays = today.clamp(0, _d.days); // bugün dâhil geçen günler
    final missed = [
      for (var i = 1; i < pastDays; i++)
        if (!kept.contains(i)) i
    ].length; // bugün henüz bitmedi
    final remaining = _d.days - pastDays;

    return PageShell(
      title: 'Oruç Takibi',
      heading: 'Ramazan',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (today < 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              "Ramazan ${_d.start.day} ${_monthLong(_d.start.month)} ${_d.start.year}'de başlıyor. "
              'Günler geldikçe tuttuğunuz oruçları işaretleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _pal.ink2, fontSize: 13.5, height: 1.4),
            ),
          ),
        SectionHead(pal: _pal, title: 'Ramazan ${_d.year}'),
        const SizedBox(height: 6),
        PaperBox(
          pal: _pal,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: log == null ? const SizedBox(height: 200) : _calendar(kept, today),
        ),
        const SizedBox(height: 10),
        _summary(kept.length, missed, remaining),
        const SizedBox(height: 10),
        SourceNote(
          pal: _pal,
          text: 'Oruç tuttuğunuz günlere dokunarak işaretleyin; yanlış işareti yine dokunarak kaldırabilirsiniz. '
              "Kaçırılan Ramazan oruçları Ramazan'dan sonra gününe gün kaza edilir (Din İşleri Yüksek Kurulu, "
              'Oruç Sıkça Sorulanlar). İşaretler yalnızca bu telefonda saklanır.',
        ),
      ],
    );
  }

  Widget _calendar(Set<int> kept, int today) {
    final lead = _d.start.weekday - 1; // Pazartesi başlangıçlı haftada ilk günün yeri
    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: Text(w, style: TextStyle(color: _pal.gold, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 5,
          childAspectRatio: 0.78,
          children: [
            for (var i = 0; i < lead; i++) const SizedBox(),
            for (var day = 1; day <= _d.days; day++) _cell(day, kept.contains(day), today),
          ],
        ),
      ],
    );
  }

  Widget _cell(int day, bool kept, int today) {
    final date = _d.dateOf(day);
    final open = day <= today; // bugün ve öncesi işaretlenebilir
    final isToday = day == today;
    final missed = open && !isToday && !kept;
    final Color fg = kept ? RC.bronzeText : (open ? _pal.ink : _pal.ink2.withValues(alpha: 0.55));
    return Semantics(
      button: open,
      selected: kept,
      label: 'Ramazan $day. gün, ${date.day} ${_monthLong(date.month)}${kept ? ', tutuldu' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: open ? () => _toggle(day) : null,
        child: Container(
          decoration: BoxDecoration(
            gradient: kept ? RC.bronze : null,
            color: kept ? null : (open ? _pal.paper2 : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isToday ? _pal.gold : (kept ? RC.bronzeBorder : _pal.line),
              width: isToday ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$day', style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w700, height: 1.1)),
                    Text('${date.day} ${_months[date.month - 1]}',
                        style: TextStyle(color: fg, fontSize: 9.5, height: 1.1)),
                  ],
                ),
              ),
              if (kept) const Positioned(top: 2, right: 3, child: Icon(Icons.check, size: 12, color: RC.bronzeText)),
              if (missed)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: Color(0xFFC0392B), shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(int kept, int missed, int remaining) {
    Widget stat(String value, String label, Color color) => Expanded(
          child: Column(
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w700, height: 1.1)),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: TextStyle(color: _pal.ink2, fontSize: 12.5)),
            ],
          ),
        );
    return PaperBox(
      pal: _pal,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                stat('$kept', 'Tutulan oruç', _pal.gold),
                Container(width: 1, color: _pal.line),
                stat('$missed', 'Kaçırılan oruç', const Color(0xFFC0392B)),
                Container(width: 1, color: _pal.line),
                stat('$remaining', 'Kalan gün', _pal.ink),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: kept / _d.days,
              minHeight: 8,
              backgroundColor: _pal.line,
              valueColor: AlwaysStoppedAnimation(_pal.gold),
            ),
          ),
          const SizedBox(height: 6),
          Text('${_d.days} günün $kept günü tutuldu', style: TextStyle(color: _pal.ink2, fontSize: 12)),
        ],
      ),
    );
  }

  static String _monthLong(int m) => const [
        'Ocak',
        'Şubat',
        'Mart',
        'Nisan',
        'Mayıs',
        'Haziran',
        'Temmuz',
        'Ağustos',
        'Eylül',
        'Ekim',
        'Kasım',
        'Aralık',
      ][m - 1];
}

/// İşaretleyince çıkan "Allah kabul etsin" kartı.
class _BlessingDialog extends StatelessWidget {
  final String text;

  const _BlessingDialog({required this.text});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          gradient: RC.darkPanel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: RC.goldBorder, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ArtIcon('imsak', size: 56),
            const SizedBox(height: 6),
            const GoldText(
              'Allah kabul etsin',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.cream, fontSize: 15.5, height: 1.45),
            ),
            const SizedBox(height: 14),
            DarkButton(label: 'Âmin', height: 42, onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}
