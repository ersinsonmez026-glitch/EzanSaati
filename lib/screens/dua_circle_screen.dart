import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/cuz.dart';
import '../services/invite_watch.dart';
import '../services/prayer_groups.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';
import 'chain_counter_screen.dart';
import 'surah_read_screen.dart';
import '../services/app_theme.dart';

/// Dua Zinciri: kişi ne okunacağını, kaç tane olacağını ve süreyi seçer; zincirin bağlantısını
/// WhatsApp'tan istediği kişiye ya da gruba gönderir. Bağlantıyı açan payını alır.
class DuaCircleScreen extends StatefulWidget {
  const DuaCircleScreen({super.key});

  @override
  State<DuaCircleScreen> createState() => _DuaCircleScreenState();
}

// ============================================================ ortak parçalar

PagePalette get _pal => PagePalette.current();
GroupSync get _sync => GroupSync.instance;

Color get _wa => tc(0xFF1FAA55);

Widget _label(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(trUpper(t), style: TextStyle(color: _pal.gold, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
    );

Widget _bar(double v) => ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
          value: v, minHeight: 7, backgroundColor: _pal.line.withValues(alpha: 0.25), color: _pal.gold),
    );

Widget _goldButton(String t, VoidCallback? onTap, {IconData? icon, double h = 44, Key? key}) => Opacity(
      key: key,
      opacity: onTap == null ? 0.45 : 1,
      child: PillButton(
        pal: _pal,
        selected: true,
        height: h,
        radius: 12,
        onTap: onTap ?? () {},
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
          Flexible(child: Text(t, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );

Widget _plainButton(String t, VoidCallback onTap, {IconData? icon, double h = 42, Key? key}) => PillButton(
      key: key,
      pal: _pal,
      selected: false,
      height: h,
      radius: 12,
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 17, color: _pal.gold), const SizedBox(width: 6)],
        Flexible(child: Text(t, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
      ]),
    );

InputDecoration _deco({String? hint}) => InputDecoration(
      isDense: true,
      counterText: '',
      hintText: hint,
      hintStyle: TextStyle(color: _pal.ink2.withValues(alpha: 0.7), fontSize: 14),
      filled: true,
      fillColor: _pal.chip,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: _pal.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: _pal.gold, width: 1.5)),
    );

/// Tek satırlık yazı sorar; vazgeçilirse null.
Future<String?> _askText(BuildContext context, String title,
    {String? message, String? hint, String initial = '', bool number = false, int maxLength = 40, String ok = 'Tamam'}) {
  final c = TextEditingController(text: initial);
  final r = showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) ...[
            Text(message, style: const TextStyle(fontSize: 13.5, height: 1.4)),
            const SizedBox(height: 10),
          ],
          TextField(
            key: const Key('askText'),
            controller: c,
            autofocus: true,
            maxLength: maxLength,
            keyboardType: number ? TextInputType.number : TextInputType.text,
            inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
            textCapitalization: number ? TextCapitalization.none : TextCapitalization.words,
            decoration: InputDecoration(hintText: hint, counterText: ''),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(ok)),
      ],
    ),
  );
  // Yazı alanı, pencerenin kapanış animasyonu bittikten sonra bırakılır.
  unawaited(r.whenComplete(() => Future<void>.delayed(const Duration(milliseconds: 500), c.dispose)));
  return r;
}

Future<bool> _confirm(BuildContext context, String title, String message, {String ok = 'Evet'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

/// Grupta görünecek ad yoksa bir kez sorar.
Future<bool> _ensureName(BuildContext context) async {
  await _sync.load();
  if (_sync.myName.isNotEmpty) return true;
  if (!context.mounted) return false;
  final n = await _askText(context, 'Adınız',
      message: 'Zincirlerde bu adla görüneceksiniz. Sonradan değiştirebilirsiniz.', hint: 'Örn. Ayşe Demir', ok: 'Kaydet');
  if (n == null || n.isEmpty) return false;
  await _sync.saveName(n);
  await InviteWatch.requestPermission(); // zincir tamamlanınca bildirim gelebilsin
  return true;
}

/// Sunucu işlemini yürütür; hata olursa kısa not gösterir.
Future<bool> _run(BuildContext context, Future<void> Function() job, {String? ok}) async {
  try {
    await job();
    if (ok != null && context.mounted) showNote(context, ok);
    return true;
  } catch (e) {
    if (context.mounted) {
      showNote(context, e is StateError ? e.message : 'İşlem yapılamadı. İnternet bağlantınızı kontrol edin.');
    }
    return false;
  }
}

Future<void> _openWhatsApp(BuildContext context, String text) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) await shareText(context, text);
}

