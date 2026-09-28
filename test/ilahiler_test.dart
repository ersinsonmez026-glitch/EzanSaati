import 'package:ezan_saati/screens/ilahiler_screen.dart';
import 'package:ezan_saati/services/ilahi_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ornek = [
  Ilahi(
    id: 'a',
    title: 'Birinci ilahi',
    performer: 'Okuyan A',
    asset: 'assets/audio/ilahiler/a.m4a',
    seconds: 95,
    source: 'Freesound',
    page: 'https://freesound.org/s/1/',
    license: 'CC0 1.0',
  ),
  Ilahi(
    id: 'b',
    title: 'İkinci ilahi',
    performer: '',
    asset: 'assets/audio/ilahiler/b.m4a',
    seconds: 130,
    source: 'Wikimedia Commons',
    page: 'https://commons.wikimedia.org/wiki/File:B.ogg',
    license: 'CC BY-SA 4.0',
    note: 'İcracı hakları kaydedenin beyanına dayanır.',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Veri dosyası okunur; her kaydın kaynağı, sayfası ve lisansı var', () async {
    final list = await IlahiData.load();
    for (final i in list) {
      expect(i.source, isNotEmpty, reason: i.id);
      expect(i.page, startsWith('https://'), reason: i.id);
      expect(i.license, isNotEmpty, reason: i.id);
      expect(i.asset, startsWith('assets/audio/ilahiler/'), reason: i.id);
    }
  });

  test('Kaynak satırı okuyan, kaynak ve lisansı içerir', () {
    expect(_ornek[0].credit, 'Okuyan A — Freesound · CC0 1.0');
    expect(_ornek[1].credit, 'Wikimedia Commons · CC BY-SA 4.0');
  });

  Future<void> pump(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: w));
    await t.pumpAndSettle();
  }

  testWidgets('Kayıt yokken oynatıcı boş ve düğmeler kapalı', (t) async {
    await pump(t, const IlahilerScreen(tracks: []));
    expect(find.text('İlahiler'), findsOneWidget);
    expect(find.text('Henüz kayıt yok'), findsOneWidget);
    expect(find.textContaining('Kullanım izni belirtilmiş kayıtlar eklendikçe'), findsOneWidget);
    // Kontrol düğmeleri devre dışı (soluk) görünür
    final prev = find.ancestor(of: find.byIcon(Icons.skip_previous), matching: find.byType(Opacity));
    expect(t.widget<Opacity>(prev.first).opacity, 0.4);
  });

  testWidgets('Kayıtlar listelenir, seçili kaydın kaynağı ve lisansı gösterilir', (t) async {
    await pump(t, const IlahilerScreen(tracks: _ornek));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Birinci ilahi'), findsNWidgets(2)); // listede ve oynatıcıda
    expect(find.text('İkinci ilahi'), findsOneWidget);
    expect(find.text('Freesound'), findsOneWidget); // kapaktaki kaynak etiketi
    expect(find.textContaining('Kaynak: Okuyan A — Freesound · CC0 1.0'), findsOneWidget);
    expect(find.text('1:35'), findsOneWidget); // toplam süre
  });
}
