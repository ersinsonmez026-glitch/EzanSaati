import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/circle_sync.dart';
import '../services/dua_circle_store.dart';
import '../widgets/page_shell.dart';
import '../widgets/reading_ui.dart';

/// Davetleri WhatsApp ile gönderme. Mesaj hazır gelir; gönder tuşuna kişi kendisi basar.
class DuaCircleInviteScreen extends StatefulWidget {
  final DuaCircle circle;

  const DuaCircleInviteScreen({super.key, required this.circle});

  @override
  State<DuaCircleInviteScreen> createState() => _DuaCircleInviteScreenState();
}

class _DuaCircleInviteScreenState extends State<DuaCircleInviteScreen> {
  final _pal = PagePalette.current();
  final _sent = <CircleMember>{};

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
          'WhatsApp mesajı hazır açılır; göndermek için WhatsApp\'ta gönder tuşuna basın. '
          '${widget.circle.remote ? 'Uygulamayı kullanan ve numarasını kaydetmiş kişiler daveti uygulamada da görür; diğerleri mesajdaki kodla katılır. ' : ''}'
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
                  color: sent ? _pal.chip : const Color(0xFF1FAA55),
                  borderRadius: BorderRadius.circular(10),
                  border: sent ? Border.all(color: _pal.line) : null,
                ),
                child: Text(sent ? 'Açıldı' : 'WhatsApp',
                    style:
                        TextStyle(color: sent ? _pal.ink2 : Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
