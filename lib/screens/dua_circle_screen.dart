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

/// Dua Zinciri: uygulama içinde dua grupları ve gruplarda birlikte okunan zincirler.
/// WhatsApp yalnız grup bağlantısını bir kez paylaşmak ve uygulamayı önermek için kullanılır.
class DuaCircleScreen extends StatefulWidget {
  /// 0: Zincirlerim · 1: Gruplarım
  final int tab;

  const DuaCircleScreen({super.key, this.tab = 0});

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
  return showDialog<String>(
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
  ).whenComplete(c.dispose);
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
      message: 'Gruplarda bu adla görüneceksiniz. Sonradan değiştirebilirsiniz.', hint: 'Örn. Ayşe Demir', ok: 'Kaydet');
  if (n == null || n.isEmpty) return false;
  await _sync.saveName(n);
  await InviteWatch.requestPermission(); // yeni zincir bildirimleri gelebilsin
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

/// Gruplar için internet durumu.
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
          child: Text(connecting ? 'Bağlanıyor…' : 'Gruplar için internet bağlantısı gerekli.',
              style: TextStyle(color: _pal.ink2, fontSize: 12.5)),
        ),
        if (!connecting) TextButton(onPressed: () => _sync.start(), child: const Text('Tekrar dene')),
      ]),
    ),
  );
}

/// Zincir kartı (listelerde).
class _ChainCard extends StatelessWidget {
  final GroupChain c;

  const _ChainCard(this.c);

