import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/sayfa_basliklari.dart';
import '../services/app_prefs.dart';
import '../services/location_store.dart';
import '../services/prayer_calc.dart';
import '../theme.dart';
import 'gold_icon.dart';

/// Ana ekran dışındaki bütün sayfaların ortak şablonu.
///
/// Üstte gece/gündüz manzaralı başlık: solda konum, ortada Ezan Saati logosu; altında sayfa adı
/// ve alt yazısı, sağda sayfanın ayeti. Kaydırınca başlık kaydırmayla birlikte
/// kapanır; yalnızca geri · sayfa adı şeridi kalır.
class PageShell extends StatelessWidget {
  final String title;

  /// Alt yazı; verilmezse [heading] anahtarıyla [kSayfaBasliklari]'ndan alınır.
  final String? subtitle;

  /// Alt yazının alınacağı sayfa anahtarı (varsayılan: [title]).
  final String? heading;
  final List<Widget> children;
  final EdgeInsets padding;

  /// Sayfa zemini. Verilmezse koyu yeşil düz renk kullanılır.
  final Decoration? background;

  /// Sayfanın kaydırmasını dışarıdan izlemek/yönetmek için (ör. kaldığın ayete gitme).
  final ScrollController? controller;

  const PageShell({
    super.key,
    required this.title,
    this.subtitle,
    this.heading,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(10, 10, 10, 24),
    this.background,
    this.controller,
  });

  static const double fullHeight = 104; // açık başlık
  static const double barHeight = 44; // kapanınca kalan şerit

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final scroll = CustomScrollView(
      controller: controller,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _HeaderDelegate(
            title: title,
            subtitle: subtitle ?? kSayfaBasliklari[heading ?? title],
            topInset: top,
            day: isDaytime(),
          ),
        ),
        SliverPadding(
          padding: padding,
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
    final body = background == null ? scroll : DecoratedBox(decoration: background!, child: scroll);
    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      body: _SwipeBack(child: body),
    );
  }
}

/// Sayfa yana doğru kaydırılınca (sağdan sola ya da soldan sağa) bir önceki sayfaya döner.
/// Sayfanın içindeki yatay kaydırılan şeritler kendi hareketini önce alır.
class _SwipeBack extends StatefulWidget {
  final Widget child;

  const _SwipeBack({required this.child});

  @override
  State<_SwipeBack> createState() => _SwipeBackState();
}

class _SwipeBackState extends State<_SwipeBack> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if ((_dx.abs() > 80 || v.abs() > 600) && Navigator.of(context).canPop()) {
          Navigator.of(context).maybePop();
        }
      },
      child: widget.child,
    );
  }
}

/// Gündüz görünümü mü? Kullanıcı Gündüz/Gece seçtiyse o, yoksa vakte göre ([isDaytimeByClock]).
/// Başlık manzarası, ana görsel ve krem/yeşil sayfa görünümü buna göre seçilir.
bool isDaytime() => switch (AppPrefs.instance.dayMode) {
      DayMode.gunduz => true,
      DayMode.gece => false,
      DayMode.otomatik => isDaytimeByClock(),
    };

/// Gündüz/gece görünümünü değiştirir ve açık bütün sayfaları yeni renklerle yeniden çizer.
/// Seçilen görünüm vakte göre olanla aynıysa yeniden "Otomatik"e döner.
void toggleDayMode(BuildContext context) {
  final toDay = !isDaytime();
  final mode = toDay == isDaytimeByClock() ? DayMode.otomatik : (toDay ? DayMode.gunduz : DayMode.gece);
  AppPrefs.instance.setDayMode(mode);
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    duration: const Duration(seconds: 2),
    content: Text(mode == DayMode.otomatik
        ? 'Görünüm yine vakte göre değişecek'
        : "${toDay ? 'Gündüz' : 'Gece'} görünümü seçildi. Ayarlar'dan Otomatik'e alabilirsiniz."),
  ));
}

/// İki taraflı gündüz/gece düğmesi: solda güneş, sağda ay. Seçili taraf koyu zeminde parlak,
/// diğeri soluk; soluk tarafa dokununca görünüm değişir. Ana ekranda ve sayfa başlıklarında kullanılır.
class DayNightSwitch extends StatelessWidget {
  final double height;

  /// Simge yerine "Gündüz" / "Gece" yazısı (ana ekranda).
  final bool labels;

  const DayNightSwitch({super.key, required this.height, this.labels = false});

