import 'package:ezan_saati/widgets/page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Büyük ekranda konum tasarım biriminde ölçülür (sesli okumada kaydırma sapmasın)', (t) async {
    t.view.physicalSize = const Size(780, 1600); // tasarım genişliğinin 2 katı: her şey 2 kat büyük çizilir
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
      builder: (context, child) => DesignScale(child: child!),
      home: Scaffold(
        body: Column(children: [const SizedBox(height: 300), SizedBox(key: key, height: 10, width: 10)]),
      ),
    ));
    final box = key.currentContext!.findRenderObject() as RenderBox;
    expect(box.localToGlobal(Offset.zero).dy, 600); // telefon pikseli
    expect(designTopOf(box, key.currentContext!), 300); // kaydırmayla aynı birim
  });
}