  @override
  Widget build(BuildContext context) {
    final p = _pal;
    final me = _sync.meIn(c);
    final String mine;
    if (c.complete) {
      mine = 'Tamamlandı';
    } else if (c.expired) {
      mine = 'Süresi doldu';
    } else if (c.isHatim) {
      final parts = c.partsOf(me);
      mine = c.solo
          ? '${c.done}/30 cüz okundu'
          : parts.isEmpty
              ? '${30 - c.taken} cüz boşta'
              : 'Sizin: ${_partsText(parts)} cüz';
    } else {
      final cl = c.claimOf(me);
      mine = cl == null ? '${trNum(c.free)} ${c.unit} boşta' : 'Sizin: ${trNum(cl.done)} / ${trNum(cl.amount)} okundu';
    }
    final left = c.complete || c.expired ? '' : (c.daysLeft == 0 ? 'Bugün bitiyor' : '${c.daysLeft} gün kaldı');
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _push(context, ChainScreen(groupId: c.groupId, chainId: c.id)),
        child: PaperBox(
          pal: p,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(c.solo ? Icons.person : Icons.groups, size: 16, color: p.gold),
              const SizedBox(width: 5),
              Expanded(
                child: Text(c.solo ? 'Yalnız ben' : c.groupName,
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
              else if (!c.expired)
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
  late int _tab = widget.tab;

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
    return PageShell(
      title: 'Dua Zinciri',
      background: p.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Row(children: [
          for (final (i, t) in [(0, 'Zincirlerim'), (1, 'Gruplarım')]) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: PillButton(
                pal: p,
                selected: _tab == i,
                height: 38,
                onTap: () => setState(() => _tab = i),
                child: Text(t, style: const TextStyle(fontSize: 14.5)),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 4),
        if (_tab == 0) ..._chainsTab(context) else ..._groupsTab(context),
      ],
    );
  }

  List<Widget> _chainsTab(BuildContext context) {
    final all = _sync.chains;
    final active = all.where((c) => c.active).toList();
    final ended = all.where((c) => !c.active).take(5).toList();
    return [
      if (active.isEmpty && ended.isEmpty) ...[
        const SizedBox(height: 12),
        PaperBox(
          pal: _pal,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Text(
            'Henüz zinciriniz yok.\nBir grup kurup sevdiklerinizle birlikte hatim, Yâsin ya da salavat okuyabilir; '
            'dilerseniz yalnız kendiniz için de zincir başlatabilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _pal.ink2, fontSize: 13.5, height: 1.45),
          ),
        ),
      ],
      if (active.isNotEmpty) _label('Devam edenler'),
      for (final c in active) ...[_ChainCard(c), const SizedBox(height: 8)],
      if (ended.isNotEmpty) _label('Bitenler'),
      for (final c in ended) ...[_ChainCard(c), const SizedBox(height: 8)],
      const SizedBox(height: 10),
      _goldButton('Zincir başlat', () => _push(context, const ChainStartScreen()),
          icon: Icons.add, key: const Key('startChain')),
      const SizedBox(height: 8),
      _plainButton('Uygulamayı tavsiye et', () => _openWhatsApp(context, appSuggestMessage()), icon: Icons.share),
    ];
  }

  List<Widget> _groupsTab(BuildContext context) {
    final groups = _sync.groups;
    return [
      const SizedBox(height: 8),
      _syncNote(context),
      if (groups.isNotEmpty) _label('Gruplarım'),
      for (final g in groups) ...[_groupCard(context, g), const SizedBox(height: 8)],
      if (groups.isEmpty && _sync.ready)
        PaperBox(
          pal: _pal,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Text(
            'Henüz bir grubunuz yok. "Aile", "Cami cemaati" gibi bir grup kurun ve bağlantısını '
            'WhatsApp\'tan bir kez paylaşın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _pal.ink2, fontSize: 13.5, height: 1.45),
          ),
        ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _goldButton('Grup kur', () => _createGroup(context), icon: Icons.group_add, key: const Key('createGroup'))),
        const SizedBox(width: 8),
        Expanded(child: _plainButton('Kodla katıl', () => _joinByCode(context), icon: Icons.login, h: 44)),
      ]),
      const SizedBox(height: 10),
      SourceNote(
        pal: _pal,
        text: 'Bir gruba katılan kişi, o grupta başlatılan bütün zincirleri uygulamada görür. '
            'Her zincir için ayrıca davet göndermek gerekmez.',
      ),
      if (_sync.myName.isNotEmpty) ...[
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: () async {
              final n = await _askText(context, 'Gruplarda görünen adınız', initial: _sync.myName, ok: 'Kaydet');
              if (n != null && n.isNotEmpty && context.mounted) await _run(context, () => _sync.saveName(n), ok: 'Kaydedildi');
            },
            icon: Icon(Icons.edit, size: 16, color: _pal.gold),
            label: Text('Adım: ${_sync.myName}', style: TextStyle(color: _pal.ink2, fontSize: 13)),
          ),
        ),
      ],
    ];
  }

  Widget _groupCard(BuildContext context, PrayerGroup g) {
    final p = _pal;
    final n = _sync.chainsOf(g.id).where((c) => c.active).length;
    final owner = g.ownerUid == _sync.uid ? 'siz' : g.ownerName;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _push(context, GroupScreen(groupId: g.id)),
      child: PaperBox(
        pal: p,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RC.bronze, border: Border.all(color: RC.bronzeBorder)),
            child: const Icon(Icons.groups, color: RC.bronzeText, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.name, style: TextStyle(color: p.ink, fontSize: 17, fontWeight: FontWeight.w700)),
              Text('${g.memberUids.length} kişi · kurucu: $owner', style: TextStyle(color: p.ink2, fontSize: 12.5)),
              Text(n == 0 ? 'Devam eden zincir yok' : '$n zincir devam ediyor',
                  style: TextStyle(color: p.gold, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
          Icon(Icons.chevron_right, color: p.ink2),
        ]),
      ),
    );
  }

  Future<void> _createGroup(BuildContext context) async {
    if (!await _ensureName(context) || !context.mounted) return;
    final name = await _askText(context, 'Grup kur',
        message: 'Grubun adını yazın. Sonra bağlantısını WhatsApp\'tan paylaşarak kişileri çağırabilirsiniz.',
        hint: 'Örn. Aile, Cami cemaati',
        ok: 'Kur');
    if (name == null || name.isEmpty || !context.mounted) return;
    PrayerGroup? g;
    final ok = await _run(context, () async => g = await _sync.createGroup(name));
    if (ok && g != null && context.mounted) _push(context, GroupScreen(groupId: g!.id));
  }

  Future<void> _joinByCode(BuildContext context) async {
    final code = await _askText(context, 'Kodla katıl',
        message: 'Size iletilen 6 karakterlik grup kodunu yazın.', hint: 'Örn. AB4 K7P', maxLength: 9, ok: 'Devam');
    if (code == null || normalizeCode(code).length != 6 || !context.mounted) {
      if (code != null && context.mounted) showNote(context, 'Grup kodu 6 karakterdir.');
      return;
    }
    _push(context, GroupJoinScreen(code: normalizeCode(code)));
  }
}