  @override
  Widget build(BuildContext context) {
    final day = isDaytime();
    Widget side(bool isDay) {
      final on = day == isDay;
      final d = height - 4;
      return Semantics(
        button: true,
        selected: on,
        label: isDay ? 'Gündüz görünümüne geç' : 'Gece görünümüne geç',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: on ? null : () => toggleDayMode(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: labels ? null : d,
            height: d,
            padding: labels ? EdgeInsets.symmetric(horizontal: d * 0.45) : EdgeInsets.all(d * 0.1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: labels ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: labels ? BorderRadius.circular(99) : null,
              color: on ? const Color(0xFF062A1C) : null,
              border: on ? Border.all(color: const Color(0xE6CFAE68)) : null,
            ),
            child: Opacity(
              opacity: on ? 1 : 0.6,
              child: labels
                  ? Text(isDay ? 'Gündüz' : 'Gece',
                      style: TextStyle(
                          color: on ? const Color(0xFFF2D58E) : Colors.white,
                          fontSize: d * 0.55,
                          fontWeight: FontWeight.w700,
                          height: 1))
                  : Image.asset(isDay ? 'assets/images/ikon/gunduz.webp' : 'assets/images/ikon/gece.webp'),
            ),
          ),
        ),
      );
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: const Color(0x8C000000),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xB3CFAE68)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [side(true), SizedBox(width: height * 0.08), side(false)]),
    );
  }
}

/// Gündüz (imsak ile akşam arası) mı? Seçili konum yoksa 06:00-19:00 kabul edilir.
bool isDaytimeByClock() {
  final now = DateTime.now();
  final loc = LocationStore.instance.current;
  if (loc == null) return now.hour >= 6 && now.hour < 19;
  final t = PrayerCalc.forDay(loc, now).slots;
  return now.isAfter(t[0].time) && now.isBefore(t[4].time);
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final String? subtitle;
  final double topInset;
  final bool day; // gündüz görünümü mü; değişince başlık yeniden çizilir

  _HeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.topInset,
    required this.day,
  });

  static const _shadow = [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1))];

  /// Yerleşimin dayandığı üst hiza: durum çubuğu (en az 24; logo bu çubuğun hizasından başlar).
  double get _base => math.max(topInset, 24);

  @override
  double get maxExtent => PageShell.fullHeight + _base;

  @override
  double get minExtent => PageShell.barHeight + topInset;

  @override
  bool shouldRebuild(covariant _HeaderDelegate old) =>
      old.title != title ||
      old.subtitle != subtitle ||
      old.topInset != topInset ||
      old.day != day;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final p = (shrinkOffset / range).clamp(0.0, 1.0); // 0 açık, 1 kapalı
    // Logo ve alt yazı ilk kaydırmada kaybolur.
    final fade = (1 - shrinkOffset / 40).clamp(0.0, 1.0);
    final canPop = Navigator.of(context).canPop();
    // Sayfa adı ortada; solda geri oku, sağda gündüz/gece düğmesi kadar boşluk.
    const side = 72.0;
    final base = _base;
    final titleTop = base + 38 - (base + 36 - topInset) * p;
    // Geri oku ve gündüz/gece düğmesi aynı hizada: açıkken alt yazı hizasında, kapanınca şeritte.
    final rowTop = titleTop + 2 + (base + 70 - titleTop - 2) * (1 - p);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.darkGreen,
        border: Border(bottom: BorderSide(color: Color(0x99CFAE68), width: 1.5)),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Manzara: görselin tamamı genişliğe sığar, üstten hizalanır; başlıkla birlikte kayar.
            Positioned(
              left: 0,
              right: 0,
              top: -shrinkOffset,
              child: Image.asset(
                isDaytime() ? 'assets/images/header_gunduz.jpg' : 'assets/images/header_gece.jpg',
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            ),
            // Gündüz göğü aydınlık: yazılar okunsun diye biraz daha koyulaştırılır.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDaytime()
                      ? const [Color(0x66000000), Color(0x26000000), Color(0x1A021C12), Color(0xB3021C12)]
                      : const [Color(0x40000000), Color(0x00000000), Color(0x00021C12), Color(0xB3021C12)],
                  stops: const [0, 0.25, 0.55, 1],
                ),
              ),
            ),
            // Logonun arkasında yumuşak gölge
            Positioned(
              top: base - 30 - shrinkOffset,
              left: 0,
              right: 0,
              height: 110,
              child: Opacity(
                opacity: fade,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.42,
                      colors: [Color(0x59000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),

            if (fade > 0) ...[
              // Logo: durum çubuğu hizasından başlar, ortada
              Positioned(
                top: base - 14 - shrinkOffset,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: fade,
                  child: Center(
                    child: Image.asset('assets/images/logo_ezan_saati.png', height: 53, fit: BoxFit.contain),
                  ),
                ),
              ),
              if (subtitle != null)
                Positioned(
                  top: base + 72 - shrinkOffset,
                  left: 76,
                  right: 76,
                  child: Opacity(
                    opacity: fade,
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            style: const TextStyle(color: Color(0xFFEBD3A0), fontSize: 11, shadows: _shadow),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const _Ornament(),
                      ],
                    ),
                  ),
                ),
            ],

            // Sayfa adı: açıkken logonun altında ortada, kapanınca şeritte kalır.
            Positioned(
              top: titleTop,
              left: side,
              right: side,
              height: 36,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: GoldText(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    tone: GoldTone.onPhoto,
                    style: TextStyle(fontSize: 26 - 6 * p, fontWeight: FontWeight.w600, fontFamily: 'Lora'),
                  ),
                ),
              ),
            ),

            // Solda geri oku, sağda gündüz/gece düğmesi; ikisi de hep görünür.
            if (canPop)
              Positioned(
                top: rowTop - 2,
                left: 4,
                width: 52,
                height: 36,
                child: Semantics(
                  button: true,
                  label: 'Geri',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Center(
                      child: Image(image: AssetImage('assets/images/ikon/geri.webp'), width: 34),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: rowTop,
              right: 8,
              height: 32,
              child: const DayNightSwitch(height: 32),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alt yazının altındaki ince altın süs: çizgi · baklava · çizgi.
class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    Widget line(bool left) => Container(
          width: 40,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  left ? const [Color(0x00CFAE68), Color(0xFFCFAE68)] : const [Color(0xFFCFAE68), Color(0x00CFAE68)],
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(true),
        const SizedBox(width: 4),
        Transform.rotate(
          angle: 0.785398,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2C584), width: 1.2)),
          ),
        ),
        const SizedBox(width: 4),
        line(false),
      ],
    );
  }
}

