import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/dua_circle_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_prefs.dart';
import 'services/ezan_notifications.dart';
import 'services/invite_watch.dart';
import 'services/location_store.dart';
import 'services/prayer_groups.dart' show normalizeCode;
import 'theme.dart';
import 'widgets/page_shell.dart' show AppRoute, DesignScale, kAppPageTransitions;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Yazı tiplerinin (Amiri, Amiri Quran, Lora) lisansı
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Amiri', 'Amiri Quran'], ofl);
    yield LicenseEntryWithLineBreaks(['Lora'], await rootBundle.loadString('assets/fonts/Lora-OFL.txt'));
  });

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Kayıtlı şehir/konum varsa açılışta yükle.
  await LocationStore.instance.load();
  await AppPrefs.instance.load();

  // Ezan bildirimleri: her açılışta ve konum değişince önümüzdeki günler için yeniden kurulur.
  await EzanNotifications.instance.load();
  unawaited(EzanNotifications.instance.reschedule());
  LocationStore.instance.addListener(() => unawaited(EzanNotifications.instance.reschedule()));

  // Dua Zinciri: uygulama kapalıyken yaklaşık 30 dakikada bir gruplarda yeni zincir kontrolü.
  unawaited(InviteWatch.schedule());
  // Zincir bildirimine dokununca Dua Zinciri açılır (uygulama açıkken ya da bildirimden açılınca).
  EzanNotifications.onTap = _openFromNotification;

  runApp(const EzanSaatiApp());

  final launch = await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp ?? false) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotification(launch!.notificationResponse?.payload));
  }
  unawaited(_openInstallReferrer());
}

/// Uygulama grup bağlantısından Play Store'a gidilerek kurulduysa (referrer=grup=KOD), ilk açılışta
/// gruba katılma ekranı kendiliğinden açılır. Yalnız bir kez bakılır.
Future<void> _openInstallReferrer() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  const key = 'kurulum_kaynagi_bakildi';
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    final ref = (await PlayInstallReferrer.installReferrer).installReferrer ?? '';
    final code = normalizeCode(Uri.splitQueryString(Uri.decodeComponent(ref))['grup'] ?? '');
    if (code.length == 6) kNavigatorKey.currentState?.pushNamed('/grup?k=$code');
  } catch (_) {
    // Play Store dışından kurulduysa kaynak bilgisi yoktur.
  }
}

/// Uygulamanın gezgini (bildirimden sayfa açmak için).
final kNavigatorKey = GlobalKey<NavigatorState>();

void _openFromNotification(String? payload) {
  if (payload == InviteWatch.payload) kNavigatorKey.currentState?.pushNamed('/zincir');
}

class EzanSaatiApp extends StatelessWidget {
  const EzanSaatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: kNavigatorKey,
      title: 'Ezan Saati',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkGreen,
        primaryColor: AppColors.gold,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          secondary: AppColors.green,
          surface: AppColors.greenSurface,
        ),
        fontFamily: 'Lora',
        pageTransitionsTheme: kAppPageTransitions,
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.green,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      // Her ekran aynı tasarımı orantılı gösterir (bkz. DesignScale).
      builder: (context, child) => DesignScale(child: child!),
      home: const HomeScreen(),
      // Grup bağlantısı (ezansaati://app/grup?k=KOD) gruba katılma ekranını, zincir bildirimi (/zincir)
      // ve eski davet bağlantıları (/davet) Dua Zinciri'ni açar.
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri == null) return null;
        if (uri.path == '/grup') return AppRoute(builder: (_) => GroupJoinScreen(code: uri.queryParameters['k'] ?? ''));
        if (uri.path == '/zincir' || uri.path == '/davet') return AppRoute(builder: (_) => const DuaCircleScreen());
        return null;
      },
      onUnknownRoute: (_) => AppRoute(builder: (_) => const HomeScreen()),
    );
  }
}