// ============================================================ grup sayfası

class GroupScreen extends StatefulWidget {
  final String groupId;

  const GroupScreen({super.key, required this.groupId});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  @override
  void initState() {
    super.initState();
    _sync.addListener(_changed);
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
    final g = _sync.group(widget.groupId);
    if (g == null) {
      return PageShell(title: 'Grup', background: p.background, children: [
        const SizedBox(height: 20),
        Text('Bu gruba artık ulaşılamıyor.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2)),
      ]);
    }
    final owner = g.ownerUid == _sync.uid;
    final chains = _sync.chainsOf(g.id);
    final active = chains.where((c) => c.active).toList();
    final uids = [...g.memberUids]..sort((a, b) => a == g.ownerUid ? -1 : (b == g.ownerUid ? 1 : g.nameOf(a).compareTo(g.nameOf(b))));
    return PageShell(
      title: g.name,
      subtitle: 'Dua grubu · ${g.memberUids.length} kişi',
      background: p.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        PaperBox(
          pal: p,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Gruba kişi çağır', style: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Bağlantıyı bir kez paylaşmanız yeterli: WhatsApp grubunuza ya da kişilere.',
                style: TextStyle(color: p.ink2, fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => copyToClipboard(context, groupLink(g.code)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: p.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.line)),
                child: Row(children: [
                  Text('Grup kodu  ', style: TextStyle(color: p.ink2, fontSize: 13)),
                  Text(formatCode(g.code),
                      style: TextStyle(color: p.gold, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  const Spacer(),
                  Icon(Icons.copy, size: 18, color: p.gold),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: () => _openWhatsApp(context, groupInviteMessage(g)),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _wa, borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('WhatsApp\'ta paylaş', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        if (active.isNotEmpty) _label(active.length == 1 ? 'Devam eden zincir' : 'Devam eden zincirler'),
        for (final c in active) ...[_ChainCard(c), const SizedBox(height: 8)],
        const SizedBox(height: 8),
        _goldButton('Bu grupta zincir başlat', () => _push(context, ChainStartScreen(groupId: g.id)), icon: Icons.add),
        _label('Üyeler'),
        PaperBox(
          pal: p,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < uids.length; i++) ...[
              if (i > 0) DashedLine(color: p.line),
              InkWell(
                onTap: owner && uids[i] != _sync.uid ? () => _removeMember(context, g, uids[i]) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Icon(Icons.person, size: 18, color: p.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${uids[i] == _sync.uid ? 'Siz' : g.nameOf(uids[i])}${uids[i] == g.ownerUid ? ' (kurucu)' : ''}',
                        style: TextStyle(color: p.ink, fontSize: 14.5),
                      ),
                    ),
                    if (owner && uids[i] != _sync.uid) Icon(Icons.more_horiz, size: 18, color: p.ink2),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () => _leave(context, g, owner),
            child: Text(owner ? 'Grubu sil' : 'Gruptan ayrıl', style: TextStyle(color: p.ink2, fontSize: 13.5)),
          ),
        ),
      ],
    );
  }

  Future<void> _removeMember(BuildContext context, PrayerGroup g, String uid) async {
    if (!await _confirm(context, 'Gruptan çıkar', '${g.nameOf(uid)} gruptan çıkarılsın mı?', ok: 'Çıkar')) return;
    if (context.mounted) await _run(context, () => _sync.removeMember(g, uid));
  }

  Future<void> _leave(BuildContext context, PrayerGroup g, bool owner) async {
    final ok = await _confirm(
      context,
      owner ? 'Grubu sil' : 'Gruptan ayrıl',
      owner
          ? '"${g.name}" grubu ve zincirleri herkes için silinecek. Emin misiniz?'
          : '"${g.name}" grubundan ayrılırsınız; bu grubun zincirlerini artık görmezsiniz.',
      ok: owner ? 'Sil' : 'Ayrıl',
    );
    if (!ok || !context.mounted) return;
    if (await _run(context, () => _sync.leaveGroup(g)) && context.mounted) Navigator.of(context).pop();
  }
}

// ============================================================ gruba katılma

/// Grup bağlantısından (ezansaati://app/grup?k=KOD) ya da kodla açılan katılma ekranı.
class GroupJoinScreen extends StatefulWidget {
  final String code;

  const GroupJoinScreen({super.key, required this.code});

  @override
  State<GroupJoinScreen> createState() => _GroupJoinScreenState();
}

class _GroupJoinScreenState extends State<GroupJoinScreen> {
  (String, String, String)? _info; // gid, ad, kuran
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sync.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    _sync.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _sync.start();
      final code = normalizeCode(widget.code);
      if (code.length != 6) throw StateError('Bağlantıdaki grup kodu eksik görünüyor.');
      final info = await _sync.lookupCode(code);
      if (info == null) throw StateError('Bu kodla bir grup bulunamadı. Grup silinmiş olabilir.');
      _info = info;
    } catch (e) {
      _error = e is StateError ? e.message : 'Gruba ulaşılamadı. İnternet bağlantınızı kontrol edin.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _join() async {
    final info = _info;
    if (info == null) return;
    if (!await _ensureName(context) || !mounted) return;
    setState(() => _busy = true);
    final ok = await _run(context, () => _sync.joinGroup(info.$1));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      showNote(context, '"${info.$2}" grubuna katıldınız');
      Navigator.of(context).pushReplacement(AppRoute(builder: (_) => GroupScreen(groupId: info.$1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pal;
    final info = _info;
    final member = info != null && _sync.isMember(info.$1);
    return PageShell(
      title: 'Dua Zinciri',
      background: p.background,
      padding: const EdgeInsets.fromLTRB(12, 26, 12, 24),
      children: [
        PaperBox(
          pal: p,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: _loading
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: p.gold)),
                )
              : info == null
                  ? Column(children: [
                      Icon(Icons.group_off, color: p.gold, size: 40),
                      const SizedBox(height: 10),
                      Text(_error ?? '', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 14, height: 1.45)),
                      const SizedBox(height: 12),
                      _plainButton('Tekrar dene', _load, h: 42),
                    ])
                  : Column(children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, gradient: RC.bronze, border: Border.all(color: RC.bronzeBorder, width: 1.5)),
                        child: const Icon(Icons.groups, color: RC.bronzeText, size: 34),
                      ),
                      const SizedBox(height: 10),
                      Text(member ? 'Bu gruptasınız' : 'Gruba çağrıldınız', style: TextStyle(color: p.ink2, fontSize: 14)),
                      Text(info.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.ink, fontSize: 28, fontWeight: FontWeight.w700)),
                      if (info.$3.isNotEmpty)
                        Text('Kuran: ${info.$3}', style: TextStyle(color: p.gold, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text(
                        'Katılınca bu grupta başlatılan dua zincirleri size uygulamada görünür; '
                        'yeni zincir başlayınca bildirim alırsınız.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.ink2, fontSize: 13, height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      if (member)
                        _goldButton('Gruba git', () {
                          Navigator.of(context).pushReplacement(AppRoute(builder: (_) => GroupScreen(groupId: info.$1)));
                        })
                      else
                        Row(children: [
                          Expanded(child: _plainButton('Vazgeç', () => Navigator.of(context).pop(), h: 44)),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _goldButton(_busy ? 'Katılınıyor…' : 'Gruba katıl', _busy ? null : _join,
                                key: const Key('joinGroup')),
                          ),
                        ]),
                    ]),
        ),
      ],
    );
  }
}

// ============================================================ zincir başlatma

class ChainStartScreen extends StatefulWidget {
  final String? groupId;

