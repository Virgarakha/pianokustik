import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synthesia_piano/controllers/practice_controller.dart';
import 'package:synthesia_piano/models/chord_detector.dart';
import 'package:synthesia_piano/widgets/piano_geometry.dart';
import 'package:synthesia_piano/widgets/top_bar_controls.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
  });
  group('ChordDetector & Not Angka Tests', () {
    test('Not Angka mapping converts MIDI pitches accurately', () {
      // Indonesian Not Angka: C=1, D=2, E=3, F=4, G=5, A=6, B=7
      expect(ChordDetector.getNotAngka(60), '1');   // C4
      expect(ChordDetector.getNotAngka(61), '1#');  // C#4
      expect(ChordDetector.getNotAngka(62), '2');   // D4
      expect(ChordDetector.getNotAngka(63), '2#');  // D#4
      expect(ChordDetector.getNotAngka(64), '3');   // E4
      expect(ChordDetector.getNotAngka(65), '4');   // F4
      expect(ChordDetector.getNotAngka(66), '4#');  // F#4
      expect(ChordDetector.getNotAngka(67), '5');   // G4
      expect(ChordDetector.getNotAngka(68), '5#');  // G#4
      expect(ChordDetector.getNotAngka(69), '6');   // A4
      expect(ChordDetector.getNotAngka(70), '6#');  // A#4
      expect(ChordDetector.getNotAngka(71), '7');   // B4
    });

    test('Note letter mapping works for white and black keys', () {
      expect(ChordDetector.getNoteLetter(60), 'C');
      expect(ChordDetector.getNoteLetter(61), 'C#');
      expect(ChordDetector.getNoteLetter(62), 'D');
      expect(ChordDetector.getNoteLetter(69), 'A');
      expect(ChordDetector.getNoteLetter(71), 'B');
    });

    test('Detects major triads with Not Angka', () {
      // C Major: C (60), E (64), G (67) -> 1 • 3 • 5
      final chord = ChordDetector.detectChord({60, 64, 67});
      expect(chord, isNotNull);
      expect(chord, contains('C Major'));
      expect(chord, contains('1 • 3 • 5'));
    });

    test('Detects minor triads with Not Angka', () {
      // A Minor: A (57), C (60), E (64)
      final chord = ChordDetector.detectChord({57, 60, 64});
      expect(chord, isNotNull);
      expect(chord, contains('A Minor'));
      expect(chord, contains('6 • b3 • 5'));
    });

    test('Detects dominant 7th chords', () {
      // G7: G (55), B (59), D (62), F (65)
      final chord = ChordDetector.detectChord({55, 59, 62, 65});
      expect(chord, isNotNull);
      expect(chord, contains('G 7'));
    });

    test('Detects simple chord names matching reference UI (e.g. A major, C major, D minor)', () {
      // A major: A (57), C# (61), E (64) -> exact match to reference screenshot
      final aMajor = ChordDetector.detectSimpleChord({57, 61, 64});
      expect(aMajor, 'A major');

      // C major: C (60), E (64), G (67)
      final cMajor = ChordDetector.detectSimpleChord({60, 64, 67});
      expect(cMajor, 'C major');

      // D minor: D (62), F (65), A (69)
      final dMinor = ChordDetector.detectSimpleChord({62, 65, 69});
      expect(dMinor, 'D minor');

      // G 7: G (55), B (59), D (62), F (65)
      final g7 = ChordDetector.detectSimpleChord({55, 59, 62, 65});
      expect(g7, 'G 7');
    });

    test('Returns null when less than 2 distinct pitch classes are active', () {
      expect(ChordDetector.detectChord({60}), isNull);
      expect(ChordDetector.detectChord({60, 72}), isNull); // octave duplicates
    });
  });

  group('PianoGeometry text painters', () {
    test('All pre-cached text painters are loaded for all 88 keys', () {
      expect(PianoGeometry.notAngkaTextPainters.length, 88);
      expect(PianoGeometry.noteNameTextPainters.length, 88);
      expect(PianoGeometry.flyingStickLabelPainters.length, 88);
      expect(PianoGeometry.flyingStickNoteNamePainters.length, 88);
    });
  });

  group('PracticeController settings & themes', () {
    late PracticeController controller;

    setUp(() {
      controller = PracticeController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Defaults are correctly initialized', () {
      expect(controller.noteColorTheme, NoteColorTheme.gold);
      expect(controller.keyLabelMode, KeyLabelMode.none);
      expect(controller.showFlyingStickLabels, isFalse);
      expect(controller.showLiveChord, isTrue);
    });

    test('Theme changes update property and notify ticker', () {
      final initialTick = controller.visualizerTicker.value;
      controller.setNoteColorTheme(NoteColorTheme.cyan);

      expect(controller.noteColorTheme, NoteColorTheme.cyan);
      expect(controller.visualizerTicker.value, greaterThan(initialTick));
    });

    test('Key label mode changes update property', () {
      controller.setKeyLabelMode(KeyLabelMode.noteName);
      expect(controller.keyLabelMode, KeyLabelMode.noteName);

      controller.setKeyLabelMode(KeyLabelMode.none);
      expect(controller.keyLabelMode, KeyLabelMode.none);
    });

    test('Flying stick labels toggle updates property', () {
      controller.setShowFlyingStickLabels(true);
      expect(controller.showFlyingStickLabels, isTrue);

      controller.setShowFlyingStickLabels(false);
      expect(controller.showFlyingStickLabels, isFalse);
    });

    test('Live chord detection detects held chords in Free Play', () {
      controller.setMode(PlayMode.freePlay);
      expect(controller.currentDetectedChord, isNull);

      // Press C Major chord
      controller.setVirtualKeyPressed(60, true);
      controller.setVirtualKeyPressed(64, true);
      controller.setVirtualKeyPressed(67, true);

      expect(controller.currentDetectedChord, isNotNull);
      expect(controller.currentDetectedChord, contains('C Major'));

      // Release notes
      controller.setVirtualKeyPressed(60, false);
      controller.setVirtualKeyPressed(64, false);
      controller.setVirtualKeyPressed(67, false);

      expect(controller.currentDetectedChord, isNull);
    });
  });

  group('TopBarControls Settings Modal Widget Test', () {
    testWidgets('Settings button opens modal with themes and label controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = PracticeController();
      controller.setMode(PlayMode.freePlay);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopBarControls(controller: controller),
          ),
        ),
      );
      await tester.pump();

      // Tap the settings icon button
      final settingsButton = find.byIcon(Icons.settings);
      expect(settingsButton, findsOneWidget);
      await tester.tap(settingsButton);
      await tester.pump(const Duration(milliseconds: 300));

      // Verify modal is displayed with title
      expect(find.text('Pengaturan & Kustomisasi'), findsOneWidget);

      // Verify Free Play Appearance tab is active
      expect(find.text('Tampilan & Free Play'), findsOneWidget);
      expect(find.text('Warna Tema Stick & Rel Piano'), findsOneWidget);

      // Verify color theme swatches
      expect(find.text('Champagne Gold'), findsOneWidget);
      expect(find.text('Electric Cyan'), findsOneWidget);
      expect(find.text('Neon Violet'), findsOneWidget);
      expect(find.text('Sunset Amber'), findsOneWidget);

      // Tap on Electric Cyan theme
      await tester.tap(find.text('Electric Cyan'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.noteColorTheme, NoteColorTheme.cyan);

      // Verify label modes
      expect(find.text('Not Angka (1 2 3 4 5 6 7)'), findsOneWidget);
      expect(find.text('Nama Nada (C D E F G A B)'), findsOneWidget);

      // Tap Nama Nada mode
      await tester.tap(find.text('Nama Nada (C D E F G A B)'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.keyLabelMode, KeyLabelMode.noteName);

      controller.dispose();
    });
  });
}
