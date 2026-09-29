import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/app_prefs.dart';
import 'services/ezan_notifications.dart';
import 'services/location_store.dart';
import 'theme.dart';
import 'widgets/page_shell.dart' show DesignScale, kAppPageTransitions;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Arapça yazı tiplerinin (Amiri, Amiri Quran) lisansı
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Amiri', 'Amiri Quran'], ofl);
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

  runApp(const EzanSaatiApp());
}

class EzanSaatiApp extends StatelessWidget {
  const EzanSaatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        fontFamily: 'EBGaramond',
        pageTransitionsTheme: kAppPageTransitions,
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.green,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      // Her ekran aynı tasarımı orantılı gösterir (bkz. DesignScale).
      builder: (context, child) => DesignScale(child: child!),
      home: const HomeScreen(),
    );
  }
}
