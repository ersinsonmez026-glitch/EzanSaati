import 'package:ezan_saati/screens/dua_circle_screen.dart';
import 'package:ezan_saati/services/dua_circle_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DuaCircle _circle({
  required String id,
  required DateTime created,
  required DateTime end,
  int total = 100,
  List<CircleMember>? members,
}) =>
    DuaCircle(
      id: id,
      type: 'salavat',
      name: 'Zincir $id',
      total: total,
      created: created,
      end: end,
      members: members ??
          [
            CircleMember(name: 'Ben', share: 50, status: MemberStatus.me, invitedAt: created),
            CircleMember(name: 'Ali', phone: '0532 111 22 33', share: 50, invitedAt: created),
          ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Dua Zinciri kuralları', () {
    test('Eşit bölme: artan adet baştakilere verilir, toplam korunur', () {
      expect(splitEvenly(110, 3), [37, 37, 36]);
      expect(splitEvenly(41, 5).reduce((a, b) => a + b), 41);
      expect(splitEvenly(10, 0), isEmpty);
    });

    test('WhatsApp numarası ülke koduyla yazılır', () {
      expect(waNumber('0532 111 22 33'), '905321112233');
      expect(waNumber('+90 (532) 111-22-33'), '905321112233');
      expect(waNumber('5321112233'), '905321112233');
      expect(waNumber('0049 151 2345678'), '491512345678');
      expect(waNumber('123'), '');
    });

    test('24 saatte yanıt vermeyenin payı kurucuya döner', () {
      final t0 = DateTime(2026, 10, 1, 9);
      final c = _circle(id: 'a', created: t0, end: DateTime(2026, 10, 20));
      final s = DuaCircleStore.instance..replaceAll([c]);
      expect(s.cleanup(t0.add(const Duration(hours: 23))), isFalse);
      expect(c.members.length, 2);
      expect(s.cleanup(t0.add(const Duration(hours: 24))), isTrue);
      expect(c.members.length, 1);
      expect(c.me.share, 100);
      expect(c.notice, contains('Ali'));
    });

    test('Kabul eden kişi 24 saatten sonra da zincirde kalır', () {
      final t0 = DateTime(2026, 10, 1, 9);
      final c = _circle(id: 'b', created: t0, end: DateTime(2026, 10, 20));
      c.members[1].status = MemberStatus.accepted;
      DuaCircleStore.instance
        ..replaceAll([c])
        ..cleanup(t0.add(const Duration(days: 2)));
      expect(c.members.length, 2);
    });

    test('Son günü geçen tamamlanmamış zincir silinir, tamamlanan saklanır', () {
      final t0 = DateTime(2026, 10, 1, 9);
      final open = _circle(id: 'open', created: t0, end: DateTime(2026, 10, 5));
      final done = _circle(id: 'done', created: t0, end: DateTime(2026, 10, 5), members: [
        CircleMember(name: 'Ben', share: 100, done: 100, status: MemberStatus.me, invitedAt: t0),
      ]);
      final s = DuaCircleStore.instance..replaceAll([open, done]);
      s.cleanup(DateTime(2026, 10, 5, 23, 59));
      expect(s.circles.length, 2, reason: 'son gün bitmeden silinmez');
      s.cleanup(DateTime(2026, 10, 6, 0, 1));
      expect(s.circles.map((c) => c.id), ['done']);
      expect(s.takeCleanupNote(), contains('Zincir open'));
    });

    test('Okumaya başlamamış kişi çıkarılınca payı kurucuya döner', () {
      final t0 = DateTime(2026, 10, 1, 9);
      final c = _circle(id: 'c', created: t0, end: DateTime(2026, 10, 20));
      final s = DuaCircleStore.instance..replaceAll([c]);
      s.removeMember(c, c.members[1]);
      expect(c.members.length, 1);
      expect(c.me.share, 100);
    });

    test('Davet mesajı pay ve son günü içerir; bağlantı yokken link eklenmez', () {
      final t0 = DateTime(2026, 10, 1, 9);
      final c = _circle(id: 'd', created: t0, end: DateTime(2026, 10, 20))..intent = 'Şifa için';
      final msg = inviteMessage(c, c.members[1]);
      expect(msg, contains('Selamün aleyküm Ali'));
      expect(msg, contains('Sana düşen: 50 salavat'));
      expect(msg, contains('Niyet: Şifa için'));
      expect(msg, contains('Son gün: 20 Ekim'));
      expect(msg, contains('24 saat'));
      expect(msg, isNot(contains('http')));
      expect(trNum(70000), '70.000');
    });
  });

  testWidgets('Dua Zinciri: oluştur, toplam uyarısı, davet ve okuma ekleme', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    DuaCircleStore.instance.replaceAll([]);

    await t.pumpWidget(const MaterialApp(home: DuaCircleScreen()));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    expect(find.textContaining('Henüz zinciriniz yok'), findsOneWidget);

    await t.tap(find.text('Yeni Zincir').first);
    await t.pumpAndSettle();
    // Sayfa içeriği tembel kurulur; öğe görünene kadar kaydırılır.
    Future<void> show(Finder f) async {
      // Açık klavye odağı, imleci göstermek için sayfayı geri kaydırmasın.
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(f);
      await t.pumpAndSettle();
    }

    // Tek kişiyle kaydedilemez
    await show(find.text('Zinciri oluştur ve davet gönder'));
    await t.tap(find.text('Zinciri oluştur ve davet gönder'));
    await t.pump();
    expect(find.text('Rehberden en az bir kişi ekleyin'), findsOneWidget);
    t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars(); // uyarı kapansın
    await t.pumpAndSettle();

    // Kişi yalnız rehberden eklenir (numarayla ekleme yok)
    expect(find.text('Numarayla ekle'), findsNothing);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('ezan_saati/contacts'),
      (call) async => {'name': 'Ali Yılmaz', 'phone': '0532 111 22 33'},
    );
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('ezan_saati/contacts'), null));
    await show(find.text('Rehberden seç'));
    await t.tap(find.text('Rehberden seç'));
    await t.pumpAndSettle();
    expect(find.text('Ali Yılmaz'), findsOneWidget);
    expect(find.text('110 / 110'), findsOneWidget);

    // Payı elle değiştir: toplam tutmazsa uyarı
    final myShare = find.byKey(const ValueKey('share:me'));
    await t.enterText(myShare, '50');
    await t.pumpAndSettle();
    expect(find.text('105 / 110'), findsOneWidget);
    expect(find.text('Toplam tutmuyor: 5 salavat dağıtılmadı.'), findsOneWidget);
    await show(find.text('Zinciri oluştur ve davet gönder'));
    await t.tap(find.text('Zinciri oluştur ve davet gönder'));
    await t.pump();
    expect(find.textContaining('hedefle (110) aynı olmalı'), findsOneWidget);
    t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars(); // uyarı kapansın
    await t.pumpAndSettle();

    // Eşit olmak zorunda değil: 60 / 50
    await t.enterText(myShare, '60');
    await t.enterText(find.byKey(const ValueKey('share:Ali Yılmaz')), '50');
    await t.pumpAndSettle();
    expect(find.text('110 / 110'), findsOneWidget);
    await show(find.text('Zinciri oluştur ve davet gönder'));
    await t.tap(find.text('Zinciri oluştur ve davet gönder'));
    await t.pumpAndSettle();

    // Davet ekranı
    expect(find.text('Davet Gönder'), findsOneWidget);
    expect(find.text('Görevi: 50 salavat'), findsOneWidget);
    expect(find.textContaining('Sana düşen: 50 salavat'), findsOneWidget);
    await show(find.text('Zincire git'));
    await t.tap(find.text('Zincire git'));
    await t.pumpAndSettle();

    // Zincir kartı
    expect(find.text('110 Salavat'), findsWidgets);
    expect(find.text('0 / 60'), findsOneWidget);
    expect(find.textContaining('1 kişi henüz kabul etmedi'), findsOneWidget);
    await t.tap(find.text('+10'));
    await t.pumpAndSettle();
    expect(find.text('10 / 60'), findsOneWidget);
    expect(DuaCircleStore.instance.circles.single.me.done, 10);
  });
}