void _push(BuildContext context, Widget page) => Navigator.of(context).push(AppRoute(builder: (_) => page));

/// İnternet durumu.
Widget _syncNote(BuildContext context) {
  final s = _sync.state;
  if (s == SyncState.ready || s == SyncState.off && _sync.uid != null) return const SizedBox.shrink();
  final connecting = s == SyncState.connecting;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: PaperBox(
      pal: _pal,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(children: [
        Icon(connecting ? Icons.cloud_sync : Icons.cloud_off, color: _pal.gold, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(connecting ? 'Bağlanıyor…' : 'Dua zincirleri için internet bağlantısı gerekli.',
              style: TextStyle(color: _pal.ink2, fontSize: 12.5)),
        ),
        if (!connecting) TextButton(onPressed: () => _sync.start(), child: const Text('Tekrar dene')),
      ]),
    ),
  );
}

/// WhatsApp'tan davet gönder düğmesi (yeşil).
Widget _waButton(BuildContext context, GroupChain c) => Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('waInvite'),
        onTap: () => _openWhatsApp(context, chainInviteMessage(c)),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _wa, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chat, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text("WhatsApp'tan davet gönder",
                  style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );

/// Zincir kartı (sağ sütundaki listede): ad, durum, ilerleme ve payım.
class _ChainCard extends StatelessWidget {
  final GroupChain c;

  const _ChainCard(this.c);

