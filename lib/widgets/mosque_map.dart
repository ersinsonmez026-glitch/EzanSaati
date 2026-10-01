import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Cami Bulucu haritası: Google Haritalar'ın gömülü görünümü, uygulamanın içinde (anahtar gerekmez).
/// Harita kaydırılıp yakınlaştırılabilir; hiçbir bağlantı uygulamanın dışına (tarayıcıya) çıkmaz.
class MosqueMap extends StatefulWidget {
  final Uri url;

  const MosqueMap({super.key, required this.url});

  /// Konumun çevresindeki camiler.
  static Uri search(double lat, double lng) =>
      Uri.parse('https://maps.google.com/maps?q=cami&ll=$lat,$lng&z=15&hl=tr&output=embed');

  /// Tek bir cami: haritada işaretli ve yakın planda (caminin adı haritada görünür).
  static Uri place(double lat, double lng) =>
      Uri.parse('https://maps.google.com/maps?q=$lat,$lng&z=17&hl=tr&output=embed');

  /// Bulunulan yerden camiye yürüyüş yolu.
  static Uri route(double fromLat, double fromLng, double lat, double lng) =>
      Uri.parse('https://maps.google.com/maps?saddr=$fromLat,$fromLng&daddr=$lat,$lng&dirflg=w&hl=tr&output=embed');

  @override
  State<MosqueMap> createState() => _MosqueMapState();
}

class _MosqueMapState extends State<MosqueMap> {
  // Birim testlerinde WebView yoktur; harita yerine düz zemin çizilir.
  static final _enabled = !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST');

  WebViewController? _c;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B2A1E))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => _set(loading: true, failed: false),
        onPageFinished: (_) => _set(loading: false),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? false) _set(loading: false, failed: true);
        },
        onNavigationRequest: (r) {
          // Harita her zaman uygulamanın içinde kalır. Google haritayı açarken kendi içinde başka adreslere
          // yönlendirir (ör. /maps/embed); bunlar da burada açılır, telefonun tarayıcısına hiç gidilmez.
          final scheme = Uri.tryParse(r.url)?.scheme ?? '';
          return const {'http', 'https', 'about', 'data', 'blob'}.contains(scheme)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ));
    _show(widget.url);
  }

  /// Google gömülü haritayı yalnız bir iframe içinde gösteriyor; harita, küçük bir sayfanın içindeki
  /// iframe'e yüklenir.
  void _show(Uri url) {
    final src = const HtmlEscape(HtmlEscapeMode.attribute).convert(url.toString());
    _c?.loadHtmlString(
      '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">'
      '<style>html,body{margin:0;height:100%;background:#0B2A1E}iframe{border:0;width:100%;height:100%;display:block}</style>'
      '</head><body><iframe src="$src" allowfullscreen referrerpolicy="no-referrer-when-downgrade"></iframe></body></html>',
      baseUrl: 'https://ezansaati-premium-2026.web.app/',
    );
  }

  void _set({bool? loading, bool? failed}) {
    if (!mounted) return;
    setState(() {
      _loading = loading ?? _loading;
      _failed = failed ?? _failed;
    });
  }

  @override
  void didUpdateWidget(MosqueMap old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _show(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Color(0xFF0B2A1E)),
      if (c != null)
        WebViewWidget(
          controller: c,
          // Harita sayfanın kaydırmasıyla çakışmasın: haritadaki parmak hareketleri haritaya gider.
          gestureRecognizers: const {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
        ),
      if (_failed)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('Harita yüklenemedi. İnternet bağlantınızı kontrol edin.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
          ),
        )
      else if (_loading && c != null)
        const Center(child: CircularProgressIndicator(color: Color(0xFFD8B45A))),
    ]);
  }
}
