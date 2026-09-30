import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'screens/dua_circle_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_prefs.dart';
import 'services/ezan_notifications.dart';
import 'services/invite_watch.dart';
import 'services/location_store.dart';
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

  // Dua Zinciri: uygulama kapalıyken yaklaşık 30 dakikada bir yeni davet kontrolü.
  unawaited(InviteWatch.schedule());
  // Davet bildirimine dokununca Davetler açılır (uygulama açıkken ya da bildirimden açılınca).
  EzanNotifications.onTap = _openFromNotification;

  runApp(const EzanSaatiApp());

  final launch = await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp ?? false) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotification(launch!.notificationResponse?.payload));
  }
}

/// Uygulamanın gezgini (bildirimden sayfa açmak için).
final kNavigatorKey = GlobalKey<NavigatorState>();

void _openFromNotification(String? payload) {
  if (payload == InviteWatch.payload) kNavigatorKey.currentState?.pushNamed('/davet');
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
      // Davet bağlantısı (ezansaati://app/davet?k=KOD) ya da davet bildirimi (/davet): Dua Zinciri Davetler'de açılır.
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri == null || uri.path != '/davet') return null;
        return AppRoute(builder: (_) => DuaCircleScreen(inviteCode: uri.queryParameters['k'] ?? ''));
      },
      onUnknownRoute: (_) => AppRoute(builder: (_) => const HomeScreen()),
    );
  }
}
