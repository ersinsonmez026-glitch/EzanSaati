import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/circle_sync.dart';
import '../services/dua_circle_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'dua_circle_screen.dart' show typeIcon;
import '../widgets/gold_icon.dart';

/// Yeni zincir oluşturma ya da mevcut zinciri düzenleme.
/// Sonuç olarak kaydedilen zincir döner.
class DuaCircleFormScreen extends StatefulWidget {
  final DuaCircle? circle;
  final (String, String, int)? template;
  final bool addPerson;

  const DuaCircleFormScreen({super.key, this.circle, this.template, this.addPerson = false});

  @override
  State<DuaCircleFormScreen> createState() => _DuaCircleFormScreenState();
}

class _Row {
  final CircleMember member;
  final TextEditingController ctl;
  final bool isNew;

  _Row(this.member, {this.isNew = false}) : ctl = TextEditingController(text: '${member.share}');
}

class _DuaCircleFormScreenState extends State<DuaCircleFormScreen> {
  static const _weekdays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  final _name = TextEditingController();
  final _total = TextEditingController();
  final _intent = TextEditingController();
  final _rows = <_Row>[];
  late String _type;
  late DateTime _end;
  late final DateTime _start; // son gün sınırı bu tarihten itibaren sayılır

  bool get _editing => widget.circle != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final c = widget.circle;
    if (c != null) {
      _type = c.type;
      _name.text = c.name;
      _total.text = '${c.total}';
      _intent.text = c.intent;
      _end = c.end;
      _start = DateTime(c.created.year, c.created.month, c.created.day);
      for (final m in c.members) {
        _rows.add(_Row(m.copy()));
      }
    } else {
      final t = widget.template;
      _type = t?.$1 ?? 'salavat';
      final type = kDuaTypesByKey[_type]!;
      _name.text = t?.$2 ?? '${type.defaultTotal} ${type.title}';
      _total.text = '${t?.$3 ?? type.defaultTotal}';
      _start = DateTime(now.year, now.month, now.day);
      _end = _start.add(const Duration(days: 7));
      _rows.add(_Row(CircleMember(name: 'Ben', status: MemberStatus.me)));
      _even();
    }
    if (widget.addPerson) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickContact());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _total.dispose();
    _intent.dispose();
    for (final r in _rows) {
      r.ctl.dispose();
    }
    super.dispose();
  }

  int get _totalValue => int.tryParse(_total.text.trim()) ?? 0;
  int get _sum => _rows.fold(0, (s, r) => s + (int.tryParse(r.ctl.text.trim()) ?? 0));
  _Row get _meRow => _rows.firstWhere((r) => r.member.isMe);

  void _setShare(_Row r, int v) {
    r.ctl.text = '$v';
  }

  /// Toplamı herkese eşit böler (kurucu dahil).
  void _even() {
    final parts = splitEvenly(_totalValue, _rows.length);
    for (var i = 0; i < _rows.length; i++) {
      _setShare(_rows[i], parts[i]);
    }
    setState(() {});
  }

  void _selectType(String key) {
    if (_editing) return;
    final t = kDuaTypesByKey[key]!;
    setState(() {
      _type = key;
      _total.text = '${t.defaultTotal}';
      _name.text = key == 'ozel' ? '' : (key == 'hatim' ? 'Hatim' : '${t.defaultTotal} ${t.title}');
    });
    _even();
  }

  // ---------------- Kişi ekleme ----------------

  Future<void> _pickContact() async {
    (String, String)? r;
    try {
      r = await ContactPicker.pick();
    } on UnsupportedError {
      r = await _manualEntry();
    }
    if (r == null || !mounted) return;
    _addPerson(r.$1, r.$2);
  }

  Future<(String, String)?> _manualEntry() =>
      showDialog<(String, String)>(context: context, builder: (_) => const _PersonDialog());

  void _addPerson(String name, String phone) {
    if (name.isEmpty && phone.isEmpty) return;
    final wa = waNumber(phone);
    final dup = _rows.any((r) =>
        !r.member.isMe &&
        ((wa.isNotEmpty && waNumber(r.member.phone) == wa) ||
            (wa.isEmpty && r.member.name.toLowerCase() == name.toLowerCase())));
    if (dup) {
      showNote(context, '${name.isEmpty ? phone : name} zaten listede');
      return;
    }
    final row = _Row(CircleMember(name: name.isEmpty ? phone : name, phone: phone), isNew: true);
    setState(() => _rows.add(row));
    if (_editing) {
      // Yeni kişiye kurucunun henüz okunmamış payının yarısı verilir; elle değiştirilebilir.
      final me = _meRow;
      final meShare = int.tryParse(me.ctl.text.trim()) ?? 0;
      final free = (meShare - me.member.done).clamp(0, meShare);
      final give = free ~/ 2 > 0 ? free ~/ 2 : free;
      _setShare(me, meShare - give);
      _setShare(row, give);
      setState(() {});
    } else {
      _even();
    }
  }

  void _removeRow(_Row r) {
    if (r.member.isMe || r.member.done > 0) return;
    final share = int.tryParse(r.ctl.text.trim()) ?? 0;
    setState(() => _rows.remove(r));
    r.ctl.dispose();
    if (_editing) {
      final me = _meRow;
      _setShare(me, (int.tryParse(me.ctl.text.trim()) ?? 0) + share);
      setState(() {});
    } else {
      _even();
    }
  }

  // ---------------- Kaydetme ----------------

  String? _validate() {
    final total = _totalValue;
    if (_name.text.trim().isEmpty) {
      return _type == 'ozel' ? 'Okunacak duanın adını yazın' : 'Zincire bir ad verin';
    }
    if (total < 1) return 'Toplam adet en az 1 olmalı';
    if (_rows.length < 2) return 'Rehberden en az bir kişi ekleyin';
    final sum = _sum;
    if (sum != total) return 'Paylaşılan toplam (${trNum(sum)}) hedefle (${trNum(total)}) aynı olmalı';
    for (final r in _rows) {
      final v = int.tryParse(r.ctl.text.trim()) ?? 0;
      if (v < r.member.done) {
        return '${r.member.isMe ? 'Sizin' : r.member.name} payı, okuduğu ${trNum(r.member.done)} adetten az olamaz';
      }
      if (!r.member.isMe && v < 1) return '${r.member.name} için en az 1 adet yazın';
    }
    return null;
  }

  bool _saving = false;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_saving) return;
    final err = _validate();
    if (err != null) {
      showNote(context, err);
      return;
    }
    // Ortak zincirde davet edilenler kurucunun adını görür.
    final sync = CircleSync.instance;
    if (!_editing && sync.ready && sync.profileName.isEmpty) {
      final name = await showDialog<String>(context: context, builder: (_) => const _NameDialog());
      if (name == null || name.trim().isEmpty || !mounted) return;
      await sync.saveProfile(name, sync.profilePhone);
      if (!mounted) return;
    }
    final now = DateTime.now();
    for (final r in _rows) {
      r.member.share = int.parse(r.ctl.text.trim());
      if (r.isNew) r.member.invitedAt = now;
    }
    final members = [for (final r in _rows) r.member];
    final DuaCircle c;
    final old = widget.circle;
    if (old != null) {
      c = old
        ..name = _name.text.trim()
        ..intent = _intent.text.trim()
        ..total = _totalValue
        ..end = _end
        ..members = members;
    } else {
      c = DuaCircle(
        id: now.microsecondsSinceEpoch.toString(),
        type: _type,
        name: _name.text.trim(),
        intent: _intent.text.trim(),
        total: _totalValue,
        created: now,
        end: _end,
        members: members,
      );
    }
    setState(() => _saving = true);
    try {
      final saved = await DuaCircleStore.instance.save(c, isNew: old == null);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showNote(context, 'Kaydedilemedi. İnternet bağlantınızı kontrol edin.');
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zincir silinsin mi?'),
        content: Text(widget.circle!.remote
            ? '"${widget.circle!.name}" ve tüm ilerlemesi bütün katılımcılar için silinecek.'
            : '"${widget.circle!.name}" ve tüm ilerlemesi bu telefondan silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await DuaCircleStore.instance.delete(widget.circle!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showNote(context, 'Silinemedi. İnternet bağlantınızı kontrol edin.');
    }
  }

  Future<void> _chooseEnd() async {
    final days = [for (var i = 1; i <= kCircleMaxDays; i++) _start.add(Duration(days: i))];
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final options = days.where((d) => !d.isBefore(today)).toList();
    final r = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: _pal.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Son gün (en fazla $kCircleMaxDays gün)',
                  style: TextStyle(color: _pal.ink, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in options)
                    ListTile(
                      dense: true,
                      selected: d == _end,
                      selectedColor: _pal.gold,
                      title: Text('${trDate(d)} ${d.year} · ${_weekdays[d.weekday - 1]}',
                          style: TextStyle(color: d == _end ? _pal.gold : _pal.ink)),
                      trailing:
                          Text('${d.difference(today).inDays} gün', style: TextStyle(color: _pal.ink2, fontSize: 12)),
                      onTap: () => Navigator.pop(ctx, d),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (r != null) setState(() => _end = r);
  }

  // ---------------- Görünüm ----------------

  @override
  Widget build(BuildContext context) {
    final total = _totalValue, sum = _sum;
    final type = kDuaTypesByKey[_type]!;
    return PageShell(
      title: _editing ? 'Zinciri Düzenle' : 'Yeni Zincir',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      children: [
        PaperBox(
          pal: _pal,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('OKUNACAK DUA'),
              _types(),
              _label(_type == 'ozel' ? 'DUANIN ADI' : 'ÇEMBERİN ADI'),
              _input(_name,
                  hint: _type == 'ozel' ? 'Ör. Kelime-i Tevhid' : null, maxLength: 40, key: const Key('cName')),
              _label('TOPLAM ADET (${type.unit})'),
              _input(_total,
                  number: true,
                  enabled: true,
                  key: const Key('cTotal'),
                  onChanged: (_) => _editing ? setState(() {}) : _even()),
              _label('SON GÜN'),
              _dateField(),
              _label('NİYET (İSTEĞE BAĞLI)'),
              _input(_intent, hint: 'Ör. Hastalarımızın şifası için', maxLength: 80),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PaperBox(
          pal: _pal,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('KİŞİLER VE DAĞITIM'),
              for (var i = 0; i < _rows.length; i++) ...[
                if (i > 0) DashedLine(color: _pal.line),
                _personRow(_rows[i]),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child:
                        Text('${_rows.length} kişi · ${type.unit}', style: TextStyle(color: _pal.ink2, fontSize: 13)),
                  ),
                  Text('Dağıtılan: ', style: TextStyle(color: _pal.ink2, fontSize: 13)),
                  Text('${trNum(sum)} / ${trNum(total)}',
                      key: const Key('cSum'),
                      style: TextStyle(
                          color: sum == total ? _pal.ink : const Color(0xFFC0392B),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              if (sum != total)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    sum < total
                        ? 'Toplam tutmuyor: ${trNum(total - sum)} ${type.unit} dağıtılmadı.'
                        : 'Toplam tutmuyor: ${trNum(sum - total)} ${type.unit} fazla dağıtıldı.',
                    style: const TextStyle(color: Color(0xFFC0392B), fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _lightButton(Icons.contacts, 'Rehberden seç', _pickContact)),
                  const SizedBox(width: 8),
                  Expanded(child: _lightButton(Icons.balance, 'Eşit böl', _even)),
                ],
              ),
              const SizedBox(height: 8),
              _lightButton(Icons.person_add_alt, 'Numarayla ekle', () async {
                final r = await _manualEntry();
                if (r != null && mounted) _addPerson(r.$1, r.$2);
              }),
              const SizedBox(height: 8),
              Text(
                'Rehber izni istenmez; yalnızca seçtiğiniz kişi eklenir. Paylar eşit olmak zorunda değildir.',
                style: TextStyle(color: _pal.ink2, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: _save,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF8A6414)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE6C35A), Color(0xFFC29A2C)],
                ),
              ),
              child: Text(_editing ? 'Kaydet' : 'Zinciri oluştur ve davet gönder',
                  style: const TextStyle(color: Color(0xFF1D1406), fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        if (_editing) ...[
          const SizedBox(height: 10),
          DarkButton(label: 'Zinciri sil', onTap: _delete),
        ],
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child:
            Text(t, style: TextStyle(color: _pal.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );

  Widget _types() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.9,
      children: [
        for (final t in kDuaTypes)
          Opacity(
            opacity: _editing && t.key != _type ? 0.4 : 1,
            child: Semantics(
              button: true,
              selected: t.key == _type,
              child: GestureDetector(
                onTap: () => _selectType(t.key),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: t.key == _type ? RC.darkPanel : null,
                    color: t.key == _type ? null : _pal.chip,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.key == _type ? RC.gold(0.7) : _pal.line),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(typeIcon(t.key), size: 19, color: t.key == _type ? RC.goldText : _pal.gold),
                      const SizedBox(height: 2),
                      Text(t.title,
                          style: TextStyle(
                              color: t.key == _type ? RC.goldText : _pal.ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  InputDecoration _deco({String? hint}) => InputDecoration(
        isDense: true,
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(color: _pal.ink2, fontSize: 14),
        filled: true,
        fillColor: _pal.chip,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: _pal.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: _pal.gold, width: 1.5),
        ),
      );

  Widget _input(TextEditingController c,
      {String? hint,
      bool number = false,
      bool enabled = true,
      int? maxLength,
      Key? key,
      ValueChanged<String>? onChanged}) {
    return TextField(
      key: key,
      controller: c,
      enabled: enabled,
      maxLength: maxLength,
      cursorColor: _pal.gold,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)] : null,
      style: TextStyle(color: _pal.ink, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: _deco(hint: hint),
      onChanged: onChanged ?? (_) => setState(() {}),
    );
  }

  Widget _dateField() {
    return Semantics(
      button: true,
      label: 'Son gün: ${trDate(_end)}',
      child: GestureDetector(
        onTap: _chooseEnd,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _pal.chip,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _pal.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('${trDate(_end)} ${_end.year} · ${_weekdays[_end.weekday - 1]}',
                    style: TextStyle(color: _pal.ink, fontSize: 15, fontWeight: FontWeight.w500)),
              ),
              GoldIcon(Icons.calendar_month, size: 20, light: !_pal.night),
            ],
          ),
        ),
      ),
    );
  }

  Widget _personRow(_Row r) {
    final m = r.member;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.isMe ? 'Ben' : m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _pal.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
                if (!m.isMe || m.done > 0)
                  Text(
                    [
                      if (!m.isMe) m.phone.isEmpty ? 'Numara yok' : m.phone,
                      if (m.done > 0) '${trNum(m.done)} okundu',
                      if (!m.isMe && m.isPending && !r.isNew) 'bekliyor',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _pal.ink2, fontSize: 11.5),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: TextField(
              key: ValueKey('share:${m.isMe ? 'me' : m.name}'),
              controller: r.ctl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
              cursorColor: _pal.gold,
              style: TextStyle(color: _pal.ink, fontSize: 14, fontWeight: FontWeight.w700),
              decoration: _deco().copyWith(contentPadding: const EdgeInsets.symmetric(vertical: 9)),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            width: 34,
            child: m.isMe || m.done > 0
                ? null
                : IconButton(
                    tooltip: 'Çıkar',
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.close, color: _pal.ink2, size: 20),
                    onPressed: () => _removeRow(r),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _lightButton(IconData icon, String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _pal.chip,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _pal.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GoldIcon(icon, size: 17, light: !_pal.night),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _pal.ink, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adı ve numarası elle yazılarak kişi ekleme.
class _PersonDialog extends StatefulWidget {
  const _PersonDialog();

  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kişi ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Ad Soyad'),
          ),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefon (WhatsApp)', hintText: '05xx xxx xx xx'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        TextButton(
          onPressed: () => Navigator.pop(context, (_name.text.trim(), _phone.text.trim())),
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}

/// Ortak zincir kurulurken kurucunun adı (davet edilenler görür).
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adınız'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Davet ettiğiniz kişiler daveti sizin adınızla görür.'),
          TextField(
            controller: _ctl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Ad Soyad'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        TextButton(onPressed: () => Navigator.pop(context, _ctl.text.trim()), child: const Text('Devam')),
      ],
    );
  }
}
