import 'package:flutter_test/flutter_test.dart';
import 'package:synthesia_piano/controllers/practice_controller.dart';
import 'package:synthesia_piano/models/midi_note.dart';
import 'package:synthesia_piano/services/midi_parser.dart';
import 'package:synthesia_piano/widgets/piano_geometry.dart';

void main() {
  group('MidiNote tests', () {
    test('pitchToNoteName maps correctly across piano range', () {
      expect(MidiNote.pitchToNoteName(21), 'A0');
      expect(MidiNote.pitchToNoteName(60), 'C4'); // Middle C
      expect(MidiNote.pitchToNoteName(69), 'A4'); // Concert pitch 440 Hz
      expect(MidiNote.pitchToNoteName(108), 'C8'); // Highest note on 88-key piano
    });

    test('isPitchBlackKey accurately identifies accidentals', () {
      expect(MidiNote.isPitchBlackKey(60), isFalse); // C
      expect(MidiNote.isPitchBlackKey(61), isTrue);  // C#
      expect(MidiNote.isPitchBlackKey(62), isFalse); // D
      expect(MidiNote.isPitchBlackKey(63), isTrue);  // D#
      expect(MidiNote.isPitchBlackKey(64), isFalse); // E
      expect(MidiNote.isPitchBlackKey(65), isFalse); // F
      expect(MidiNote.isPitchBlackKey(66), isTrue);  // F#
    });

    test('pitchToFrequency calculates correct standard frequencies', () {
      expect(MidiNote.pitchToFrequency(69), closeTo(440.0, 0.01)); // A4 = 440 Hz
      expect(MidiNote.pitchToFrequency(57), closeTo(220.0, 0.01)); // A3 = 220 Hz
      expect(MidiNote.pitchToFrequency(81), closeTo(880.0, 0.01)); // A5 = 880 Hz
    });
  });

  group('PianoGeometry tests', () {
    test('standard 88-key layout composition', () {
      expect(PianoGeometry.allKeys.length, 88);
      expect(PianoGeometry.totalWhiteKeys, 52);

      final whiteKeys = PianoGeometry.allKeys.where((k) => !k.isBlack).toList();
      final blackKeys = PianoGeometry.allKeys.where((k) => k.isBlack).toList();

      expect(whiteKeys.length, 52);
      expect(blackKeys.length, 36);

      // First key is A0 (21), last key is C8 (108)
      expect(PianoGeometry.allKeys.first.pitch, 21);
      expect(PianoGeometry.allKeys.first.noteName, 'A0');
      expect(PianoGeometry.allKeys.last.pitch, 108);
      expect(PianoGeometry.allKeys.last.noteName, 'C8');
    });

    test('horizontal bounds stay strictly within total width', () {
      const width = 1040.0; // 52 * 20
      for (final key in PianoGeometry.allKeys) {
        final (left, right) = PianoGeometry.getHorizontalBounds(key.pitch, width);
        expect(left, greaterThanOrEqualTo(0.0));
        expect(right, lessThanOrEqualTo(width));
        expect(right, greaterThan(left));
      }
    });
  });

  group('MidiParser demo songs tests', () {
    test('demo songs load with valid notes and timings', () {
      final songs = MidiParser.getDemoSongs();
      expect(songs.length, 4);

      for (final song in songs) {
        expect(song.notes, isNotEmpty);
        expect(song.durationMs, greaterThan(0));
        expect(song.bpm, greaterThan(0));

        // Check each note has positive duration and valid pitch
        for (final note in song.notes) {
          expect(note.pitch, inInclusiveRange(21, 108));
          expect(note.durationMs, greaterThan(0));
          expect(note.startTimeMs, greaterThanOrEqualTo(0));
        }

        // Verify notes are sorted chronologically
        for (int i = 0; i < song.notes.length - 1; i++) {
          expect(song.notes[i].startTimeMs, lessThanOrEqualTo(song.notes[i + 1].startTimeMs));
        }
      }
    });

    test('Für Elise contains both left and right hand tracks', () {
      final furElise = MidiParser.getDemoSongs().firstWhere((s) => s.id == 'fur_elise');
      expect(furElise.rightHandNoteCount, greaterThan(0));
      expect(furElise.leftHandNoteCount, greaterThan(0));
    });
  });

  group('PracticeController stuck note recovery tests', () {
    testWidgets('setVirtualKeyPressed toggles off a stuck note when clicked again', (tester) async {
      final controller = PracticeController();
      controller.setMode(PlayMode.freePlay);

      // Press D2 (pitch 38)
      controller.setVirtualKeyPressed(38, true);
      expect(controller.userHeldNotes.containsKey(38), isTrue);

      // Clicking D2 again while stuck immediately clears it
      controller.setVirtualKeyPressed(38, true);
      expect(controller.userHeldNotes.containsKey(38), isFalse);
      expect(controller.freePlayNotes.every((n) => !n.isHeld), isTrue);

      controller.dispose();
    });

    testWidgets('clearAllHeldNotes resets all active notes and detaches all sticks', (tester) async {
      final controller = PracticeController();
      controller.setMode(PlayMode.freePlay);

      controller.setVirtualKeyPressed(38, true);
      controller.setVirtualKeyPressed(45, true);
      expect(controller.userHeldNotes.length, 2);

      controller.clearAllHeldNotes();
      expect(controller.userHeldNotes.isEmpty, isTrue);
      expect(controller.freePlayNotes.every((n) => !n.isHeld), isTrue);

      controller.dispose();
    });
  });
}
