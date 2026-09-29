import 'package:firebase_core/firebase_core.dart';

/// Firebase ayarları (android/app/google-services.json ile aynı değerler).
/// Proje: ezansaati-premium-2026 — ücretsiz Spark planı.
/// Yalnızca Android uygulaması kayıtlı; diğer platformlarda Dua Zinciri
/// telefonda (sunucusuz) çalışmaya devam eder.
class DefaultFirebaseOptions {
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyCeqcX8e0lTqpkg6fFxXwk0682eYACAmEc',
    appId: '1:607513055482:android:a6eaf55029c990c5c0b943',
    messagingSenderId: '607513055482',
    projectId: 'ezansaati-premium-2026',
    storageBucket: 'ezansaati-premium-2026.firebasestorage.app',
  );
}
