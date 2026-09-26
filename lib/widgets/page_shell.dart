import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../screens/city_picker_screen.dart';
import '../screens/settings_screen.dart';
import '../services/location_store.dart';
import '../theme.dart';

/// Ana ekran dışındaki bütün sayfaların ortak şablonu.
///
/// Üstte gece manzaralı başlık (levhalar, logo, konum, sayfa adı) vardır.
/// Sayfa aşağı kaydırıldıkça başlık YAVAŞÇA ince bir şeride dönüşür.
/// Hız: [collapseDistance] piksellik kaydırmada tamamen küçülür.
class PageShell extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsets padding;
  final bool showSettings;

  const PageShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(12, 14, 12, 32),
    this.showSettings = true,
  });

  /// Başlığın küçülmesi için gereken kaydırma mesafesi.
  /// Büyütürsen başlık daha yavaş küçülür.
  static const double collapseDistance = 320;

  static const double expandedHeight = 230;
  static const double collapsedHeight = 64;

  @override
  State<PageShell> createState() => _PageShellState();
}

class _PageShellState extends State<PageShell> {
  final ScrollController _controller = ScrollController();
  double _progress = 0; // 0 = tam büyük, 1 = tam küçük

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    LocationStore.instance.addListener(_onLocation);
  }

  void _onLocation() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    LocationStore.instance.removeListener(_onLocation);
    super.dispose();
  }

  void _onScroll() {
    final p = (_controller.offset / PageShell.collapseDistance).clamp(0.0, 1.0);
    if ((p - _progress).abs() > 0.001) setState(() => _progress = p);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    // Başı ve sonu yumuşak geçiş
    final t = Curves.easeInOut.transform(_progress);
    final height = lerpDouble(PageShell.expandedHeight, PageShell.collapsedHeight, t)! + top;

    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      body: Stack(
        children: [
          // İçerik başlığın altından kayar
          Positioned.fill(
            child: ListView(
              controller: _controller,
              padding: widget.padding.copyWith(
                top: widget.padding.top + PageShell.expandedHeight + top,
              ),
              children: widget.children,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: height,
            child: _Header(
              t: t,
              topInset: top,
              title: widget.title,
              subtitle: widget.subtitle,
              showSettings: widget.showSettings,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final double t;
  final double topInset;
  final String title;
  final String? subtitle;
  final bool showSettings;

  const _Header({
    required this.t,
    required this.topInset,
    required this.title,
    required this.subtitle,
    required this.showSettings,
  });

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2))];
    final fadeOut = (1 - t * 1.6).clamp(0.0, 1.0); // levhalar, konum
    final medSize = lerpDouble(66, 40, t)!;
    final canPop = Navigator.of(context).canPop();
    final locName = LocationStore.instance.current?.name ?? 'Konum Seç';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.darkGreen,
        border: Border(
          bottom: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.45 + 0.55 * t),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35 * t), blurRadius: 10),
        ],
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/header_night.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.1),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    AppColors.darkGreen.withValues(alpha: 0.75 + 0.2 * t),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),

            // Levhalar (küçülürken kaybolur)
            if (fadeOut > 0) ...[
              Positioned(
                top: topInset + 8,
                left: 10,
                child: Opacity(
                  opacity: fadeOut,
                  child: Image.asset('assets/images/levha_allah.png', width: medSize, height: medSize),
                ),
              ),
              Positioned(
                top: topInset + 8,
                right: 10,
                child: Opacity(
                  opacity: fadeOut,
                  child: Image.asset('assets/images/levha_muhammed.png', width: medSize, height: medSize),
                ),
              ),
              // Logo ve konum
              Positioned(
                top: topInset + 10,
                left: 90,
                right: 90,
                child: Opacity(
                  opacity: fadeOut,
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.nightlight_round, color: AppColors.goldLight, size: 18, shadows: shadow),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Ezan Saati',
                              maxLines: 1,
                              style: TextStyle(
                                color: AppColors.goldLight,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'serif',
                                shadows: shadow,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CityPickerScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.85)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, color: AppColors.gold, size: 15),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$locName  ›',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Alt satır: geri · sayfa adı · ayarlar
            Positioned(
              left: 0,
              right: 0,
              bottom: lerpDouble(10, 4, t)!,
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: canPop
                        ? IconButton(
                            tooltip: 'Geri',
                            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.goldLight, shadows: shadow),
                            onPressed: () => Navigator.of(context).maybePop(),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: lerpDouble(30, 21, t),
                            fontWeight: FontWeight.w700,
                            fontFamily: 'serif',
                            shadows: shadow,
                          ),
                        ),
                        if (subtitle != null && t < 0.5)
                          Opacity(
                            opacity: (1 - t * 2).clamp(0.0, 1.0),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.goldLight,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'serif',
                                  shadows: shadow,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: showSettings
                        ? IconButton(
                            tooltip: 'Ayarlar',
                            icon: const Icon(Icons.settings, color: AppColors.gold, shadows: shadow),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