/// Uygulamadaki sayfa geçişi: yeni sayfa sağdan kayarak gelir, alttaki sayfa hafifçe sola çekilir
/// (saydamlık yok; eski telefonlarda da net görünür). Temada tüm sayfalara (ana ekran dahil) verilir.
class AppPageTransitions extends PageTransitionsBuilder {
  const AppPageTransitions();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final outCurve =
        CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-0.25, 0)).animate(outCurve),
      child: SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(inCurve),
        child: DecoratedBox(
          decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 16)]),
          child: child,
        ),
      ),
    );
  }
}

/// Tüm platformlarda aynı geçiş.
const kAppPageTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.android: AppPageTransitions(),
  TargetPlatform.iOS: AppPageTransitions(),
});

/// Sayfa açma: varsayılandan biraz yavaş (400 ms); geçişin şekli temadan (AppPageTransitions).
class AppRoute<T> extends MaterialPageRoute<T> {
  AppRoute({required super.builder});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 350);
}

/// Tüm uygulama tek bir tasarım genişliğinde (390) kurulur; her ekran bu tasarımı kendi genişliğine
/// orantılı büyütür ya da küçültür. Böylece yazı, tuş ve görsellerin oranı her telefonda aynı kalır.
class DesignScale extends StatelessWidget {
  static const designWidth = 390.0;
  final Widget child;

  const DesignScale({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= 0) return child;
    final s = mq.size.width / designWidth;
    final size = mq.size / s;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: MediaQuery(
          data: mq.copyWith(
            size: size,
            devicePixelRatio: mq.devicePixelRatio * s,
            padding: mq.padding / s,
            viewPadding: mq.viewPadding / s,
            viewInsets: mq.viewInsets / s,
            systemGestureInsets: mq.systemGestureInsets / s,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// [box]'ın ekrandaki üst kenarı, tasarım biriminde (kaydırma miktarı ve MediaQuery ile aynı birim).
/// `localToGlobal` telefonun gerçek piksellerini verir; [DesignScale] ekranı büyütüp küçülttüğü için
/// kaydırma hesabında o değer doğrudan kullanılamaz.
double designTopOf(RenderBox box, BuildContext context) {
  final root = Navigator.maybeOf(context, rootNavigator: true)?.context.findRenderObject();
  return box.localToGlobal(Offset.zero, ancestor: root).dy;
}
