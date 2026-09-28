import 'package:flutter/material.dart';

import '../data/namaz_ogren.dart';
import '../services/content_store.dart';
import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import '../widgets/gold_icon.dart';

/// Namaz Öğren: solda sabit namaz/konu listesi, sağda rekât rekât anlatım.
/// Tasarım: onizleme/05-namaz-ogren.html
class LearnNamazScreen extends StatefulWidget {
  const LearnNamazScreen({super.key});

  @override
  State<LearnNamazScreen> createState() => _LearnNamazScreenState();
}

class _LearnNamazScreenState extends State<LearnNamazScreen> {
  static const _railWidth = 104.0;
  static const _gap = 7.0;

  final _pal = PagePalette.current();
  final _scroll = ScrollController();
  Map<String, Dua>? _duas;

  // Seçim: namaz (index) ya da konu (key)
  int? _namaz;
  String? _topic;
  int _part = 0;
  final Set<int> _open = {}; // açık adımlar
  final Map<int, String> _picked = {}; // zamm-ı sure seçimi (adım -> sure)

  @override
  void initState() {
    super.initState();
    _namaz = _namazForNow();
    DuaData.namaz().then((d) {
      if (mounted) setState(() => _duas = d);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Açılışta şu anki vaktin namazı seçili gelir (güneş doğduktan öğleye kadar sabah).
  int _namazForNow() {
    final loc = LocationStore.instance.current;
    if (loc == null) return 0;
    final now = DateTime.now();
    final t = PrayerCalc.forDay(loc, now).slots;
    int vakit = 5;
    if (!now.isBefore(t[0].time)) {
      for (var i = 5; i >= 0; i--) {
        if (!now.isBefore(t[i].time)) {
          vakit = i == 1 ? -1 : i;
          break;
        }
      }
    }
    final i = namazlar.indexWhere((n) => n.vakit == vakit);
    return i < 0 ? 0 : i;
  }

  void _selectNamaz(int i, [int part = 0]) {
    setState(() {
      _namaz = i;
      _topic = null;
      _part = part;
      _open.clear();
      _picked.clear();
    });
  }

  void _selectTopic(String key) {
    setState(() {
      _topic = key;
      _namaz = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Namaz Öğren',
      background: _pal.background,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
      children: [
        _StickyRailLayout(
          railWidth: _railWidth,
          gap: _gap,
          rail: _rail(),
          content: _topic != null
              ? _topicView(infoTopics.firstWhere((t) => t.key == _topic))
              : _namazView(namazlar[_namaz ?? 0]),
        ),
        const SizedBox(height: 10),
        SourceNote(pal: _pal, text: "Anlatımlar Hanefî mezhebine ve Türkiye'deki uygulamaya göredir."),
      ],
    );
  }

  // ---------------------------------------------------------------- sol liste

  static const _namazIcons = {
    'sabah': Icons.wb_twilight,
    'ogle': Icons.wb_sunny_outlined,
    'ikindi': Icons.wb_cloudy_outlined,
    'aksam': Icons.nights_stay_outlined,
    'yatsi': Icons.dark_mode_outlined,
    'cuma': Icons.mosque_outlined,
    'vitir': Icons.nightlight_outlined,
    'teravih': Icons.light_outlined,
  };

  static const _topicIcons = {
    'abdest': Icons.water_drop_outlined,
    'gusul': Icons.bathtub_outlined,
    'teyemmum': Icons.landscape_outlined,
    'sart': Icons.menu_book_outlined,
    'sss': Icons.help_outline,
  };

  Widget _rail() {
    final buttons = <Widget>[
      for (var i = 0; i < namazlar.length; i++)
        _RailButton(
          icon: _namazIcons[namazlar[i].key]!,
          label: namazlar[i].shortTitle,
          selected: _topic == null && _namaz == i,
          onTap: () => _selectNamaz(i),
        ),
      Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3), color: RC.gold(0.35)),
      for (final t in infoTopics)
        _RailButton(
          icon: _topicIcons[t.key]!,
          label: t.railTitle,
          selected: _topic == t.key,
          onTap: () => _selectTopic(t.key),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          buttons[i],
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- namaz anlatımı

  Widget _namazView(Namaz n) {
    final part = n.parts[_part.clamp(0, n.parts.length - 1)];
    final steps = namazSteps(n, part);
    final children = <Widget>[_namazHead(n, part)];
    var no = 0;
    for (var k = 0; k < steps.length; k++) {
      final s = steps[k];
      if (s.rakat != null) {
        children.add(Align(alignment: Alignment.centerLeft, child: _rakatLabel('${part.name} · ${s.rakat}. Rekât')));
        continue;
      }
      no++;
      children.add(_stepCard(k, no, s));
    }
    final p = _part;
    children.add(PrevNextRow(
      prevLabel: p > 0 ? '‹ ${n.parts[p - 1].name}' : '‹ Önceki',
      nextLabel: p < n.parts.length - 1 ? '${n.parts[p + 1].name} ›' : 'Sonraki ›',
      onPrev: p > 0 ? () => _selectNamaz(_namaz!, p - 1) : null,
      onNext: p < n.parts.length - 1 ? () => _selectNamaz(_namaz!, p + 1) : null,
      height: 40,
      fontSize: 11.5,
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
  }

  Widget _namazHead(Namaz n, NamazPart part) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RC.gold(0.75), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x38281905), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              gradient: RC.darkPanel,
              border: Border(bottom: BorderSide(color: RC.gold(0.6), width: 1.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title, style: const TextStyle(color: RC.goldText, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(partSubtitle(n, part), style: const TextStyle(color: Color(0xE6F3ECD9), fontSize: 12.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            color: _pal.paper2,
            child: Row(
              children: [
                for (var j = 0; j < n.parts.length; j++) ...[
                  if (j > 0) const SizedBox(width: 4),
                  Expanded(
                    // Yazısı uzun olan bölüm daha geniş yer alır.
                    flex: '${n.parts[j].name} (${n.parts[j].rakats})'.length,
                    child: PillButton(
                      pal: _pal,
                      selected: j == _part,
                      height: 32,
                      radius: 10,
                      border: false,
                      background: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onTap: () => _selectNamaz(_namaz!, j),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('${n.parts[j].name} (${n.parts[j].rakats})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rakatLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: RC.darkPanel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RC.gold(0.5)),
      ),
      child: Text(text, style: const TextStyle(color: RC.goldText, fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }

  Widget _stepCard(int k, int no, NamazStep s) {
    final open = _open.contains(k);
    final image = poseImages[s.pose];
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RC.darkPanel),
            child: Text('$no', style: const TextStyle(color: RC.goldText, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 7),
          Container(
            width: 50,
            height: 56,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E6C8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _pal.line),
            ),
            child: image == null
                ? null
                : Image.asset('assets/images/namaz/$image.webp', fit: BoxFit.cover),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: TextStyle(color: _pal.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(s.description, style: TextStyle(color: _pal.ink2, fontSize: 11.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );

    return PaperBox(
      pal: _pal,
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.hasDetails)
            Semantics(
              button: true,
              expanded: open,
              child: InkWell(
                onTap: () => setState(() => open ? _open.remove(k) : _open.add(k)),
                child: header,
              ),
            )
          else
            header,
          if (open && s.hasDetails)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DashedLine(color: _pal.line),
                  if (s.niyet != null) ...[
                    _label('NİYET'),
                    const SizedBox(height: 6),
                    Text('"${s.niyet}"', style: TextStyle(color: _pal.ink, fontSize: 13.5, height: 1.55)),
                  ],
                  for (final t in s.duas) ..._duaBlock(t),
                  if (s.pickSurah) ..._surahPicker(k),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(text,
            style: TextStyle(color: _pal.gold, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );

  List<Widget> _duaBlock(String title) {
    final d = _duas?[title];
    if (d == null) return const [];
    return [
      _label(trUpper(d.title)),
      const SizedBox(height: 8),
      Text(
        d.arabic,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(fontFamily: kQuranFont, fontSize: 22, height: 2.1, color: _pal.ink),
      ),
      const SizedBox(height: 4),
      Text(d.reading,
          style: TextStyle(color: _pal.ink2, fontSize: 13.5, height: 1.55, fontStyle: FontStyle.italic)),
      const SizedBox(height: 6),
      Text(d.meaning, style: TextStyle(color: _pal.ink, fontSize: 13.5, height: 1.55)),
    ];
  }

  List<Widget> _surahPicker(int k) {
    final available = zammSurahs.where((t) => _duas?.containsKey(t) ?? false).toList();
    if (available.isEmpty) return const [];
    final selected = _picked[k] ?? available.first;
    return [
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final t in available)
            IntrinsicWidth(
              child: PillButton(
                pal: _pal,
                selected: t == selected,
                height: 28,
                onTap: () => setState(() => _picked[k] = t),
                child: Text(t.replaceAll(' Sûresi', ''), style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
      ..._duaBlock(selected),
    ];
  }

  // ---------------------------------------------------------------- bilgi konuları

  Widget _topicView(InfoTopic t) {
    final children = <Widget>[
      for (final c in t.cards) _infoCard(c),
      for (final a in t.accordions) _Accordion(pal: _pal, item: a),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
  }

  Widget _infoCard(InfoCard c) {
    final base = TextStyle(color: _pal.ink, fontSize: 13, height: 1.6);
    return PaperBox(
      pal: _pal,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.title, style: TextStyle(color: _pal.gold, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (c.body != null) Text(c.body!, style: base),
          for (var i = 0; i < c.items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 20, child: Text('${i + 1}.', style: base)),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        if (c.items[i].lead != null)
                          TextSpan(text: '${c.items[i].lead} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: c.items[i].text),
                      ]),
                      style: base,
                    ),
                  ),
                ],
              ),
            ),
          if (c.warn != null) ...[
            const SizedBox(height: 8),
            DashedLine(color: _pal.line),
            const SizedBox(height: 8),
            Text(c.warn!, style: TextStyle(color: _pal.ink2, fontSize: 12.5, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

/// Sol listedeki koyu düğme; seçiliyken bronz.
class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailButton({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? RC.bronzeText : RC.cream;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: selected
                ? RC.bronze
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF062A1D), Color(0xFF01170F), Color(0xFF000C07)],
                    stops: [0, 0.5, 1],
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? RC.bronzeBorder : RC.gold(0.75), width: selected ? 1.5 : 1),
            boxShadow: selected
                ? RC.bronzeGlow
                : const [BoxShadow(color: Color(0x80000000), blurRadius: 5, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: selected ? RC.bronzeText : const Color(0xFFE9C96A)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Açılır kapanır bilgi kutusu.
class _Accordion extends StatefulWidget {
  final PagePalette pal;
  final InfoAccordion item;

  const _Accordion({required this.pal, required this.item});

  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final a = widget.item;
    final text = TextStyle(color: pal.ink, fontSize: 13.5, height: 1.6);
    return PaperBox(
      pal: pal,
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(a.title,
                          style: TextStyle(color: pal.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: GoldIcon(Icons.chevron_right, size: 22, light: !pal.night),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (a.body != null) Text(a.body!, style: text),
                  for (final b in a.bullets)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 16, child: Text('•', style: text)),
                          Expanded(child: Text(b, style: text)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Sol sütun sayfa kaydırılırken başlığın altında sabit kalır, sağ sütun akar.
class _StickyRailLayout extends StatefulWidget {
  final double railWidth;
  final double gap;
  final Widget rail;
  final Widget content;

  const _StickyRailLayout({required this.railWidth, required this.gap, required this.rail, required this.content});

  @override
  State<_StickyRailLayout> createState() => _StickyRailLayoutState();
}

class _StickyRailLayoutState extends State<_StickyRailLayout> {
  final _railKey = GlobalKey();
  final _shift = ValueNotifier<double>(0);
  double _railHeight = 0;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = Scrollable.maybeOf(context)?.position;
    if (p != _position) {
      _position?.removeListener(_update);
      _position = p;
      _position?.addListener(_update);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_update);
    _shift.dispose();
    super.dispose();
  }

  // Sütunun, kaydırma sıfırdayken ekrandaki üst kenarı. Kaydırma bildirimi yerleşimden önce
  // geldiği için konum, ölçülen bu değerden ve kaydırma miktarından hesaplanır.
  double? _baseTop;

  /// Yerleşimden sonra ölçüm yapar.
  void _measure() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || _position == null) return;
    _baseTop = box.localToGlobal(Offset.zero).dy + _position!.pixels;
    final railBox = _railKey.currentContext?.findRenderObject() as RenderBox?;
    if (railBox != null && railBox.hasSize && railBox.size.height != _railHeight) {
      setState(() => _railHeight = railBox.size.height);
    }
    _update();
  }

  void _update() {
    final box = context.findRenderObject() as RenderBox?;
    final base = _baseTop;
    if (box == null || !box.hasSize || base == null || _position == null) return;
    final top = base - _position!.pixels;
    final pinTop = MediaQuery.paddingOf(context).top + PageShell.barHeight + 8;
    final maxShift = (box.size.height - _railHeight).clamp(0.0, double.infinity);
    _shift.value = (pinTop - top).clamp(0.0, maxShift);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(left: widget.railWidth + widget.gap),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: _railHeight),
            child: widget.content,
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _shift,
          builder: (context, shift, child) => Positioned(
            left: 0,
            top: shift,
            width: widget.railWidth,
            child: child!,
          ),
          child: KeyedSubtree(key: _railKey, child: widget.rail),
        ),
      ],
    );
  }
}
