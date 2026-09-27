import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/app_prefs.dart';
import 'services/location_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Kayıtlı şehir/konum varsa açılışta yükle.
  await LocationStore.instance.load();
  await AppPrefs.instance.load();

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
        fontFamily: 'serif',
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.green,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