  const ChainStartScreen({super.key, this.groupId});

  @override
  State<ChainStartScreen> createState() => _ChainStartScreenState();
}

class _ChainStartScreenState extends State<ChainStartScreen> {
  static const _solo = '';
  late String _group = widget.groupId ?? (_sync.groups.isEmpty ? _solo : _sync.groups.first.id);
  String _type = 'hatim';
  String _mode = 'pick';
  int _days = 7;
  bool _busy = false;
  final _total = TextEditingController(text: '30');
  final _name = TextEditingController();
  final _intent = TextEditingController();

  @override
  void dispose() {
    _total.dispose();
    _name.dispose();
    _intent.dispose();
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
      showNote(context, 'Hedef adedi yazın.');
      return;
    }
    final custom = _type == 'ozel';
    if (custom && _name.text.trim().isEmpty) {
      showNote(context, 'Ne okunacağını yazın (örn. Kelime-i Tevhid).');
      return;
    }
    final gid = _group == _solo ? null : _group;
    if (gid != null && (!await _ensureName(context) || !mounted)) return;
    final name = custom ? '${trNum(total)} ${_name.text.trim()}' : (_type == 'hatim' ? 'Hatim' : '${trNum(total)} ${t.title}');
    setState(() => _busy = true);
    GroupChain? c;
    final ok = await _run(
      context,
      () async => c = await _sync.startChain(
        groupId: gid,
        type: _type,
        name: name,
        unit: custom ? 'adet' : t.unit,
        total: total,
        mode: _mode,
        days: _days,
        intent: _intent.text,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && c != null) {
      Navigator.of(context).pushReplacement(AppRoute(builder: (_) => ChainScreen(groupId: c!.groupId, chainId: c!.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pal;
    final groups = _sync.groups;
    final solo = _group == _solo;
    final gName = solo ? '' : (_sync.group(_group)?.name ?? '');
    return PageShell(
      title: 'Zincir Başlat',
      subtitle: 'Birlikte okuyalım',
      background: p.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        PaperBox(
          pal: p,
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Hangi grupta?'),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final g in groups) _chip(g.name, _group == g.id, () => setState(() => _group = g.id)),
              _chip('Yalnız ben', solo, () => setState(() => _group = _solo)),
            ]),
            _label('Ne okunacak?'),
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
            if (_type != 'hatim') ...[
              _label('Hedef'),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _total,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 8,
                  style: TextStyle(color: p.ink, fontSize: 15, fontWeight: FontWeight.w700),
                  decoration: _deco(hint: 'Adet'),
                ),
              ),
            ],
            if (!solo) ...[
              _label('Paylar nasıl olsun?'),
              Wrap(spacing: 7, runSpacing: 7, children: [
                _chip('Herkes kendi seçsin', _mode == 'pick', () => setState(() => _mode = 'pick')),
                _chip('Eşit böl', _mode == 'equal', () => setState(() => _mode = 'equal')),
              ]),
              const SizedBox(height: 5),
              Text(
                _mode == 'pick'
                    ? (_type == 'hatim'
                        ? '30 cüz listelenir, herkes okuyacağı cüzü kendisi alır.'
                        : 'Herkes okuyabileceği kadarını kendisi alır.')
                    : 'Şu an gruptaki kişilere eşit bölünür; sonradan katılanlar boşta kalandan alır.',
                style: TextStyle(color: p.ink2, fontSize: 12.5),
              ),
            ],
            _label('Son gün'),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final (d, t) in [(3, '3 gün'), (7, '1 hafta'), (15, '15 gün'), (kChainMaxDays, '1 ay')])
                _chip(t, _days == d, () => setState(() => _days = d)),
            ]),
            _label('Niyet (isteğe bağlı)'),
            TextField(
              controller: _intent,
              maxLength: 100,
              style: TextStyle(color: p.ink, fontSize: 14.5),
              decoration: _deco(hint: 'Kısa bir not yazabilirsiniz'),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _goldButton(
          _busy ? 'Başlatılıyor…' : (solo ? 'Başlat' : 'Başlat · $gName grubuna bildir'),
          _busy ? null : _start,
          key: const Key('doStart'),
        ),
      ],
    );
  }
}

