import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium abonelik durumu.
///
/// Google Play satın alması bağlanana kadar durum yalnız deneme anahtarıyla (Premium sayfasının altındaki
/// "Test" anahtarı) açılıp kapanır.
class Premium extends ChangeNotifier {
  Premium._();
  static final instance = Premium._();

  static const _kTest = 'premium_test';

  /// Deneme anahtarı yalnız geliştirme ve deneme (--dart-define=DENEME=true) sürümlerinde görünür.
  static const showTestSwitch = kDebugMode || bool.fromEnvironment('DENEME');

  static const monthlyPrice = '49,90 TL';
  static const yearlyPrice = '299,90 TL';
  static const yearlyPerMonth = '24,99 TL';
  static const trialDays = 7;

  SharedPreferences? _p;
  bool _active = false;
  bool get active => _active;

  Future<void> load() async {
    _p ??= await SharedPreferences.getInstance();
    _active = showTestSwitch && (_p!.getBool(_kTest) ?? false); // mağaza sürümünde deneme kaydı yok sayılır
    notifyListeners();
  }

  Future<void> setTest(bool on) async {
    _active = on;
    notifyListeners();
    _p ??= await SharedPreferences.getInstance();
    await _p!.setBool(_kTest, on);
  }

  @visibleForTesting
  void debugSet(bool on) {
    _active = on;
    notifyListeners();
  }
}
