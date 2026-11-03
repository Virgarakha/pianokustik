import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synthesia_piano/main.dart';

void main() {
  testWidgets('PianoKustik app smoke test on desktop window', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const PianoKustikApp());
    expect(find.text('PianoKustik'), findsOneWidget);
    expect(find.text('Pilih Lagu'), findsNothing); // Song should be loaded
    expect(find.text('Mode Latihan: Wait for Notes'), findsNothing); // Initially in Listen mode
  });
}
