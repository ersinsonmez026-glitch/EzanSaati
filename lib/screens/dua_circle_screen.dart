import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/circle_sync.dart';
import '../services/dua_circle_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'dua_circle_form_screen.dart';
import 'dua_circle_invite_screen.dart';
import '../widgets/gold_icon.dart';

/// Dua Zinciri ana sayfası (onizleme/10-dua-zinciri.html): solda menü, sağda
/// seçili zincirin kartı, altta diğer zincirler.
class DuaCircleScreen extends StatefulWidget {
  const DuaCircleScreen({super.key});

  @override
  State<DuaCircleScreen> createState() => _DuaCircleScreenState();
}

class _DuaCircleScreenState extends State<DuaCircleScreen> {
  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  final _store = DuaCircleStore.instance;
  final _sync = CircleSync.instance;
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _codeCtl = TextEditingController();
  String _menu = 'mine';
  String? _selected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    _sync.addListener(_changed);
    _store.load().then((_) {
      if (!mounted) return;
      final note = _store.takeCleanupNote();
      if (note.isNotEmpty) showNote(context, note);
      _connect();
    });
  }

  Future<void> _connect() async {
    await _sync.start();
    if (!mounted) return;
    _nameCtl.text = _sync.profileName;
    _phoneCtl.text = _sync.profilePhone;
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    _sync.removeListener(_changed);
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  List<DuaCircle> _list(String menu) {
    final all = _store.circles;
    return switch (menu) {
      'mine' => all.where((c) => c.mine).toList(),
      'joined' => all.where((c) => !c.mine).toList(),
      'act' => all.where((c) => !c.isComplete).toList(),
      'fin' => all.where((c) => c.isComplete).toList(),
      _ => const <DuaCircle>[],
    };
  }

  DuaCircle? get _current {
    final list = _list(_menu);
    if (list.isEmpty) return null;
    return list.firstWhere((c) => c.id == _selected, orElse: () => list.first);
  }

  Future<void> _newCircle({(String, String, int)? template}) async {
    final c = await Navigator.of(context).push<DuaCircle>(
      AppRoute(builder: (_) => DuaCircleFormScreen(template: template)),
    );
    if (c == null || !mounted) return;
    setState(() {
      _menu = 'mine';
      _selected = c.id;
    });
    _invite(c);
  }

  Future<void> _edit(DuaCircle c, {bool addPerson = false}) async {
    final r = await Navigator.of(context).push<DuaCircle>(
      AppRoute(builder: (_) => DuaCircleFormScreen(circle: c, addPerson: addPerson)),
    );
    if (r == null || !mounted) return;
    if (r.pending.isNotEmpty) _invite(r);
  }

  void _invite(DuaCircle c) {
    Navigator.of(context).push(AppRoute(builder: (_) => DuaCircleInviteScreen(circle: c)));
  }

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    return PageShell(
      title: 'Dua Zinciri',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
      children: !_store.loaded
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: _pal.gold)),
              ),
            ]
          : [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 132, child: _rail()),
                  const SizedBox(width: 7),
                  Expanded(child: _Pane(child: _paneContent(cur))),
                ],
              ),
              if (_store.circles.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionHead(
                  pal: _pal,
                  title: 'Diğer Zincirlerim',
                  trailing: Text('Seçmek için dokunun', style: TextStyle(color: _pal.ink2, fontSize: 12)),
                ),
                const SizedBox(height: 8),
                _others(cur),
              ],
              const SizedBox(height: 12),
              SourceNote(
                pal: _pal,
                text: 'Dua Zinciri: bir görevi (salavat, Yasin, hatim…) sevdiklerinizle bölüşün. '
                    '${_sync.ready ? 'Zincirler katılımcılarla eşitlenir; telefon numaraları sunucuya yazılmaz.' : 'İnternet bağlantısı olmadan kurulan zincirler yalnızca bu telefonda tutulur.'}',
              ),
            ],
    );
  }

  // ---------------- Sol menü ----------------

  Widget _rail() {
    final all = _store.circles;
    final act = all.where((c) => !c.isComplete).length;
    final mine = all.where((c) => c.mine).length;
    final inv = _sync.invites.length;
    final items = [
      ('mine', Icons.link, 'Zincirlerim', '$mine zincir'),
      ('joined', Icons.group, 'Katıldıklarım', '${all.length - mine} zincir'),
      ('new', Icons.add_circle, 'Yeni Zincir', 'Oluştur'),
      ('sug', Icons.menu_book, 'Önerilenler', 'Hazır görevler'),
      ('act', Icons.schedule, 'Devam Eden', '$act zincir'),
      ('fin', Icons.verified, 'Tamamlanan', '${all.length - act} zincir'),
      ('inv', Icons.mail, 'Davetler', inv > 0 ? '$inv bekliyor' : 'Yok'),
      ('online', Icons.groups, 'Online Dua', 'Toplam'),
      ('set', Icons.settings, 'Ayarlar', 'Profil, kurallar'),
    ];
    return Column(
      children: [
        for (final (key, icon, title, sub) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _RailButton(
              icon: icon,
              title: title,
              subtitle: sub,
              selected: _menu == key,
              onTap: () {
                if (key == 'new') {
                  _newCircle();
                } else {
                  setState(() => _menu = key);
                }
              },
            ),
          ),
      ],
    );
  }

  // ---------------- Sağ panel ----------------

  Widget _paneContent(DuaCircle? cur) {
    switch (_menu) {
      case 'mine':
      case 'act':
      case 'fin':
        if (cur != null) return _circlePane(cur);
        return _info(
          const {'mine': 'Zincirlerim', 'act': 'Devam Edenler', 'fin': 'Tamamlananlar'}[_menu]!,
          _menu == 'fin'
              ? 'Tamamlanan zincirleriniz burada saklanır.'
              : 'Henüz zinciriniz yok. Bir dua seçip sevdiklerinizle bölüşün.',
          action: _menu == 'fin' ? null : ('Yeni Zincir', () => _newCircle()),
        );
      case 'sug':
        return _suggestions();
      case 'joined':
        if (cur != null) return _circlePane(cur);
        return _info(
            'Katıldıklarım',
            'Başkalarının kurduğu ve sizin kabul ettiğiniz zincirler burada görünür. '
                'Size gelen davetleri Davetler bölümünden kabul edebilirsiniz.');
      case 'inv':
        return _invites();
      case 'online':
        return _online();
      default:
        return _settings();
    }
  }

  Widget _heading(String title, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      child: Column(
        children: [
          _GoldTitle(title, size: 18),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFF2DDA8), fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _info(String title, String text, {(String, VoidCallback)? action}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(title),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Text(text,
              textAlign: TextAlign.center, style: const TextStyle(color: RC.creamSoft, fontSize: 12.5, height: 1.5)),
        ),
        if (action != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: _GoldButton(label: action.$1, onTap: action.$2),
          ),
      ],
    );
  }

  Widget _suggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Önerilen Zincirler', sub: 'Dokunun, hazır ayarlarla başlasın'),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Column(
            children: [
              for (final t in kCircleTemplates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _DarkItem(
                    icon: _typeIcon(t.$1),
                    title: t.$2,
                    subtitle: 'Toplam ${trNum(t.$3)} ${kDuaTypesByKey[t.$1]!.unit}',
                    onTap: () => _newCircle(template: t),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _online() {
    final totals = <String, int>{};
    for (final c in _store.circles) {
      final key = c.type == 'ozel' ? c.name : kDuaTypesByKey[c.type]!.title;
      totals[key] = (totals[key] ?? 0) + (c.meOrNull?.done ?? 0);
    }
    final rows = totals.entries.where((e) => e.value > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Online Dua', sub: 'Zincirlerde okuduklarınızın toplamı'),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Text(
            'Herkesin toplamı sunucu bağlantısı kurulduğunda burada canlı görünecek. '
            'Şimdilik bu telefonda zincirlerde okuduklarınız:',
            textAlign: TextAlign.center,
            style: TextStyle(color: RC.creamSoft, fontSize: 12, height: 1.5),
          ),
        ),
        _Parchment(
          children: rows.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('Henüz okuma eklenmedi.',
                        textAlign: TextAlign.center, style: TextStyle(color: RC.verseInk2, fontSize: 12)),
                  ),
                ]
              : [
                  for (final e in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(e.key,
                                style:
                                    const TextStyle(color: RC.verseInk, fontSize: 12.5, fontWeight: FontWeight.w700)),
                          ),
                          Text(trNum(e.value),
                              style: const TextStyle(color: RC.verseInk, fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
        ),
      ],
    );
  }

  Widget _rules() {
    const rules = [
      'Zincirin son günü en fazla $kCircleMaxDays gün sonrası olabilir.',
      'Son günü geçen ve tamamlanmamış zincirler silinir; tamamlananlar saklanır.',
      'Davete $kInviteHours saat içinde yanıt vermeyen kişinin payı size döner; dilerseniz başkasına verebilirsiniz.',
      'Paylar eşit olmak zorunda değildir; toplamı hedefle aynı olmalıdır.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Zincir kuralları'),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5, right: 6),
                        child: GoldIcon(Icons.circle, size: 5),
                      ),
                      Expanded(
                        child: Text(r, style: const TextStyle(color: RC.cream, fontSize: 12, height: 1.45)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Text(
              'Uygulama kapalıyken bildirim gönderilmez; yeni davetler ve ilerlemeler uygulama açıldığında görünür.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RC.creamSoft, fontSize: 11.5, height: 1.4)),
        ),
      ],
    );
  }

  // ---------------- Davetler ve ayarlar ----------------

  String get _syncText => switch (_sync.state) {
        SyncState.ready => 'Bağlı: zincirler katılımcılarla eşitleniyor.',
        SyncState.connecting => 'Bağlanıyor…',
        SyncState.error => 'Bağlanılamadı. İnternet bağlantınızı kontrol edin.',
        SyncState.off => 'Ortak zincir bu cihazda kullanılamıyor; zincirler telefonda tutulur.',
      };

  Widget _paneText(String t, {double size = 12, Color color = RC.creamSoft}) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Text(t, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: size, height: 1.45)),
      );

  Widget _darkField(TextEditingController c, String label,
      {TextInputType? keyboard, String? hint, Key? key, TextCapitalization caps = TextCapitalization.none}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: TextField(
        key: key,
        controller: c,
        keyboardType: keyboard,
        textCapitalization: caps,
        cursorColor: RC.goldText,
        style: const TextStyle(color: RC.cream, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: RC.goldIcon, fontSize: 12.5),
          hintStyle: const TextStyle(color: RC.creamSoft, fontSize: 13),
          filled: true,
          fillColor: const Color(0x33000000),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: RC.gold(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: RC.goldText, width: 1.4),
          ),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() job, {String? ok}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
      if (ok != null && mounted) showNote(context, ok);
    } catch (e) {
      if (mounted) showNote(context, 'İşlem yapılamadı. İnternet bağlantınızı kontrol edin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _invites() {
    if (!_sync.ready) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('Davetler'),
          if (_sync.state != SyncState.off)
            _paneText('Davetleri almak için internet bağlantısı gerekiyor.', size: 12.5),
          _paneText(_syncText),
          if (_sync.state == SyncState.error)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: _GoldButton(label: 'Yeniden dene', onTap: _connect),
            ),
        ],
      );
    }
    final list = _sync.invites;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Davetler', sub: 'Size gelen davetler'),
        if (list.isEmpty) _paneText('Şu an bekleyen davetiniz yok.', size: 12.5),
        for (final i in list)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              decoration: BoxDecoration(
                gradient: RC.darkPanel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: RC.gold(0.75)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(i.circleName,
                      style: const TextStyle(color: RC.goldText, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${i.ownerName} davet etti · Size düşen: ${trNum(i.share)} ${i.unit}',
                      style: const TextStyle(color: Color(0xFFC9D8CF), fontSize: 11.5, height: 1.35)),
                  Text(
                      'Son gün ${trDate(i.end)} · yanıt için ${i.expiresAt.difference(now).inHours.clamp(0, kInviteHours)} sa',
                      style: const TextStyle(color: RC.creamSoft, fontSize: 11)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ActButton(
                          icon: Icons.close,
                          label: 'Reddet',
                          onTap: _busy ? null : () => _run(() => _sync.decline(i), ok: 'Davet reddedildi'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ActButton(
                          icon: Icons.check,
                          label: 'Kabul et',
                          onTap: _busy
                              ? null
                              : () => _run(() async {
                                    await _sync.accept(i);
                                    if (mounted) setState(() => _menu = 'joined');
                                  }, ok: 'Daveti kabul ettiniz. Allah kabul etsin.'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        _darkField(_codeCtl, 'Davet kodu', hint: 'ABCDE-FGHJK', key: const Key('inviteCode')),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: _GoldButton(
            label: 'Kodu gir',
            onTap: () => _run(() async {
              final err = await _sync.redeemCode(_codeCtl.text);
              if (!mounted) return;
              if (err != null) {
                showNote(context, err);
              } else {
                _codeCtl.clear();
              }
            }),
          ),
        ),
        _paneText(
            _sync.profilePhone.isEmpty
                ? 'Numaranızı Ayarlar bölümüne kaydederseniz size gelen davetler burada kendiliğinden görünür.'
                : 'Numaranıza gelen davetler burada kendiliğinden görünür.',
            size: 11.5),
      ],
    );
  }

  Widget _settings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Ayarlar', sub: 'Profil'),
        _paneText(_syncText, size: 11.5, color: _sync.ready ? const Color(0xFF7FE0B0) : RC.creamSoft),
        if (_sync.ready) ...[
          _darkField(_nameCtl, 'Adınız', key: const Key('profileName'), caps: TextCapitalization.words),
          _darkField(_phoneCtl, 'Telefon numaranız',
              key: const Key('profilePhone'), keyboard: TextInputType.phone, hint: '05xx xxx xx xx'),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: _GoldButton(
              label: 'Kaydet',
              onTap: () => _run(() => _sync.saveProfile(_nameCtl.text, _phoneCtl.text), ok: 'Kaydedildi'),
            ),
          ),
          _paneText(
              'Adınız davet ettiğiniz kişilere görünür. Numaranız sunucuya yazılmaz ve kimseye gösterilmez; '
              'yalnızca size gelen davetleri bulmak için numaradan üretilen tek yönlü bir özet saklanır.',
              size: 11),
        ] else if (_sync.state == SyncState.error)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _GoldButton(label: 'Yeniden dene', onTap: _connect),
          ),
        Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 12), color: RC.gold(0.3)),
        _rules(),
      ],
    );
  }

  // ---------------- Zincir kartı ----------------

  Widget _circlePane(DuaCircle c) {
    final me = c.meOrNull;
    final active = c.active..sort((a, b) => _pct(b).compareTo(_pct(a)));
    final pending = c.pending;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          child: Column(
            children: [
              const OrnamentStar(color: RC.goldBorder, lineWidth: 26),
              const SizedBox(height: 2),
              _GoldTitle(c.name, size: 22),
              const SizedBox(height: 3),
              Text(
                  c.mine
                      ? (!c.remote && _sync.ready ? 'Sizin zinciriniz · yalnız bu telefonda' : 'Sizin zinciriniz')
                      : '${c.ownerName} oluşturdu',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFF2DDA8), fontSize: 12.5)),
              if (c.intent.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text('“${c.intent}”',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFC9D8CF), fontSize: 12, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 7),
              _StatusChip(done: c.isComplete),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(child: _Bar(value: c.percent / 100, ok: c.isComplete, height: 13, dark: true)),
                  const SizedBox(width: 8),
                  Text('%${c.percent}',
                      style: const TextStyle(color: RC.goldText, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        _stats(c),
        if (me != null) _myTask(c, me),
        if (c.mine && c.notice.isNotEmpty) _notice(c),
        _Parchment(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Katılımcılar',
                        style: TextStyle(color: RC.verseInk, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                  Text('${active.length} kişi',
                      style: const TextStyle(color: RC.verseInk, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            for (final m in active) _personRow(c, m, now),
            if (pending.isNotEmpty) ...[
              Container(height: 1, color: const Color(0x40966E1E)),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                child: Text(
                  '${pending.length} kişi henüz kabul etmedi; kabul edince listede yer alır. '
                  'Yanıt süresi $kInviteHours saattir.',
                  style: const TextStyle(color: RC.verseInk2, fontSize: 10.5, height: 1.35),
                ),
              ),
              for (final m in pending) _personRow(c, m, now),
            ],
          ],
        ),
        if (c.mine)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _ActButton(
                    icon: Icons.person_add_alt_1,
                    label: 'Kişi Ekle',
                    onTap: c.isComplete ? null : () => _edit(c, addPerson: true),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _ActButton(
                    icon: Icons.chat,
                    iconColor: const Color(0xFF35D07F),
                    label: 'WhatsApp Davet',
                    onTap: () => _invite(c),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(child: _ActButton(icon: Icons.settings, label: 'Düzenle', onTap: () => _edit(c))),
              ],
            ),
          ),
      ],
    );
  }

  int _pct(CircleMember m) => m.share == 0 ? 100 : m.done * 100 ~/ m.share;

  Widget _stats(DuaCircle c) {
    Widget cell(IconData icon, String value, String label) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 1),
            child: Column(
              children: [
                GoldIcon(icon, size: 19),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child:
                      Text(value, style: const TextStyle(color: RC.cream, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                Text(label, style: const TextStyle(color: RC.creamSoft, fontSize: 9.5)),
              ],
            ),
          ),
        );
    Widget sep() => Container(width: 1, height: 44, color: RC.gold(0.2));
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x59000000),
        border: Border.symmetric(horizontal: BorderSide(color: RC.gold(0.3))),
      ),
      child: Row(
        children: [
          cell(Icons.group, '${c.active.length}', 'Katılımcı'),
          sep(),
          cell(_typeIcon(c.type), trNum(c.total), 'Toplam'),
          sep(),
          cell(Icons.hourglass_bottom, trNum(c.remaining), 'Kalan'),
          sep(),
          cell(Icons.calendar_month, trDateShort(c.end), 'Son gün'),
        ],
      ),
    );
  }

  Widget _myTask(DuaCircle c, CircleMember me) {
    final finished = me.done >= me.share;
    Widget btn(String label, int add) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Semantics(
            button: true,
            label: add < 0 ? 'Görevimi tamamladım' : '$label ekle',
            child: GestureDetector(
              onTap: finished
                  ? null
                  : () {
                      _store.addMine(c, add < 0 ? me.share : add);
                      if (me.done >= me.share && mounted) {
                        showNote(context, 'Görevinizi tamamladınız. Allah kabul etsin.');
                      }
                    },
              child: Container(
                height: 30,
                constraints: const BoxConstraints(minWidth: 32),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: RC.darkPanel,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: RC.gold(0.75)),
                ),
                child: add < 0
                    ? const GoldIcon(Icons.check, size: 16)
                    : Text(label,
                        style: const TextStyle(color: RC.goldText, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0x24F0C75E), Color(0x0AF0C75E)]),
        border: Border(bottom: BorderSide(color: RC.gold(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Senin görevin:',
                    style: TextStyle(color: RC.goldText, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text('${trNum(me.done)} / ${trNum(me.share)}',
                    style: const TextStyle(color: RC.goldText, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(finished ? '${c.unit} · tamamlandı' : c.unit,
                    style: const TextStyle(color: Color(0xFFC9D8CF), fontSize: 11)),
              ],
            ),
          ),
          if (!finished) ...[btn('+1', 1), btn('+10', 10), btn('', -1)],
        ],
      ),
    );
  }

  Widget _notice(DuaCircle c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
      color: const Color(0x33E6C35A),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1, right: 6),
            child: GoldIcon(Icons.info_outline, size: 15),
          ),
          Expanded(child: Text(c.notice, style: const TextStyle(color: RC.cream, fontSize: 11, height: 1.4))),
          Semantics(
            button: true,
            label: 'Bilgiyi kapat',
            child: GestureDetector(
              onTap: () => _store.dismissNotice(c),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 15, color: RC.creamSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _personRow(DuaCircle c, CircleMember m, DateTime now) {
    final pct = _pct(m);
    final ok = !m.isPending && m.done >= m.share;
    final String badge;
    if (m.isPending) {
      final left = m.inviteLeft(now);
      badge = left.inHours >= 1 ? '${left.inHours} sa' : '${left.inMinutes.clamp(1, 59)} dk';
    } else {
      badge = ok ? 'Tamam' : '%$pct';
    }
    final canTap = c.mine && !m.isMe;
    return Semantics(
      button: canTap,
      child: InkWell(
        onTap: canTap ? () => _memberSheet(c, m) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x40966E1E)))),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: m.isPending
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE6C35A), Color(0xFFC29A2C)],
                        ),
                  color: m.isPending ? const Color(0x33966E1E) : null,
                  border: Border.all(color: const Color(0xFFFFF5D6), width: 1.5),
                  boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))],
                ),
                child: Text(m.isMe ? 'S' : m.name.characters.first.toUpperCase(),
                    style: const TextStyle(color: Color(0xFF1D1406), fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.isMe ? 'Sen' : m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: RC.verseInk, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    Text(
                      m.isPending
                          ? 'Bekliyor · ${trNum(m.share)} ${c.unit}'
                          : '${trNum(m.done)} / ${trNum(m.share)} ${c.unit}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: RC.verseInk2, fontSize: 10.5),
                    ),
                    if (!m.isPending) ...[
                      const SizedBox(height: 3),
                      _Bar(value: pct / 100, ok: ok, height: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: ok
                        ? const [Color(0xFFE6F6EC), Color(0xFFCDEBD8)]
                        : m.isPending
                            ? const [Color(0xFFF3ECD9), Color(0xFFE9DFC6)]
                            : const [Color(0xFFFFF0D9), Color(0xFFF8DCB0)],
                  ),
                  border: Border.all(
                      color: ok
                          ? const Color(0xFF9FD5B4)
                          : m.isPending
                              ? const Color(0x59966E1E)
                              : const Color(0xFFEFC58A)),
                ),
                child: Text(badge,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ok
                            ? const Color(0xFF1D6F47)
                            : m.isPending
                                ? RC.verseInk2
                                : const Color(0xFF9A5A0B))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _memberSheet(DuaCircle c, CircleMember m) async {
    final wa = waNumber(m.phone);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _pal.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Widget item(IconData icon, String text, VoidCallback? onTap, {String? sub}) => ListTile(
              enabled: onTap != null,
              leading: GoldIcon(icon, light: !_pal.night),
              title: Text(text, style: TextStyle(color: _pal.ink, fontWeight: FontWeight.w600)),
              subtitle: sub == null ? null : Text(sub, style: TextStyle(color: _pal.ink2, fontSize: 12)),
              onTap: onTap == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      onTap();
                    },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(m.name, style: TextStyle(color: _pal.ink, fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '${m.isPending ? 'Davet bekliyor' : 'Katıldı'} · Payı ${trNum(m.share)} ${c.unit}',
                  style: TextStyle(color: _pal.ink2, fontSize: 12.5),
                ),
              ),
              if (m.isPending)
                item(Icons.how_to_reg, 'Kabul etti olarak işaretle', () => _store.accept(c, m),
                    sub: c.remote
                        ? 'Uygulaması yoksa; ilerlemesini siz girersiniz'
                        : 'Daveti size WhatsApp\'tan kabul ettiyse'),
              // Uygulamadan katılan kişi ilerlemesini kendisi günceller.
              if (!m.isPending && m.uid == null)
                item(Icons.edit_note, 'Okuduğu sayıyı gir', () => _askDone(c, m), sub: 'Size bildirdiği okuma sayısı'),
              item(Icons.chat, 'WhatsApp ile yaz', wa.isEmpty ? null : () => _openWhatsApp(wa, inviteMessage(c, m)),
                  sub: wa.isEmpty ? 'Telefon numarası yok' : null),
              if (m.done == 0)
                item(Icons.person_remove, 'Zincirden çıkar', () => _store.removeMember(c, m), sub: 'Payı size döner'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _askDone(DuaCircle c, CircleMember m) async {
    final v = await showDialog<int>(
      context: context,
      builder: (_) => _NumberDialog(
        title: '${m.name} kaç ${c.unit} okudu?',
        initial: m.done,
        helper: 'En fazla ${trNum(m.share)}',
      ),
    );
    if (v != null) _store.setDone(c, m, v);
  }

  Future<void> _openWhatsApp(String number, String text) async {
    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) showNote(context, 'WhatsApp açılamadı.');
  }

  // ---------------- Diğer zincirler ----------------

  Widget _others(DuaCircle? cur) {
    final list = _store.circles;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = list[i];
          final on = cur?.id == c.id;
          return Semantics(
            button: true,
            selected: on,
            label: c.name,
            child: GestureDetector(
              onTap: () => setState(() {
                _selected = c.id;
                _menu = c.isComplete ? 'fin' : (c.mine ? 'mine' : 'joined');
              }),
              child: Container(
                width: 172,
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                decoration: BoxDecoration(
                  gradient: RC.darkPanel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: on ? const Color(0xFFE6C35A) : RC.gold(0.75), width: on ? 1.5 : 1),
                  boxShadow: on ? const [BoxShadow(color: Color(0x66E6C35A), blurRadius: 12)] : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0x4D000000),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: RC.gold(0.55)),
                          ),
                          child: GoldIcon(_typeIcon(c.type), size: 19),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: RC.cream, fontSize: 13, fontWeight: FontWeight.w700)),
                              Text('${c.active.length} kişi · ${trNum(c.total)} ${c.unit}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: RC.creamSoft, fontSize: 10.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _Bar(value: c.percent / 100, ok: c.isComplete, height: 7, dark: true),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('%${c.percent}', style: const TextStyle(color: RC.creamSoft, fontSize: 10.5)),
                        const Spacer(),
                        Text('Son gün ${trDateShort(c.end)}',
                            style: const TextStyle(color: RC.creamSoft, fontSize: 10.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

IconData _typeIcon(String type) => switch (type) {
      'salavat' => Icons.nightlight_round,
      'yasin' || 'hatim' => Icons.menu_book,
      'ihlas' => Icons.star,
      'istigfar' => Icons.volunteer_activism,
      _ => Icons.edit,
    };

IconData typeIcon(String type) => _typeIcon(type);

// ---------------- Küçük parçalar ----------------

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RailButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? const Color(0xFFFBE7A8) : RC.cream;
    final accent = selected ? RC.bronzeText : const Color(0xFFE2C584);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42), // 9 tuş telefona kaydırmadan sığsın
          padding: const EdgeInsets.fromLTRB(5, 4, 4, 4),
          decoration: BoxDecoration(
            gradient: selected
                ? RC.bronze
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF062A1D), Color(0xFF01170F), Color(0xFF000C07)],
                  ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? RC.bronzeBorder : RC.gold(0.75), width: selected ? 1.5 : 1),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x80F0C75E), blurRadius: 14)]
                : const [BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dar ekranda kesilmesin: sığmazsa yazı küçülür.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(title,
                          maxLines: 1,
                          style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.2)),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(subtitle,
                          maxLines: 1,
                          style: TextStyle(color: selected ? const Color(0xFFE9D49A) : RC.creamSoft, fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Altın çerçeveli koyu yeşil panel, üst köşelerde süs.
class _Pane extends StatelessWidget {
  final Widget child;

  const _Pane({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0B64A), width: 1.5),
        gradient: const RadialGradient(
          center: Alignment(0, -1),
          radius: 1.2,
          colors: [Color(0xFF0A3323), Color(0xFF021A11), Color(0xFF000C07)],
          stops: [0, 0.45, 1],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFF000806), spreadRadius: 3),
          BoxShadow(color: Color(0x8CE0B64A), spreadRadius: 4.5),
          BoxShadow(color: Color(0x99000000), blurRadius: 26, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            child,
            const Positioned(top: 3, left: 3, child: _Corner()),
            const Positioned(top: 3, right: 3, child: _Corner(flip: true)),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final bool flip;

  const _Corner({this.flip = false});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.flip(
        flipX: flip,
        child: const SizedBox(width: 40, height: 40, child: CustomPaint(painter: _CornerPainter())),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 40;
    final p = Paint()
      ..color = const Color(0xE6CFAE68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s;
    canvas.drawPath(
      Path()
        ..moveTo(3 * s, 30 * s)
        ..lineTo(3 * s, 9 * s)
        ..arcToPoint(Offset(9 * s, 3 * s), radius: Radius.circular(6 * s))
        ..lineTo(30 * s, 3 * s),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(8 * s, 24 * s)
        ..lineTo(8 * s, 13 * s)
        ..arcToPoint(Offset(13 * s, 8 * s), radius: Radius.circular(5 * s))
        ..lineTo(24 * s, 8 * s),
      p,
    );
    canvas.drawCircle(Offset(9 * s, 9 * s), 2.4 * s, Paint()..color = const Color(0xE6CFAE68));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoldTitle extends StatelessWidget {
  final String text;
  final double size;

  const _GoldTitle(this.text, {required this.size});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF6E6BE), Color(0xFFE3C07A), Color(0xFFB8914A)],
        stops: [0, 0.55, 1],
      ).createShader(r),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: size, fontWeight: FontWeight.w700, height: 1.15),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool done;

  const _StatusChip({required this.done});

  @override
  Widget build(BuildContext context) {
    final dot = done ? const Color(0xFFE6C35A) : const Color(0xFF4FE0A6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x80E2C26E)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x59000000), Color(0x26000000)],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: dot, boxShadow: [BoxShadow(color: dot, blurRadius: 6)]),
          ),
          const SizedBox(width: 5),
          Text(done ? 'Tamamlandı' : 'Devam Ediyor',
              style: const TextStyle(color: Color(0xFFF2DDA8), fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// İlerleme çubuğu (altın; tamamlanınca yeşil).
class _Bar extends StatelessWidget {
  final double value;
  final bool ok;
  final double height;
  final bool dark;

  const _Bar({required this.value, required this.ok, required this.height, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: dark ? const Color(0x1FFFFFFF) : const Color(0x33966E1E),
        borderRadius: BorderRadius.circular(99),
        border: dark && height > 10 ? Border.all(color: const Color(0x73E2C26E)) : null,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LinearGradient(
              colors: ok
                  ? const [Color(0xFF1C7A4A), Color(0xFF3FC57C)]
                  : const [Color(0xFFC9922E), Color(0xFFF9C265), Color(0xFFFFE3A0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _Parchment extends StatelessWidget {
  final List<Widget> children;

  const _Parchment({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDF0D2), Color(0xFFF3DFB4)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _ActButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color iconColor;

  const _ActButton({required this.icon, required this.label, required this.onTap, this.iconColor = RC.goldIcon});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            decoration: BoxDecoration(
              gradient: RC.darkPanel,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: RC.gold(0.75)),
              boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: iconColor),
                const SizedBox(height: 2),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(color: RC.cream, fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DarkItem({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
          decoration: BoxDecoration(
            gradient: RC.darkPanel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RC.gold(0.75)),
          ),
          child: Row(
            children: [
              GoldIcon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(color: RC.goldText, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(subtitle, style: const TextStyle(color: Color(0xFFC9D8CF), fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GoldButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF8A6414)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE6C35A), Color(0xFFC29A2C)],
            ),
          ),
          child:
              Text(label, style: const TextStyle(color: Color(0xFF1D1406), fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _NumberDialog extends StatefulWidget {
  final String title;
  final int initial;
  final String helper;

  const _NumberDialog({required this.title, required this.initial, required this.helper});

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _ctl = TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctl,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(helperText: widget.helper),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        TextButton(
          onPressed: () => Navigator.pop(context, int.tryParse(_ctl.text.trim())),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
