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

Widget _chip(String t, bool sel, VoidCallback onTap) => IntrinsicWidth(
      child: PillButton(
        pal: _pal,
        selected: sel,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        onTap: onTap,
        child: Text(t, style: const TextStyle(fontSize: 13.5)),
      ),
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

/// Zincir kartı (listede).
class _ChainCard extends StatelessWidget {
  final GroupChain c;

  const _ChainCard(this.c);

  @override
  Widget build(BuildContext context) {
    final p = _pal;
    final me = _sync.uid ?? '';
    final String mine;
    if (c.complete) {
      mine = 'Tamamlandı · Allah kabul etsin';
    } else if (c.expired) {
      mine = 'Süresi doldu';
    } else if (c.isHatim) {
      final parts = c.partsOf(me);
      mine = parts.isNotEmpty ? 'Sizin: ${_partsText(parts)} cüz' : (c.full ? 'Bütün cüzler alındı' : '${c.free} cüz boşta');
    } else {
      final cl = c.claimOf(me);
      mine = cl != null
          ? 'Sizin: ${trNum(cl.done)} / ${trNum(cl.amount)} okundu'
          : (c.full ? 'Bütün paylar alındı' : '${trNum(c.free)} ${c.unit} boşta');
    }
    final left = c.complete || c.expired ? '' : (c.daysLeft == 0 ? 'Bugün bitiyor' : '${c.daysLeft} gün kaldı');
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _push(context, ChainScreen(chainId: c.id)),
        child: PaperBox(
          pal: p,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.person, size: 16, color: p.gold),
              const SizedBox(width: 5),
              Expanded(
                child: Text(c.creatorUid == me ? 'Siz başlattınız' : 'Başlatan: ${c.creatorName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              Text(left, style: TextStyle(color: p.ink2, fontSize: 12)),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Expanded(
                child: Text(c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink, fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              Text(c.isHatim ? '${c.done}/30 cüz' : '${trNum(c.done)}/${trNum(c.total)}',
                  style: TextStyle(color: p.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            _bar(c.progress),
            const SizedBox(height: 7),
            Row(children: [
              Expanded(child: Text(mine, style: TextStyle(color: p.ink2, fontSize: 13))),
              if (c.complete)
                Icon(Icons.check_circle, color: p.gold, size: 20)
              else
                Icon(Icons.chevron_right, color: p.gold, size: 22),
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

class _DuaCircleScreenState extends State<DuaCircleScreen> {
  @override
  void initState() {
    super.initState();
    _sync.addListener(_changed);
    _sync.start();
  }

  @override
  void dispose() {
    _sync.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = _pal;
    final all = _sync.chains;
    final active = all.where((c) => c.active).toList();
    final ended = all.where((c) => !c.active).take(5).toList();
    return PageShell(
      title: 'Dua Zinciri',
      background: p.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _syncNote(context),
        _goldButton('Yeni zincir başlat', () => _push(context, const ChainStartScreen()),
            icon: Icons.add, h: 50, key: const Key('startChain')),
        if (all.isEmpty) ...[
          const SizedBox(height: 12),
          PaperBox(
            pal: p,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(children: [
              Text('Nasıl çalışır?', style: TextStyle(color: p.gold, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final (i, t) in [
                (1, 'Ne okunacağını, kaç tane olacağını ve süreyi seçin.'),
                (2, "Zincirin davetini WhatsApp'tan istediğiniz kişiye ya da gruba gönderin."),
                (3, 'Davete dokunan payını alır; herkes ne kadar okunduğunu görür.'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$i.', style: TextStyle(color: p.gold, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(t, style: TextStyle(color: p.ink2, fontSize: 13.5, height: 1.4))),
                  ]),
                ),
            ]),
          ),
        ],
        if (active.isNotEmpty) _label('Devam edenler'),
        for (final c in active) ...[_ChainCard(c), const SizedBox(height: 8)],
        if (ended.isNotEmpty) _label('Bitenler'),
        for (final c in ended) ...[_ChainCard(c), const SizedBox(height: 8)],
        const SizedBox(height: 10),
        _plainButton('Uygulamayı tavsiye et', () => _openWhatsApp(context, appSuggestMessage()), icon: Icons.share),
        if (_sync.myName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                final n = await _askText(context, 'Zincirlerde görünen adınız', initial: _sync.myName, ok: 'Kaydet');
                if (n != null && n.isNotEmpty && context.mounted) await _run(context, () => _sync.saveName(n), ok: 'Kaydedildi');
              },
              icon: Icon(Icons.edit, size: 16, color: p.gold),
              label: Text('Adım: ${_sync.myName}', style: TextStyle(color: p.ink2, fontSize: 13)),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================ zincir başlat

class ChainStartScreen extends StatefulWidget {
  const ChainStartScreen({super.key});

  @override
  State<ChainStartScreen> createState() => _ChainStartScreenState();
}

class _ChainStartScreenState extends State<ChainStartScreen> {
  String _type = 'hatim';
  int _days = 7;
  bool _busy = false;
  final _total = TextEditingController(text: '30');
  final _name = TextEditingController();

  @override
  void dispose() {
    _total.dispose();
    _name.dispose();
    super.dispose();
  }

  void _setType(String t) {
    setState(() {
      _type = t;
      _total.text = '${kDuaTypesByKey[t]!.defaultTotal}';
    });
  }

  Future<void> _start() async {
    final t = kDuaTypesByKey[_type]!;
    final total = _type == 'hatim' ? 30 : int.tryParse(_total.text) ?? 0;
    if (total <= 0 || total > 10000000) {
      showNote(context, 'Kaç tane okunacağını yazın.');
      return;
    }
    final custom = _type == 'ozel';
    if (custom && _name.text.trim().isEmpty) {
      showNote(context, 'Ne okunacağını yazın (örn. Kelime-i Tevhid).');
      return;
    }
    if (!await _ensureName(context) || !mounted) return;
    final name = custom ? '${trNum(total)} ${_name.text.trim()}' : (_type == 'hatim' ? 'Hatim' : '${trNum(total)} ${t.title}');
    setState(() => _busy = true);
    GroupChain? c;
    final ok = await _run(
      context,
      () async => c = await _sync.startChain(
          type: _type, name: name, unit: custom ? 'adet' : t.unit, total: total, days: _days),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && c != null) {
      Navigator.of(context).pushReplacement(AppRoute(builder: (_) => ChainScreen(chainId: c!.id, justCreated: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pal;
    return PageShell(
      title: 'Yeni Zincir',
      subtitle: 'Birlikte okuyalım',
      background: p.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _syncNote(context),
        PaperBox(
          pal: p,
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('1. Ne okunacak?'),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final t in kDuaTypes) _chip(t.title, _type == t.key, () => _setType(t.key)),
            ]),
            if (_type == 'ozel') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: p.ink, fontSize: 14.5),
                decoration: _deco(hint: 'Ne okunacak? (örn. Kelime-i Tevhid)'),
              ),
            ],
            _label('2. Kaç tane?'),
            if (_type == 'hatim')
              Text('30 cüz · her kişi okuyacağı cüzü kendisi alır.', style: TextStyle(color: p.ink2, fontSize: 13.5))
            else
              Row(children: [
                SizedBox(
                  width: 140,
                  child: TextField(
                    key: const Key('total'),
                    controller: _total,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 8,
                    style: TextStyle(color: p.ink, fontSize: 15, fontWeight: FontWeight.w700),
                    decoration: _deco(hint: 'Adet'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Herkes okuyabileceği kadarını alır.', style: TextStyle(color: p.ink2, fontSize: 12.5)),
                ),
              ]),
            _label('3. Ne zamana kadar?'),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final (d, t) in [(3, '3 gün'), (7, '1 hafta'), (15, '15 gün'), (kChainMaxDays, '1 ay')])
                _chip(t, _days == d, () => setState(() => _days = d)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        _goldButton(_busy ? 'Hazırlanıyor…' : 'Zinciri oluştur', _busy ? null : _start, h: 50, key: const Key('doStart')),
        const SizedBox(height: 6),
        Text("Sonraki adımda davetini WhatsApp'tan gönderirsiniz.",
            textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 12.5)),
      ],
    );
  }
}

// ============================================================ zincir sayfası

class ChainScreen extends StatefulWidget {
  final String chainId;

  /// Zincir az önce oluşturuldu: davet gönderme öne çıkar.
  final bool justCreated;

  const ChainScreen({super.key, required this.chainId, this.justCreated = false});

  @override
  State<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends State<ChainScreen> {
  bool _opening = false;

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
        if (widget.justCreated && c.active) ...[
          PaperBox(
            pal: p,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Zincir hazır', textAlign: TextAlign.center,
                  style: TextStyle(color: p.gold, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Davetini WhatsApp\'tan istediğiniz kişiye ya da gruba gönderin. Davete dokunan payını alır.',
                  textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 13.5, height: 1.4)),
              const SizedBox(height: 12),
              _waButton(context, c),
            ]),
          ),
          const SizedBox(height: 10),
        ],
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
        if (!widget.justCreated && c.active && !c.full) ...[
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

  // ---------------- hatim

  List<Widget> _hatim(BuildContext context, GroupChain c) {
    final p = _pal;
    final me = _sync.uid ?? '';
    final mine = c.partsOf(me);
    final open = c.active;
    Widget cell(int n) {
      final s = c.slots[n];
      final own = s != null && s.uid == me;
      final done = s?.done ?? false;
      final label = s == null ? (open ? 'Al' : '') : (own ? 'Siz' : s.name.split(' ').first);
      return Semantics(
        button: true,
        label: '$n. cüz',
        child: GestureDetector(
          onTap: () => _tapPart(context, c, n),
          child: Container(
            decoration: BoxDecoration(
              gradient: own && !done ? RC.bronze : null,
              color: done ? p.gold.withValues(alpha: 0.28) : (own ? null : (s == null ? Colors.transparent : p.chip)),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: own ? RC.bronzeBorder : (s == null && open ? p.gold : p.line), width: s == null && open ? 1.4 : 1),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$n',
                    style: TextStyle(
                        color: own && !done ? RC.bronzeText : p.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                if (done) ...[const SizedBox(width: 2), Icon(Icons.check, size: 13, color: p.gold)],
              ]),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: own && !done ? RC.bronzeText : (s == null ? p.gold : p.ink2),
                      fontSize: 10.5,
                      fontWeight: s == null ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        ),
      );
    }

    Widget key(Color? col, String t, {Gradient? g, Color? b}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                  color: col, gradient: g, borderRadius: BorderRadius.circular(3), border: Border.all(color: b ?? p.line))),
          const SizedBox(width: 4),
          Text(t, style: TextStyle(color: p.ink2, fontSize: 11.5)),
        ]);

    final unread = mine.where((n) => !(c.slots[n]?.done ?? false)).toList();
    return [
      PaperBox(
        pal: p,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text('${c.done} cüz okundu',
                    style: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w700))),
            Text('${c.taken}/30 alındı', style: TextStyle(color: p.ink2, fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          _bar(c.progress),
          const SizedBox(height: 10),
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
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            key(Colors.transparent, 'Boş (Al)', b: p.gold),
            key(p.chip, 'Alındı'),
            key(p.gold.withValues(alpha: 0.28), 'Okundu'),
            key(null, 'Sizin', g: RC.bronze, b: RC.bronzeBorder),
          ]),
          const SizedBox(height: 4),
          Text('Boş cüze dokunarak alın; kendi cüzünüze dokunarak okuyun ya da işaretleyin.',
              style: TextStyle(color: p.ink2, fontSize: 11.5)),
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
    ];
  }

  void _read(BuildContext context, int part) {
    final (surah, ayah) = kCuzBaslangic[part - 1];
    _push(context, SurahReadScreen(surah: surah, startAyah: ayah));
  }

  Future<void> _tapPart(BuildContext context, GroupChain c, int n) async {
    final me = _sync.uid ?? '';
    final s = c.slots[n];
    if (s == null) {
      if (!c.active) return;
      if (!await _ensureName(context) || !context.mounted) return;
      if (await _confirm(context, '$n. cüz', '$n. cüzü okumak için alıyor musunuz?', ok: 'Al') && context.mounted) {
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

  /// Yâsin ve İhlâs zincirlerinde sûreyi açar.
  int? _surahOf(GroupChain c) => switch (c.type) { 'yasin' => 36, 'ihlas' => 112, _ => null };

  List<Widget> _count(BuildContext context, GroupChain c) {
    final p = _pal;
    final me = _sync.uid ?? '';
    final mine = c.claimOf(me);
    final surah = _surahOf(c);
    final others = c.claims.values.where((x) => x.uid != me).toList()..sort((a, b) => b.amount.compareTo(a.amount));
    return [
      PaperBox(
        pal: p,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text('${trNum(c.done)} / ${trNum(c.total)} ${c.unit} okundu',
                  style: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Text(c.full ? 'Doldu' : '${trNum(c.free)} boşta', style: TextStyle(color: p.ink2, fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          _bar(c.progress),
        ]),
      ),
      if (mine != null || (c.active && !c.full)) ...[
        const SizedBox(height: 10),
        PaperBox(
          pal: p,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: mine == null
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Payınızı alın', style: TextStyle(color: p.ink, fontSize: 15.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Okuyabileceğiniz kadarını alın. Boşta: ${trNum(c.free)} ${c.unit}',
                      style: TextStyle(color: p.ink2, fontSize: 12.5)),
                  const SizedBox(height: 10),
                  _goldButton('Pay al', () => _take(context, c), key: const Key('takeShare')),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Sizin payınız', style: TextStyle(color: p.ink2, fontSize: 12.5)),
                        Text('${trNum(mine.done)} / ${trNum(mine.amount)}',
                            style: TextStyle(color: p.ink, fontSize: 20, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    if (surah != null)
                      PillButton(
                        pal: p,
                        selected: false,
                        height: 36,
                        onTap: () => _push(context, SurahReadScreen(surah: surah)),
                        child: const Text('Oku'),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  _bar(mine.amount == 0 ? 0 : mine.done / mine.amount),
                  const SizedBox(height: 10),
                  if (mine.done < mine.amount)
                    Row(children: [
                      for (final add in [1, if (mine.amount >= 10) 10, if (mine.amount >= 100) 100]) ...[
                        Expanded(
                          child: _plainButton(
                              '+$add', () => _run(context, () => _sync.setDone(c, min(mine.amount, mine.done + add))),
                              h: 40),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        flex: 2,
                        child: _goldButton('Okudum', () => _writeDone(context, c, mine), h: 40, key: const Key('writeDone')),
                      ),
                    ])
                  else
                    Center(
                        child: Text('Payınızı tamamladınız · Allah kabul etsin',
                            style: TextStyle(color: p.gold, fontSize: 13.5))),
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
      if (others.isNotEmpty) ...[
        _label('Katılanlar'),
        PaperBox(
          pal: p,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < others.length; i++) ...[
              if (i > 0) DashedLine(color: p.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Icon(Icons.person, size: 18, color: p.gold),
                  const SizedBox(width: 8),
                  Expanded(child: Text(others[i].name, style: TextStyle(color: p.ink, fontSize: 14.5))),
                  Text('${trNum(others[i].done)} / ${trNum(others[i].amount)}',
                      style: TextStyle(color: p.ink2, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  if (others[i].done >= others[i].amount) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle, size: 16, color: p.gold),
                  ],
                ]),
              ),
            ],
          ]),
        ),
      ],
    ];
  }

  Future<void> _take(BuildContext context, GroupChain c) async {
    if (!await _ensureName(context) || !context.mounted) return;
    final free = c.free;
    final suggest = min(free, max(1, (c.total / 10).ceil()));
    final v = await _askText(context, 'Pay al',
        message: 'Kaç ${c.unit} okuyacaksınız? Boşta: ${trNum(free)}', initial: '$suggest', number: true, maxLength: 8, ok: 'Al');
    final n = int.tryParse(v ?? '');
    if (n == null || n <= 0 || !context.mounted) return;
    final now = _sync.chain(c.id) ?? c; // bu arada başkası almış olabilir
    if (n > now.free) {
      showNote(context, now.full ? 'Zincir doldu, bütün paylar alındı.' : 'En fazla ${trNum(now.free)} alabilirsiniz.');
      return;
    }
    final ok = await _run(context, () => _sync.takeAmount(now, n));
    if (!ok && context.mounted) {
      final after = _sync.chain(c.id);
      if (after != null && after.full) showNote(context, 'Zincir doldu, bütün paylar alındı.');
    }
  }

  Future<void> _writeDone(BuildContext context, GroupChain c, ChainClaim mine) async {
    final v = await _askText(context, 'Okudum',
        message: 'Şimdiye kadar toplam kaç ${c.unit} okudunuz?', initial: '${mine.amount}', number: true, maxLength: 8, ok: 'Kaydet');
    final n = int.tryParse(v ?? '');
    if (n == null || !context.mounted) return;
    await _run(context, () => _sync.setDone(c, min(n, mine.amount)), ok: n >= mine.amount ? 'Allah kabul etsin' : null);
  }
}