  @override
  Widget build(BuildContext context) {
    final p = _pal;
    final me = _sync.uid ?? '';
    final String state;
    if (c.complete) {
      state = 'Tamamlandı';
    } else if (c.expired) {
      state = 'Süresi doldu';
    } else {
      state = c.daysLeft == 0 ? 'Bugün bitiyor' : '${c.daysLeft} gün kaldı';
    }
    final String mine;
    if (c.isHatim) {
      final parts = c.partsOf(me);
      final read = parts.where((n) => c.slots[n]?.done ?? false).length;
      mine = parts.isEmpty ? '' : 'Payınız: $read/${parts.length} cüz';
    } else {
      final m = c.claimOf(me);
      mine = m == null ? '' : 'Payınız: ${trNum(m.done)}/${trNum(m.amount)}';
    }
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _push(context, ChainScreen(chainId: c.id)),
        child: PaperBox(
          pal: p,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (c.complete) const Icon(Icons.check_circle, color: Color(0xFF2E9E57), size: 18),
            ]),
            Text(c.creatorUid == me ? state : '${c.creatorName} · $state',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.gold, fontSize: 11.5)),
            const SizedBox(height: 5),
            _bar(c.progress),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(mine, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.ink2, fontSize: 11.5)),
              ),
              Text(c.isHatim ? '${c.done}/30 cüz' : '${trNum(c.done)}/${trNum(c.total)}',
                  style: TextStyle(color: p.ink, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// "7, 8 ve 9." gibi cüz listesi.
String _partsText(List<int> parts) {
  if (parts.isEmpty) return '';
  if (parts.length == 1) return '${parts.first}.';
  return '${parts.sublist(0, parts.length - 1).join(', ')} ve ${parts.last}.';
}

// ============================================================ ana sayfa

/// Ayarlar: zincirlerde görünen adı değiştirir.
Future<void> editChainName(BuildContext context) async {
  await _sync.load();
  if (!context.mounted) return;
  final n = await _askText(context, 'Zincirlerde görünen adınız', initial: _sync.myName, hint: 'Örn. Ayşe Demir', ok: 'Kaydet');
  if (n != null && n.isNotEmpty && context.mounted) await _run(context, () => _sync.saveName(n), ok: 'Kaydedildi');
}

/// Ayarlar: uygulamayı WhatsApp'tan önerir.
Future<void> recommendApp(BuildContext context) => _openWhatsApp(context, appSuggestMessage());

enum _Pane { create, mine, joined }

class _DuaCircleScreenState extends State<DuaCircleScreen> {
  _Pane? _pane;
  String _type = 'salavat';
  bool _busy = false;
  final _total = TextEditingController(text: '1000');
  final _days = TextEditingController(text: '7');
  final _share = TextEditingController(text: '100');
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sync.addListener(_changed);
    _sync.start();
  }

  @override
  void dispose() {
    _sync.removeListener(_changed);
    _total.dispose();
    _days.dispose();
    _share.dispose();
    _name.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  List<GroupChain> get _started => _sync.chains.where((c) => c.creatorUid == _sync.uid).toList();
  List<GroupChain> get _joined => _sync.chains.where((c) => c.creatorUid != _sync.uid).toList();

  /// Açılışta: zinciri olan kendi zincirlerini, olmayan oluşturma formunu görür.
  _Pane get _current => _pane ?? (_started.isNotEmpty ? _Pane.mine : (_joined.isNotEmpty ? _Pane.joined : _Pane.create));

  void _setType(String t) {
    setState(() {
      _type = t;
      final d = kDuaTypesByKey[t]!;
      _total.text = '${d.defaultTotal}';
      _share.text = t == 'hatim' ? '1' : '${max(1, d.defaultTotal ~/ 10)}';
    });
  }

  /// Kaydet ve WhatsApp'tan davet et: zincir oluşur, kurucunun payı ayrılır (Zikir Sayacı'nda bekler),
  /// davet mesajı WhatsApp'ta hazır açılır.
  Future<void> _create() async {
    final t = kDuaTypesByKey[_type]!;
    final hatim = _type == 'hatim';
    final total = hatim ? 30 : int.tryParse(_total.text) ?? 0;
    final days = int.tryParse(_days.text) ?? 0;
    final share = int.tryParse(_share.text) ?? 0;
    final custom = _type == 'ozel';
    String? err;
    if (total <= 0 || total > 10000000) {
      err = 'Kaç tane okunacağını yazın.';
    } else if (custom && _name.text.trim().isEmpty) {
      err = 'Ne okunacağını yazın (örn. Kelime-i Tevhid).';
    } else if (days < 1 || days > kChainMaxDays) {
      err = 'Süre 1 ile $kChainMaxDays gün arasında olmalı.';
    } else if (share < 0 || share > total) {
      err = 'Kendi payınız en fazla ${trNum(total)} olabilir.';
    }
    if (err != null) {
      showNote(context, err);
      return;
    }
    if (!await _ensureName(context) || !mounted) return;
    final name = custom ? '${trNum(total)} ${_name.text.trim()}' : (hatim ? 'Hatim' : '${trNum(total)} ${t.title}');
    setState(() => _busy = true);
    GroupChain? c;
    final ok = await _run(context, () async {
      c = await _sync.startChain(type: _type, name: name, unit: custom ? 'adet' : t.unit, total: total, days: days);
      if (share > 0) {
        hatim ? await _sync.takeParts(c!, [for (var i = 1; i <= share; i++) i]) : await _sync.takeAmount(c!, share);
      }
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok || c == null) return;
    setState(() => _pane = _Pane.mine);
    if (share > 0) showNote(context, "Payınız Zikir Sayacı'na eklendi.");
    await _openWhatsApp(context, chainInviteMessage(c!));
  }

  @override
  Widget build(BuildContext context) {
    final p = _pal;
    final pane = _current;
    return PageShell(
      title: 'Dua Zinciri',
      background: p.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _syncNote(context),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 108,
            child: Column(children: [
              _menu('Zincir oluştur', Icons.add, pane == _Pane.create, () => setState(() => _pane = _Pane.create),
                  key: const Key('paneCreate')),
              _menu('Başlattıklarım', Icons.campaign_outlined, pane == _Pane.mine, () => setState(() => _pane = _Pane.mine),
                  count: _started.length, key: const Key('paneMine')),
              _menu('Katıldıklarım', Icons.groups_outlined, pane == _Pane.joined, () => setState(() => _pane = _Pane.joined),
                  count: _joined.length, key: const Key('paneJoined')),
            ]),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: switch (pane) {
              _Pane.create => _form(),
              _Pane.mine => _list(_started, 'Henüz başlattığınız zincir yok. "Zincir oluştur" ile başlayın.'),
              _Pane.joined => _list(_joined, 'Size gelen davet bağlantısına dokunduğunuzda zincir burada görünür.'),
            },
          ),
        ]),
      ],
    );
  }

  Widget _menu(String label, IconData icon, bool on, VoidCallback onTap, {int? count, Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
              decoration: BoxDecoration(
                gradient: on ? RC.bronze : RC.darkPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: on ? RC.bronzeBorder : RC.gold(0.75), width: on ? 1.5 : 1),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 19, color: on ? RC.bronzeText : RC.goldText),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(count == null || count == 0 ? label : '$label ($count)',
                      style: TextStyle(color: on ? RC.bronzeText : RC.cream, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _list(List<GroupChain> all, String empty) {
    final p = _pal;
    final active = all.where((c) => c.active).toList();
    final ended = all.where((c) => !c.active).take(5).toList();
    if (all.isEmpty) {
      return PaperBox(
        pal: p,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Text(empty, textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 13, height: 1.4)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final c in active) ...[_ChainCard(c), const SizedBox(height: 7)],
      if (ended.isNotEmpty) Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
        child: Text('BİTENLER', style: TextStyle(color: p.gold, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
      for (final c in ended) ...[_ChainCard(c), const SizedBox(height: 7)],
    ]);
  }

  Widget _field(TextEditingController c, {Key? key, String? hint}) => TextField(
        key: key,
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 8,
        style: TextStyle(color: _pal.ink, fontSize: 15, fontWeight: FontWeight.w700),
        decoration: _deco(hint: hint),
      );

  Widget _q(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 5),
        child: Text(t, style: TextStyle(color: _pal.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
      );

  Widget _form() {
    final p = _pal;
    final hatim = _type == 'hatim';
    return PaperBox(
      pal: p,
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _q('Ne okunacak?'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: p.chip,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: p.line),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('typePick'),
              value: _type,
              isExpanded: true,
              dropdownColor: p.night ? const Color(0xFF0B2A1E) : const Color(0xFFF3E7CC),
              iconEnabledColor: p.gold,
              style: TextStyle(color: p.ink, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Lora'),
              items: [for (final t in kDuaTypes) DropdownMenuItem(value: t.key, child: Text(t.title))],
              onChanged: (v) => v == null ? null : _setType(v),
            ),
          ),
        ),
        if (_type == 'ozel') ...[
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: p.ink, fontSize: 14.5),
            decoration: _deco(hint: 'Ne okunacak? (örn. Kelime-i Tevhid)'),
          ),
        ],
        _q('Kaç tane?'),
        if (hatim)
          Text('30 cüz', style: TextStyle(color: p.ink, fontSize: 15, fontWeight: FontWeight.w700))
        else
          _field(_total, key: const Key('total'), hint: 'Adet'),
        _q('Kaç gün?'),
        _field(_days, key: const Key('days'), hint: '1 – $kChainMaxDays gün'),
        _q(hatim ? 'Sen kaç cüz okuyacaksın?' : 'Sen kaç tane okuyacaksın?'),
        _field(_share, key: const Key('myShare'), hint: hatim ? 'Cüz' : 'Adet'),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          child: GestureDetector(
            key: const Key('doStart'),
            onTap: _busy ? null : _create,
            child: Opacity(
              opacity: _busy ? 0.5 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _wa, borderRadius: BorderRadius.circular(12)),
                child: Text(_busy ? 'Hazırlanıyor…' : "Kaydet ve WhatsApp'tan davet et",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.25)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text("Payınız Zikir Sayacı'na eklenir. Davete dokunan kişi kendi payını seçer.",
            textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 11.5, height: 1.35)),
      ]),
    );
  }
}

