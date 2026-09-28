import 'package:ezan_saati/screens/surah_read_screen.dart';
import 'package:ezan_saati/services/content_store.dart';
import 'package:ezan_saati/services/quran_audio.dart';
import 'package:ezan_saati/widgets/surah_audio_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Test ortamında ses motoru yok: oynatıcı kurulumu bağlantı hatası gibi başarısız olur.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.just_audio.methods'),
      (call) async {
        if (call.method == 'init') throw PlatformException(code: 'network', message: 'Bağlantı yok (test)');
        return <String, dynamic>{};
      },
    );
  });

  test('114 sûrenin tamamı için ses adresi üretilir (akış, uygulamaya gömülü değil)', () {
    expect(kQuranReciter.surahUrl(1).toString(), 'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/1.mp3');
    expect(
        kQuranReciter.surahUrl(114).toString(), 'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/114.mp3');
    final urls = {for (var i = 1; i <= 114; i++) kQuranReciter.surahUrl(i).toString()};
    expect(urls, hasLength(114));
    expect(kQuranAudioSource, contains('alquran.cloud'));
  });

  Future<void> open(WidgetTester t, {bool listen = false}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(() => Future.wait([QuranData.load(), ReadingPrefs.get()]));
    await t.pumpWidget(MaterialApp(home: SurahReadScreen(surah: 1, listen: listen)));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
  }

  testWidgets('Dinle düğmesi sesli okuma çubuğunu açar ve kapatır', (t) async {
    await open(t);
    expect(find.byType(SurahAudioBar), findsNothing);
    await t.tap(find.text('Dinle'));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    expect(find.byType(SurahAudioBar), findsOneWidget);
    expect(find.textContaining('Fâtiha Sûresi · Mişari'), findsOneWidget);
    // Bağlantı kurulamayınca anlaşılır hata ve "Tekrar dene" görünür
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.textContaining('İnternet bağlantınızı kontrol edip tekrar deneyin'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Sesli okumayı kapat').first);
    await t.pumpAndSettle();
    expect(find.byType(SurahAudioBar), findsNothing);
  });

  testWidgets('Günün ayetindeki Dinle ile açılınca çubuk hazır gelir; önceki/sonraki sûre düğmeleri var', (t) async {
    await open(t, listen: true);
    expect(find.byType(SurahAudioBar), findsOneWidget);
    expect(find.bySemanticsLabel('Önceki sûre'), findsOneWidget);
    expect(find.bySemanticsLabel('Sonraki sûre'), findsOneWidget);
  });
}