// ============================================================ zincir sayfası

class ChainScreen extends StatefulWidget {
  final String? groupId;
  final String chainId;

  const ChainScreen({super.key, required this.groupId, required this.chainId});

  @override
  State<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends State<ChainScreen> {
  @override
  void initState() {
    super.initState();
    _sync.addListener(_changed);
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
    final c = _sync.chain(widget.groupId, widget.chainId);
    if (c == null) {
      return PageShell(title: 'Dua Zinciri', background: p.background, children: [
        const SizedBox(height: 20),
        Text('Bu zincir silinmiş.', textAlign: TextAlign.center, style: TextStyle(color: p.ink2)),
      ]);
    }
    final sub = [
      c.solo ? 'Yalnız ben' : c.groupName,
      if (c.complete) 'Tamamlandı' else if (c.expired) 'Süresi doldu' else if (c.daysLeft == 0) 'Bugün bitiyor' else '${c.daysLeft} gün kaldı',
    ].join(' · ');
    return PageShell(
      title: c.isHatim ? 'Hatim' : c.name,
      subtitle: sub,
      background: p.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (c.isHatim) ..._hatim(context, c) else ..._count(context, c),
        if (c.intent.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Niyet: ${c.intent}', textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 13, height: 1.4)),
        ],
        if (!c.solo) ...[
          const SizedBox(height: 4),
          Text('Başlatan: ${c.creatorUid == _sync.uid ? 'siz' : c.creatorName}',
              textAlign: TextAlign.center, style: TextStyle(color: p.ink2, fontSize: 12)),
        ],
        if (_sync.canDelete(c)) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () async {
                final ok = await _confirm(context, 'Zinciri sil',
                    c.solo ? 'Bu zincir silinsin mi?' : 'Bu zincir gruptaki herkes için silinecek. Emin misiniz?',
                    ok: 'Sil');
                if (!ok || !context.mounted) return;
                if (await _run(context, () => _sync.deleteChain(c)) && context.mounted) Navigator.of(context).pop();
              },
              child: Text('Zinciri sil', style: TextStyle(color: p.ink2, fontSize: 13.5)),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------- hatim

  List<Widget> _hatim(BuildContext context, GroupChain c) {
    final p = _pal;
    final me = _sync.meIn(c);
    final mine = c.partsOf(me);
    final open = c.active;
    Widget cell(int n) {
      final s = c.slots[n];
      final own = s != null && s.uid == me && !c.solo;
      final done = s?.done ?? false;
      final label = s == null ? (open ? 'Al' : '') : (c.solo ? (done ? 'Okundu' : '') : (own ? 'Siz' : s.name.split(' ').first));
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
            if (!c.solo) Text('${c.taken}/30 alındı', style: TextStyle(color: p.ink2, fontSize: 13)),
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
            if (!c.solo) key(Colors.transparent, 'Boş (Al)', b: p.gold),
            if (!c.solo) key(p.chip, 'Alındı'),
            key(p.gold.withValues(alpha: 0.28), 'Okundu'),
            if (!c.solo) key(null, 'Sizin', g: RC.bronze, b: RC.bronzeBorder),
          ]),
          const SizedBox(height: 4),
          Text(
            c.solo ? 'Okuduğunuz cüze dokunarak işaretleyin.' : 'Boş cüze dokunarak alın; kendi cüzünüze dokunarak okuyun ya da işaretleyin.',
            style: TextStyle(color: p.ink2, fontSize: 11.5),
          ),
        ]),
      ),
      if (!c.solo && mine.isNotEmpty) ...[
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
    final me = _sync.meIn(c);
    final s = c.slots[n];
    if (c.solo) {
      await _partSheet(context, c, n, s?.done ?? false, canRelease: false);
      return;
    }
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
    final me = _sync.meIn(c);
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
              child: Text('${trNum(c.done)} / ${trNum(c.total)} ${c.unit}',
                  style: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (!c.solo) Text('${trNum(c.free)} boşta', style: TextStyle(color: p.ink2, fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          _bar(c.progress),
        ]),
      ),
      const SizedBox(height: 10),
      PaperBox(
        pal: p,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: mine == null
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Henüz pay almadınız', style: TextStyle(color: p.ink, fontSize: 15.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Okuyabileceğiniz kadarını alın.', style: TextStyle(color: p.ink2, fontSize: 12.5)),
                const SizedBox(height: 10),
                _goldButton('Pay al', c.active ? () => _take(context, c) : null, key: const Key('takeShare')),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.solo ? 'Okunan' : 'Sizin payınız', style: TextStyle(color: p.ink2, fontSize: 12.5)),
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
                        child: _plainButton('+$add', () => _run(context, () => _sync.setDone(c, min(mine.amount, mine.done + add))),
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
                  Center(child: Text('Payınızı tamamladınız · Allah kabul etsin', style: TextStyle(color: p.gold, fontSize: 13.5))),
                if (!c.solo && c.active)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _take(context, c, current: mine),
                      child: Text('Payı değiştir', style: TextStyle(color: p.ink2, fontSize: 12.5)),
                    ),
                  ),
              ]),
      ),
      if (others.isNotEmpty) ...[
        _label('Diğerleri'),
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

  Future<void> _take(BuildContext context, GroupChain c, {ChainClaim? current}) async {
    if (!await _ensureName(context) || !context.mounted) return;
    final members = max(1, _sync.group(c.groupId ?? '')?.memberUids.length ?? 1);
    final free = c.free + (current?.amount ?? 0);
    final suggest = current?.amount ?? min(free, max(1, (c.total / members).ceil()));
    final v = await _askText(context, current == null ? 'Pay al' : 'Payı değiştir',
        message: 'Kaç ${c.unit} okuyacaksınız? Boşta: ${trNum(free)}', initial: '$suggest', number: true, maxLength: 8, ok: 'Kaydet');
    final n = int.tryParse(v ?? '');
    if (n == null || !context.mounted) return;
    if (n > free) {
      showNote(context, 'En fazla ${trNum(free)} alabilirsiniz.');
      return;
    }
    await _run(context, () => _sync.setAmount(c, n));
  }

  Future<void> _writeDone(BuildContext context, GroupChain c, ChainClaim mine) async {
    final v = await _askText(context, 'Okudum',
        message: 'Şimdiye kadar toplam kaç ${c.unit} okudunuz?', initial: '${mine.amount}', number: true, maxLength: 8, ok: 'Kaydet');
    final n = int.tryParse(v ?? '');
    if (n == null || !context.mounted) return;
    await _run(context, () => _sync.setDone(c, min(n, mine.amount)), ok: n >= mine.amount ? 'Allah kabul etsin' : null);
  }
}