// ============================================================ zincir sayfası

class ChainScreen extends StatefulWidget {
  final String chainId;

  const ChainScreen({super.key, required this.chainId});

  @override
  State<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends State<ChainScreen> {
  bool _opening = false;
  bool _busy = false;
  final _picked = <int>{}; // hatimde okumak için seçilen boş cüzler
  final _amount = TextEditingController();
  bool _amountSet = false; // önerilen adet bir kez yazılır

  @override
  void initState() {
    super.initState();
    _sync.addListener(_changed);
    _open();
  }

  /// Bağlantıdan gelindiyse zinciri sunucudan açar.
  Future<void> _open() async {
    if (_sync.chain(widget.chainId) != null || _opening) return;
    setState(() => _opening = true);
    await _sync.start();
    try {
      if (_sync.ready) await _sync.open(widget.chainId);
    } catch (_) {}
    if (mounted) setState(() => _opening = false);
  }

  @override
  void dispose() {
    _sync.removeListener(_changed);
    _amount.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    // İnternet sonradan geldiyse (Tekrar dene) bağlantıdaki zincir yeniden açılır.
    if (_sync.ready && !_opening && _sync.chain(widget.chainId) == null && !_sync.isMissing(widget.chainId)) {
      _open();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _pal;
    final c = _sync.chain(widget.chainId);
    if (c == null) {
      final missing = _sync.isMissing(widget.chainId);
      return PageShell(title: 'Dua Zinciri', background: p.background, padding: const EdgeInsets.all(16), children: [
        _syncNote(context),
        const SizedBox(height: 30),
        if (_opening || _sync.state == SyncState.connecting)
          Center(child: CircularProgressIndicator(color: p.gold))
        else
          Text(
            missing ? 'Bu zincir bulunamadı. Silinmiş ya da bağlantı eksik olabilir.' : 'Zincir açılamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.ink2, fontSize: 14.5, height: 1.4),
          ),
      ]);
    }
    final me = _sync.uid ?? '';
    final mineAny = c.hasShare(me);
    final sub = [
      c.creatorUid == me ? 'Siz başlattınız' : 'Başlatan: ${c.creatorName}',
      if (c.complete) 'Tamamlandı' else if (c.expired) 'Süresi doldu' else if (c.daysLeft == 0) 'Bugün bitiyor' else '${c.daysLeft} gün kaldı',
    ].join(' · ');
    return PageShell(
      title: c.isHatim ? 'Hatim' : c.name,
      subtitle: sub,
      background: p.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (c.full && !mineAny && c.active) ...[
          PaperBox(
            pal: p,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(children: [
              Icon(Icons.groups, color: p.gold, size: 28),
              const SizedBox(height: 4),
              Text('Zincir doldu', style: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                c.isHatim ? 'Bütün cüzler alındı. Okunuşu buradan takip edebilirsiniz.' : 'Bütün paylar alındı. Okunuşu buradan takip edebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.ink2, fontSize: 13, height: 1.4),
              ),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        if (c.isHatim) ..._hatim(context, c) else ..._count(context, c),
        if (c.active && !c.full) ...[
          const SizedBox(height: 12),
          _waButton(context, c),
        ],
        const SizedBox(height: 8),
        if (_sync.canDelete(c))
          Center(
            child: TextButton(
              onPressed: () async {
                final ok = await _confirm(context, 'Zinciri sil', 'Bu zincir katılan herkes için silinecek. Emin misiniz?',
                    ok: 'Sil');
                if (!ok || !context.mounted) return;
                if (await _run(context, () => _sync.deleteChain(c)) && context.mounted) Navigator.of(context).pop();
              },
              child: Text('Zinciri sil', style: TextStyle(color: p.ink2, fontSize: 13.5)),
            ),
          )
        else if (_sync.isMember(c) && !mineAny)
          Center(
            child: TextButton(
              onPressed: () async {
                if (await _run(context, () => _sync.leave(c)) && context.mounted) Navigator.of(context).pop();
              },
              child: Text('Listemden kaldır', style: TextStyle(color: p.ink2, fontSize: 13.5)),
            ),
          ),
      ],
    );
  }

  // ---------------- ortak

  /// "Şu ana kadar: 6.250 / 10.000" özeti.
  Widget _summary(GroupChain c) {
    final p = _pal;
    return PaperBox(
      pal: p,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Şu ana kadar', style: TextStyle(color: p.ink2, fontSize: 12.5)),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Text('${trNum(c.done)} / ${trNum(c.total)}${c.isHatim ? ' cüz' : ''}',
                style: TextStyle(color: p.ink, fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          Text(c.full ? 'Bütün paylar alındı' : '${trNum(c.free)} ${c.unit} boşta',
              style: TextStyle(color: p.ink2, fontSize: 12.5)),
        ]),
        const SizedBox(height: 6),
        _bar(c.progress),
      ]),
    );
  }

  /// Katılma: "Şimdi oku" ya da "Daha sonra".
  Widget _joinButtons({required VoidCallback? now, required VoidCallback? later}) => Row(children: [
        Expanded(child: _goldButton(_busy ? 'Bekleyin…' : 'Şimdi oku', _busy ? null : now, key: const Key('readNow'))),
        const SizedBox(width: 8),
        Expanded(
          child: Opacity(
            opacity: later == null || _busy ? 0.45 : 1,
            child: _plainButton('Daha sonra', _busy || later == null ? () {} : later, h: 44, key: const Key('readLater')),
          ),
        ),
      ]);

  Future<bool> _join(BuildContext context, Future<void> Function() take) async {
    if (!await _ensureName(context) || !context.mounted) return false;
    setState(() => _busy = true);
    final ok = await _run(context, take);
    if (mounted) setState(() => _busy = false);
    return ok;
  }

  /// Katılanlar: her kişinin okuduğu, ilerleme çubuğu, bitirince yeşil tik; altta toplam.
  Widget _people(GroupChain c, List<(String, int, int, String)> rows) {
    final p = _pal;
    const green = Color(0xFF2E9E57);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label('Katılanlar'),
      PaperBox(
        pal: p,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) DashedLine(color: p.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Expanded(
                  flex: 5,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rows[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
                    if (rows[i].$4.isNotEmpty) Text(rows[i].$4, style: TextStyle(color: p.ink2, fontSize: 11.5)),
                  ]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: rows[i].$3 == 0 ? 0 : rows[i].$2 / rows[i].$3,
                      minHeight: 6,
                      backgroundColor: p.line.withValues(alpha: 0.25),
                      color: rows[i].$2 >= rows[i].$3 ? green : p.gold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text('${trNum(rows[i].$2)}/${trNum(rows[i].$3)}',
                        maxLines: 1, style: TextStyle(color: p.ink2, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 20,
                  child: rows[i].$2 >= rows[i].$3 ? const Icon(Icons.check_circle, size: 18, color: green) : null,
                ),
              ]),
            ),
          ],
          if (rows.isNotEmpty) Divider(color: p.line, height: 10),
          Row(children: [
            Expanded(child: Text('Toplam', style: TextStyle(color: p.ink, fontSize: 14.5, fontWeight: FontWeight.w700))),
            Text('${trNum(c.done)} / ${trNum(c.total)}${c.isHatim ? ' cüz' : ''}',
                style: TextStyle(color: p.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    ]);
  }

  // ---------------- hatim

  List<Widget> _hatim(BuildContext context, GroupChain c) {
    final p = _pal;
    final me = _sync.uid ?? '';
    final mine = c.partsOf(me);
    final open = c.active;
    final picking = mine.isEmpty && open && !c.full; // ilk kez gelen: hangi cüzü okuyacağını seçer
    Widget cell(int n) {
      final s = c.slots[n];
      final own = s != null && s.uid == me;
      final picked = _picked.contains(n);
      final done = s?.done ?? false;
      final label = s == null ? (picked ? 'Seçildi' : (open ? 'Al' : '')) : (own ? 'Siz' : s.name.split(' ').first);
      return Semantics(
        button: true,
        label: '$n. cüz',
        child: GestureDetector(
          onTap: () => _tapPart(context, c, n, picking: picking),
          child: Container(
            decoration: BoxDecoration(
              gradient: (own && !done) || picked ? RC.bronze : null,
              color: done ? p.gold.withValues(alpha: 0.28) : (own || picked ? null : (s == null ? Colors.transparent : p.chip)),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: own || picked ? RC.bronzeBorder : (s == null && open ? p.gold : p.line),
                  width: s == null && open ? 1.4 : 1),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$n',
                    style: TextStyle(
                        color: (own && !done) || picked ? RC.bronzeText : p.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                if (done) ...[const SizedBox(width: 2), Icon(Icons.check, size: 13, color: p.gold)],
              ]),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: (own && !done) || picked ? RC.bronzeText : (s == null ? p.gold : p.ink2),
                      fontSize: 10.5,
                      fontWeight: s == null ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        ),
      );
    }

    final unread = mine.where((n) => !(c.slots[n]?.done ?? false)).toList();
    final byPerson = <String, List<int>>{};
    for (final e in c.slots.entries) {
      byPerson.putIfAbsent(e.value.uid, () => []).add(e.key);
    }
    final rows = [
      for (final e in byPerson.entries)
        (
          e.key == me ? 'Siz' : c.slots[e.value.first]!.name,
          e.value.where((n) => c.slots[n]!.done).length,
          e.value.length,
          '${_partsText(e.value..sort())} cüz',
        ),
    ]..sort((a, b) => a.$1 == 'Siz' ? -1 : (b.$1 == 'Siz' ? 1 : b.$3.compareTo(a.$3)));
    return [
      _summary(c),
      const SizedBox(height: 10),
      PaperBox(
        pal: p,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (picking) ...[
            Text('Hangi cüzü okuyacaksın?', style: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Boş cüzlere dokunarak seçin (birden çok seçebilirsiniz).', style: TextStyle(color: p.ink2, fontSize: 12.5)),
            const SizedBox(height: 10),
          ],
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.95,
            children: [for (var i = 1; i <= 30; i++) cell(i)],
          ),
          if (picking) ...[
            const SizedBox(height: 12),
            _joinButtons(
              now: _picked.isEmpty
                  ? null
                  : () async {
                      final parts = (_picked.toList()..sort());
                      if (await _join(context, () => _sync.takeParts(c, parts)) && context.mounted) {
                        setState(_picked.clear);
                        _read(context, parts.first);
                      }
                    },
              later: _picked.isEmpty
                  ? null
                  : () async {
                      final parts = (_picked.toList()..sort());
                      if (await _join(context, () => _sync.takeParts(c, parts)) && context.mounted) {
                        setState(_picked.clear);
                        showNote(context, 'Cüzleriniz ayrıldı. Dilediğinizde buradan okuyabilirsiniz.');
                      }
                    },
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text('Kendi cüzünüze dokunarak okuyun ya da okudum diye işaretleyin.',
                style: TextStyle(color: p.ink2, fontSize: 11.5)),
          ],
        ]),
      ),
      if (mine.isNotEmpty) ...[
        const SizedBox(height: 10),
        PaperBox(
          pal: p,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sizin cüzleriniz', style: TextStyle(color: p.ink2, fontSize: 12.5)),
                Text('${_partsText(mine)} cüz', style: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
            ),
            if (unread.isNotEmpty) ...[
              PillButton(pal: p, selected: false, height: 36, onTap: () => _read(context, unread.first), child: const Text('Oku')),
              const SizedBox(width: 6),
              PillButton(
                pal: p,
                selected: true,
                height: 36,
                onTap: () => _run(context, () async {
                  for (final n in unread) {
                    await _sync.markPart(c, n, true);
                  }
                }, ok: 'Allah kabul etsin'),
                child: const Text('Okudum'),
              ),
            ] else
              Icon(Icons.check_circle, color: p.gold),
          ]),
        ),
      ],
      if (rows.isNotEmpty) _people(c, rows),
    ];
  }

