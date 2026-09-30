import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/circle_people.dart';
import '../services/circle_sync.dart';
import '../services/dua_circle_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Davet gönderme. Uygulamayı kullanan kişilere davet uygulamadan gider (WhatsApp açılmaz);
/// diğerleri için WhatsApp sırayla, mesaj hazır açılır; gönder tuşuna kişi kendisi basar.
class DuaCircleInviteScreen extends StatefulWidget {
  final DuaCircle circle;

  /// true: WhatsApp gerekenler için sırayla kendiliğinden açılır (zincir yeni kurulunca).
  final bool autoSend;

  const DuaCircleInviteScreen({super.key, required this.circle, this.autoSend = false});

  @override
  State<DuaCircleInviteScreen> createState() => _DuaCircleInviteScreenState();
}

class _DuaCircleInviteScreenState extends State<DuaCircleInviteScreen> with WidgetsBindingObserver {
  PagePalette get _pal => PagePalette.current(); // Gündüz/Gece değişince hemen yenilensin
  final _sent = <CircleMember>{};

  /// Sırayla WhatsApp'ı açılacak kişiler (uygulamada olmayanlar).
  final _queue = <CircleMember>[];
  bool _auto = false;

  /// Uygulamayı kullanan kişi: ortak zincirde davet ona uygulamadan gider.
  bool _inApp(CircleMember m) => widget.circle.remote && CirclePeople.instance.isInApp(m.phone);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CirclePeople.instance.load().then((_) {
      if (!mounted || !widget.autoSend) return;
      _queue.addAll(widget.circle.members.where((m) => !m.isMe && m.isPending && !_inApp(m)));
      if (_queue.isNotEmpty) {
        setState(() => _auto = true);
        _next();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // WhatsApp'tan dönünce sıradaki kişinin sohbeti açılır.
    if (state == AppLifecycleState.resumed && _auto) {
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted && _auto) _next();
      });
    }
  }

  void _next() {
    if (_queue.isEmpty) {
      setState(() => _auto = false);
      return;
    }
    _send(_queue.removeAt(0));
  }

  Future<void> _send(CircleMember m) async {
    final number = waNumber(m.phone);
    final text = inviteMessage(widget.circle, m);
    final uri = Uri.parse(number.isEmpty
        ? 'https://wa.me/?text=${Uri.encodeComponent(text)}'
        : 'https://wa.me/$number?text=${Uri.encodeComponent(text)}');
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!mounted) return;
    if (ok) {
      setState(() => _sent.add(m));
    } else {
      setState(() => _auto = false);
      showNote(context, 'WhatsApp açılamadı. Mesajı kopyalayıp gönderebilirsiniz.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.circle;
    final others = c.members.where((m) => !m.isMe).toList();
    final pending = others.where((m) => m.isPending).toList();
    final list = pending.isNotEmpty ? pending : others;
    return PageShell(
      title: 'Davet Gönder',
      background: _pal.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        PaperBox(
          pal: _pal,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Davetleri gönder',
                        style: TextStyle(color: _pal.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Text('WhatsApp ile', style: TextStyle(color: _pal.ink2, fontSize: 12)),
                ],
              ),
              if (_auto) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text('WhatsApp sırayla açılıyor · ${_queue.length} kişi kaldı',
                          style: TextStyle(color: _pal.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(onPressed: () => setState(() => _auto = false), child: const Text('Durdur')),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) DashedLine(color: _pal.line),
                _row(list[i]),
              ],
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Davet edilecek kişi yok.', style: TextStyle(color: _pal.ink2, fontSize: 13)),
                ),
              if (list.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: _pal.chip,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _pal.line),
                  ),
                  child: Text('Örnek mesaj:\n${inviteMessage(c, list.first)}',
                      style: TextStyle(color: _pal.ink2, fontSize: 12.5, height: 1.5)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'WhatsApp mesajı hazır açılır; göndermek için WhatsApp\'ta gönder tuşuna basın, sonra uygulamaya dönün. '
          '${widget.circle.remote ? '"Uygulamada" yazan kişilere davet uygulamadan gider, WhatsApp gerekmez. ' : ''}'
          'Davet $kInviteHours saat geçerlidir; yanıt gelmezse pay size döner.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _pal.ink2, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 12),
        DarkButton(label: 'Zincire git', onTap: () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _row(CircleMember m) {
    final sent = _sent.contains(m);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: TextStyle(color: _pal.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
                Text('Görevi: ${trNum(m.share)} ${widget.circle.unit}',
                    style: TextStyle(color: _pal.ink2, fontSize: 12)),
                if (_inApp(m))
                  Text('Uygulamada · davet uygulamasına gitti',
                      style: TextStyle(color: _pal.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                if (widget.circle.remote && m.key.isNotEmpty)
                  Text('Davet kodu: ${formatCode(m.key)}',
                      style: TextStyle(color: _pal.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: '${m.name} kişisine WhatsApp daveti gönder',
            child: GestureDetector(
              onTap: () => _send(m),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sent || _inApp(m) ? _pal.chip : const Color(0xFF1FAA55),
                  borderRadius: BorderRadius.circular(10),
                  border: sent || _inApp(m) ? Border.all(color: _pal.line) : null,
                ),
                child: Text(sent ? 'Açıldı' : (_inApp(m) ? 'Hatırlat' : 'WhatsApp'),
                    style:
                        TextStyle(color: sent || _inApp(m) ? _pal.ink2 : Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
