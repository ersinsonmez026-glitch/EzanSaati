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

  const cdn = 'https://cdn.islamic.network/quran/audio/128/ar.alafasy';

  test('114 sûrenin tamamı için ses adresi üretilir (akış, uygulamaya gömülü değil)', () {
    expect(kQuranReciter.surahUrl(1).toString(), 'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/1.mp3');
    expect(
        kQuranReciter.surahUrl(114).toString(), 'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/114.mp3');
    final urls = {for (var i = 1; i <= 114; i++) kQuranReciter.surahUrl(i).toString()};
    expect(urls, hasLength(114));
    expect(kQuranAudioSource, contains('alquran.cloud'));
  });

  test('global ayet numarası: 1:1 → 1, 2:255 → 262, 114:6 → 6236', () {
    expect(globalAyahNumber(1, 1), 1);
    expect(globalAyahNumber(2, 255), 262);
    expect(globalAyahNumber(114, 6), 6236);
    // Araştırmada API'den okunan diğer değerler
    expect(globalAyahNumber(2, 1), 8);
    expect(globalAyahNumber(9, 1), 1236);
    expect(globalAyahNumber(36, 1), 3706);
    expect(globalAyahNumber(67, 1), 5242);
    expect(globalAyahNumber(112, 1), 6222);
    expect(kSurahAyahCounts, hasLength(114));
    expect(kSurahAyahCounts.fold<int>(0, (a, b) => a + b), kTotalAyahs);
    expect(kQuranReciter.ayahUrl(262).toString(), '$cdn/262.mp3');
  });

  test('ayet sayıları uygulamanın Kur\'an verisiyle birebir aynı (ayet numaraları değişmez)', () async {
    final data = await QuranData.load();
    for (var s = 1; s <= 114; s++) {
      expect(data.verses[s - 1].length, kSurahAyahCounts[s - 1], reason: '$s. sûre');
      expect(data.surahs[s - 1].ayahCount, kSurahAyahCounts[s - 1], reason: '$s. sûre');
    }
  });

  test('çalma listesi: Fâtiha ve Tevbe besmelesiz, diğer sûrelerde başta besmele', () {
    const fatiha = SurahPlaylist(1);
    expect(fatiha.hasBasmala, isFalse);
    expect(fatiha.length, 7);
    expect(fatiha.urls.first.toString(), '$cdn/1.mp3'); // 1:1 besmeledir
    expect(fatiha.ayahAt(0), 1);
    expect(fatiha.indexOf(7), 6);

    const tevbe = SurahPlaylist(9);
    expect(tevbe.hasBasmala, isFalse);
    expect(tevbe.urls.first.toString(), '$cdn/1236.mp3');

    const bakara = SurahPlaylist(2);
    expect(bakara.length, 287);
    expect(bakara.urls[0].toString(), '$cdn/1.mp3'); // besmele
    expect(bakara.urls[1].toString(), '$cdn/8.mp3'); // 2:1
    expect(bakara.urls[255].toString(), '$cdn/262.mp3'); // 2:255
    expect(bakara.ayahAt(0), 0);
    expect(bakara.ayahAt(255), 255);
    expect(bakara.indexOf(1), 0); // 1. ayetten başlarken besmele de okunur
    expect(bakara.indexOf(255), 255);

    expect(const SurahPlaylist(114).urls.last.toString(), '$cdn/6236.mp3');
  });

  test('kısa sûreler (78–114): her ayet kendi dosyasıyla, sırayla ve eksiksiz eşleşir', () {
    var expected = globalAyahNumber(78, 1);
    for (var s = 78; s <= 114; s++) {
      final list = SurahPlaylist(s);
      final urls = list.urls;
      expect(urls, hasLength(list.ayahCount + 1), reason: '$s. sûre');
      expect(urls.first.toString(), '$cdn/1.mp3', reason: '$s. sûre besmele');
      for (var a = 1; a <= list.ayahCount; a++) {
        expect(list.ayahAt(a), a); // 0. sıra besmele
        expect(urls[a].toString(), '$cdn/$expected.mp3', reason: '$s:$a');
        expected++;
      }
    }
    expect(expected - 1, kTotalAyahs);
  });

  /// Gerçek zamanlı bekleme ile kare çizer: oynatıcının (sahte) bağlantı denemesi ve uzun
  /// sûrelerde hedef ayete kademeli yaklaşan kaydırma bu sırada tamamlanır.
  Future<void> settleAudio(WidgetTester t, {int rounds = 6}) async {
    for (var i = 0; i < rounds; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester t, {int surah = 1, int startAyah = 1, bool listen = false, bool settle = true}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(() => Future.wait([QuranData.load(), ReadingPrefs.get()]));
    await t.pumpWidget(MaterialApp(home: SurahReadScreen(surah: surah, startAyah: startAyah, listen: listen)));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    // Çubuk veri yüklendikten sonra kurulur; oynatıcının (sahte) bağlantı denemesi bitsin.
    if (listen && settle) await settleAudio(t);
  }

  // Okunan ayetin etiketi, kutunun içindeki diğer etiketlerle birleşebilir.
  Finder playing(int ayah) => find.bySemanticsLabel(RegExp('^$ayah\\. ayet okunuyor'));

  SurahAudioBar bar(WidgetTester t) => t.widget<SurahAudioBar>(find.byType(SurahAudioBar));

  testWidgets('Dinle düğmesi sesli okuma çubuğunu açar ve kapatır', (t) async {
    await open(t);
    expect(find.byType(SurahAudioBar), findsNothing);
    await t.tap(find.text('Dinle'));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    expect(find.byType(SurahAudioBar), findsOneWidget);
    expect(bar(t).startAyah, 1);
    expect(find.textContaining('Fâtiha Sûresi · Mişari'), findsOneWidget);
    // Bağlantı kurulamayınca anlaşılır hata ve "Tekrar dene" görünür
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.textContaining('İnternet bağlantınızı kontrol edip tekrar deneyin'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Sesli okumayı kapat').first);
    await t.pumpAndSettle();
    expect(find.byType(SurahAudioBar), findsNothing);
  });

  testWidgets('Günün ayetindeki Dinle o ayetten başlar; ayet ve sûre kontrolleri var, ±10 sn yok', (t) async {
    await open(t, surah: 2, startAyah: 255, listen: true, settle: false);
    expect(find.byType(SurahAudioBar), findsOneWidget);
    expect(bar(t).startAyah, 255);
    for (final label in ['Önceki sûre', 'Önceki ayet', 'Sonraki ayet', 'Sonraki sûre']) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    expect(find.bySemanticsLabel('10 saniye geri'), findsNothing);
    expect(find.bySemanticsLabel('10 saniye ileri'), findsNothing);
    expect(find.text('Ayet 255/286'), findsOneWidget);
    // Bağlantı kurulamazsa "Tekrar dene" kalınan ayetten sürer
    await settleAudio(t);
    expect(find.text('Tekrar dene'), findsOneWidget);
    await t.tap(find.text('Tekrar dene'));
    await t.pump();
    await settleAudio(t);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(bar(t).startAyah, 255);
  });

  testWidgets('okunan ayet altın çerçeveyle vurgulanır ve ekranda tutulur; ilerleme "Ayet n/m"', (t) async {
    await open(t, surah: 36, listen: true);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    // Hata durumunda çubuk ilerleme yerine uyarı gösterir; çağrıları sayfa açısından sınarız.
    bar(t).onAyahChanged!(3);
    await t.pumpAndSettle();
    expect(playing(3), findsOneWidget);
    bar(t).onAyahChanged!(4);
    await t.pumpAndSettle();
    expect(playing(3), findsNothing);
    expect(playing(4), findsOneWidget);

    // Uzaktaki ayete geçilince sayfa kendiliğinden oraya kayar
    bar(t).onAyahChanged!(60);
    await settleAudio(t, rounds: 10);
    await t.pumpAndSettle();
    final r = t.getRect(playing(60));
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.top, lessThan(844 - SurahAudioBar.height));
  });

  testWidgets('elle kaydırınca otomatik takip birkaç saniye durur', (t) async {
    await open(t, surah: 36, listen: true);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await t.pumpAndSettle();
    final scroll = t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    bar(t).onAyahChanged!(70);
    await t.pumpAndSettle();
    // Sayfa, kullanıcının bıraktığı yerde kalır
    expect(t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels, scroll);
  });

  testWidgets('son ayetten sonra sonraki sûreye geçer, 1. ayetten sürer; Nâs\'ta durur', (t) async {
    await open(t, surah: 113, listen: true);
    expect(bar(t).surah, 113);
    expect(bar(t).onSurahFinished, isNotNull);
    bar(t).onSurahFinished!();
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    expect(bar(t).surah, 114);
    expect(bar(t).startAyah, 1);
    expect(find.textContaining('Nâs Sûresi · Mişari'), findsOneWidget);
    // Son sûre: sonraki sûreye geçiş yok, çalma durur
    expect(bar(t).onSurahFinished, isNull);
    expect(bar(t).onNextSurah, isNull);
  });

  testWidgets('ayetin yanındaki dinle simgesi o ayetten başlatır', (t) async {
    await open(t, surah: 112);
    expect(find.byType(SurahAudioBar), findsNothing);
    await t.tap(find.bySemanticsLabel('3. ayetten dinle'));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    expect(bar(t).startAyah, 3);
    final token = bar(t).startToken;
    await t.tap(find.bySemanticsLabel('2. ayetten dinle'));
    await t.pump();
    expect(bar(t).startAyah, 2);
    expect(bar(t).startToken, greaterThan(token));
  });
}