  void _read(BuildContext context, int part) {
    final (surah, ayah) = kCuzBaslangic[part - 1];
    _push(context, SurahReadScreen(surah: surah, startAyah: ayah));
  }

  Future<void> _tapPart(BuildContext context, GroupChain c, int n, {bool picking = false}) async {
    final me = _sync.uid ?? '';
    final s = c.slots[n];
    if (s == null) {
      if (!c.active) return;
      if (picking) {
        setState(() => _picked.contains(n) ? _picked.remove(n) : _picked.add(n));
        return;
      }
      if (!await _ensureName(context) || !context.mounted) return;
      if (await _confirm(context, '$n. cüz', '$n. cüzü de okumak için alıyor musunuz?', ok: 'Al') && context.mounted) {
        await _run(context, () => _sync.takeParts(c, [n]));
      }
    } else if (s.uid == me) {
      await _partSheet(context, c, n, s.done, canRelease: !s.done);
    } else {
      showNote(context, '$n. cüzü ${s.name} aldı${s.done ? ' ve okudu' : ''}.');
    }
  }

  Future<void> _partSheet(BuildContext context, GroupChain c, int n, bool done, {required bool canRelease}) async {
    final r = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('$n. cüz', style: const TextStyle(fontWeight: FontWeight.w700))),
          ListTile(leading: const Icon(Icons.menu_book), title: const Text('Oku'), onTap: () => Navigator.pop(ctx, 'oku')),
          ListTile(
            leading: Icon(done ? Icons.undo : Icons.check_circle),
            title: Text(done ? 'Okunmadı olarak işaretle' : 'Okudum'),
            onTap: () => Navigator.pop(ctx, 'isaret'),
          ),
          if (canRelease)
            ListTile(leading: const Icon(Icons.close), title: const Text('Cüzü bırak'), onTap: () => Navigator.pop(ctx, 'birak')),
        ]),
      ),
    );
    if (!context.mounted) return;
    switch (r) {
      case 'oku':
        _read(context, n);
      case 'isaret':
        await _run(context, () => _sync.markPart(c, n, !done), ok: done ? null : 'Allah kabul etsin');
      case 'birak':
        await _run(context, () => _sync.releasePart(c, n));
    }
  }

  // ---------------- sayılı zincir

  void _openCounter(BuildContext context, GroupChain c) => _push(context, ChainCounterScreen(chainId: c.id));

  List<Widget> _count(BuildContext context, GroupChain c) {
    final p = _pal;
    final me = _sync.uid ?? '';
    final mine = c.claimOf(me);
    final rows = [
      for (final x in c.claims.values) (x.uid == me ? 'Siz' : x.name, min(x.done, x.amount), x.amount, ''),
    ]..sort((a, b) => a.$1 == 'Siz' ? -1 : (b.$1 == 'Siz' ? 1 : b.$3.compareTo(a.$3)));
    if (!_amountSet && c.free > 0) {
      _amountSet = true;
      _amount.text = '${min(c.free, max(1, (c.total / 10).ceil()))}';
    }
    int? wanted() {
      final n = int.tryParse(_amount.text);
      if (n == null || n <= 0) {
        showNote(context, 'Kaç ${c.unit} okuyacağınızı yazın.');
        return null;
      }
      final now = _sync.chain(c.id) ?? c; // bu arada başkası almış olabilir
      if (n > now.free) {
        showNote(context, now.full ? 'Zincir doldu, bütün paylar alındı.' : 'En fazla ${trNum(now.free)} alabilirsiniz.');
        return null;
      }
      return n;
    }

    return [
      _summary(c),
      if (mine == null && c.active && !c.full) ...[
        const SizedBox(height: 10),
        PaperBox(
          pal: p,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Kaç ${c.unit} okuyacaksın?', style: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              SizedBox(
                width: 140,
                child: TextField(
                  key: const Key('amount'),
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 8,
                  style: TextStyle(color: p.ink, fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: _deco(hint: 'Adet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Boşta: ${trNum(c.free)}', style: TextStyle(color: p.ink2, fontSize: 13))),
            ]),
            const SizedBox(height: 10),
            _joinButtons(
              now: () async {
                final n = wanted();
                if (n == null) return;
                if (await _join(context, () => _sync.takeAmount(_sync.chain(c.id) ?? c, n)) && context.mounted) {
                  _openCounter(context, c);
                }
              },
              later: () async {
                final n = wanted();
                if (n == null) return;
                if (await _join(context, () => _sync.takeAmount(_sync.chain(c.id) ?? c, n)) && context.mounted) {
                  showNote(context, "Payınız Zikir Sayacı'na eklendi; dilediğinizde okuyabilirsiniz.");
                }
              },
            ),
          ]),
        ),
      ],
      if (mine != null) ...[
        const SizedBox(height: 10),
        PaperBox(
          pal: p,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sizin payınız', style: TextStyle(color: p.ink2, fontSize: 12.5)),
                  Text('${trNum(mine.done)} / ${trNum(mine.amount)} ${c.unit}',
                      style: TextStyle(color: p.ink, fontSize: 20, fontWeight: FontWeight.w700)),
                ]),
              ),
              if (mine.done < mine.amount)
                PillButton(
                  key: const Key('continueRead'),
                  pal: p,
                  selected: true,
                  height: 38,
                  onTap: () => _openCounter(context, c),
                  child: Text(mine.done == 0 ? 'Okumaya başla' : 'Devam et'),
                )
              else
                const Icon(Icons.check_circle, color: Color(0xFF2E9E57)),
            ]),
            const SizedBox(height: 6),
            _bar(mine.amount == 0 ? 0 : mine.done / mine.amount),
            if (mine.done >= mine.amount) ...[
              const SizedBox(height: 6),
              Center(child: Text('Payınızı tamamladınız · Allah kabul etsin', style: TextStyle(color: p.gold, fontSize: 13.5))),
            ],
            if (mine.done == 0 && c.active)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _run(context, () => _sync.releaseAmount(c)),
                  child: Text('Payı bırak', style: TextStyle(color: p.ink2, fontSize: 12.5)),
                ),
              ),
          ]),
        ),
      ],
      if (rows.isNotEmpty) _people(c, rows),
    ];
  }
}
