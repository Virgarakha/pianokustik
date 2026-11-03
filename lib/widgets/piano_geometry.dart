import 'package:flutter/painting.dart';
import '../models/chord_detector.dart';
import '../models/midi_note.dart';

class PianoKeyInfo {
  final int pitch;
  final bool isBlack;
  final int whiteKeyIndex; // Index 0..51 for white keys, or index of white key to the left for black keys
  final String noteName;

  PianoKeyInfo({
    required this.pitch,
    required this.isBlack,
    required this.whiteKeyIndex,
    required this.noteName,
  });
}

class KeyFraction {
  final double leftFraction;
  final double rightFraction;
  final bool isBlack;

  const KeyFraction(this.leftFraction, this.rightFraction, this.isBlack);
}

class PianoGeometry {
  static const int minPitch = 21;  // A0
  static const int maxPitch = 108; // C8
  static const int totalWhiteKeys = 52;

  // Precomputed list of 88 keys
  static final List<PianoKeyInfo> allKeys = _generateAllKeys();
  static final Map<int, PianoKeyInfo> keyMap = {
    for (final k in allKeys) k.pitch: k,
  };

  // Ultra-fast direct array lookup (0..127) for horizontal fractions. ZERO hash lookup overhead!
  static final List<KeyFraction> pitchFractions = _generatePitchFractions();

  // Pre-laid-out TextPainters for labels to eliminate per-frame layout cost
  static final Map<int, TextPainter> octaveTextPainters = _initOctaveTextPainters();
  static final Map<int, TextPainter> notAngkaTextPainters = _initNotAngkaTextPainters();
  static final Map<int, TextPainter> noteNameTextPainters = _initNoteNameTextPainters();
  static final Map<int, TextPainter> flyingStickLabelPainters = _initFlyingStickLabelPainters();
  static final Map<int, TextPainter> flyingStickNoteNamePainters = _initFlyingStickNoteNamePainters();

  static List<KeyFraction> _generatePitchFractions() {
    final list = List<KeyFraction>.filled(128, const KeyFraction(0, 0, false));
    final whiteKeyFraction = 1.0 / totalWhiteKeys;
    final blackKeyFraction = whiteKeyFraction * 0.65;

    for (final key in allKeys) {
      if (!key.isBlack) {
        final left = key.whiteKeyIndex * whiteKeyFraction;
        list[key.pitch] = KeyFraction(left, left + whiteKeyFraction, false);
      } else {
        final boundary = (key.whiteKeyIndex + 1) * whiteKeyFraction;
        final left = boundary - (blackKeyFraction / 2.0);
        list[key.pitch] = KeyFraction(left, left + blackKeyFraction, true);
      }
    }
    return list;
  }

  static Map<int, TextPainter> _initOctaveTextPainters() {
    final map = <int, TextPainter>{};
    for (int p = minPitch; p <= maxPitch; p++) {
      if (p % 12 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: MidiNote.pitchToNoteName(p),
            style: const TextStyle(
              color: Color(0xFFB39880),
              fontSize: 10.0,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        map[p] = tp;
      }
    }
    return map;
  }

  static Map<int, TextPainter> _initNotAngkaTextPainters() {
    final map = <int, TextPainter>{};
    for (int p = minPitch; p <= maxPitch; p++) {
      final isBlack = MidiNote.isPitchBlackKey(p);
      final text = ChordDetector.getNotAngka(p);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: isBlack ? const Color(0xFFDCC2A6) : const Color(0xFF8F7660),
            fontSize: isBlack ? 8.5 : 10.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      map[p] = tp;
    }
    return map;
  }

  static Map<int, TextPainter> _initNoteNameTextPainters() {
    final map = <int, TextPainter>{};
    for (int p = minPitch; p <= maxPitch; p++) {
      final isBlack = MidiNote.isPitchBlackKey(p);
      final text = ChordDetector.getNoteLetter(p);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: isBlack ? const Color(0xFFDCC2A6) : const Color(0xFF8F7660),
            fontSize: isBlack ? 8.5 : 10.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      map[p] = tp;
    }
    return map;
  }

  static Map<int, TextPainter> _initFlyingStickLabelPainters() {
    final map = <int, TextPainter>{};
    for (int p = minPitch; p <= maxPitch; p++) {
      final text = ChordDetector.notAngkaMap[p % 12];
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Color(0xFF1E1A16),
            fontSize: 9.0,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      map[p] = tp;
    }
    return map;
  }

  static Map<int, TextPainter> _initFlyingStickNoteNamePainters() {
    final map = <int, TextPainter>{};
    for (int p = minPitch; p <= maxPitch; p++) {
      final text = ChordDetector.getNoteLetter(p);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Color(0xFF1E1A16),
            fontSize: 9.0,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      map[p] = tp;
    }
    return map;
  }

  static List<PianoKeyInfo> _generateAllKeys() {
    final list = <PianoKeyInfo>[];
    int currentWhiteIndex = 0;

    for (int p = minPitch; p <= maxPitch; p++) {
      final isBlack = MidiNote.isPitchBlackKey(p);
      final noteName = MidiNote.pitchToNoteName(p);

      if (!isBlack) {
        list.add(PianoKeyInfo(
          pitch: p,
          isBlack: false,
          whiteKeyIndex: currentWhiteIndex,
          noteName: noteName,
        ));
        currentWhiteIndex++;
      } else {
        list.add(PianoKeyInfo(
          pitch: p,
          isBlack: true,
          whiteKeyIndex: currentWhiteIndex - 1,
          noteName: noteName,
        ));
      }
    }
    return list;
  }

  /// Instantaneous flat array lookup for horizontal bounds [left, right]
  static (double, double) getHorizontalBounds(int pitch, double totalWidth) {
    if (pitch < 0 || pitch >= 128) return (0.0, 0.0);
    final kf = pitchFractions[pitch];
    return (kf.leftFraction * totalWidth, kf.rightFraction * totalWidth);
  }

  /// Get precise bounding Rect for a key given keyboard size
  static Rect getKeyRect(int pitch, double totalWidth, double keyboardHeight) {
    final (left, right) = getHorizontalBounds(pitch, totalWidth);
    final isBlack = MidiNote.isPitchBlackKey(pitch);

    if (isBlack) {
      return Rect.fromLTRB(left, 0, right, keyboardHeight * 0.63);
    } else {
      return Rect.fromLTRB(left, 0, right, keyboardHeight);
    }
  }

  /// Determine which key is at a given local (x, y) offset
  static int? getPitchAt(Offset position, double totalWidth, double keyboardHeight) {
    if (position.dx < 0 || position.dx > totalWidth || position.dy < 0 || position.dy > keyboardHeight) {
      return null;
    }

    // 1. Check black keys first (they overlap on top)
    for (final key in allKeys) {
      if (key.isBlack) {
        final rect = getKeyRect(key.pitch, totalWidth, keyboardHeight);
        if (rect.contains(position)) {
          return key.pitch;
        }
      }
    }

    // 2. Check white keys
    for (final key in allKeys) {
      if (!key.isBlack) {
        final rect = getKeyRect(key.pitch, totalWidth, keyboardHeight);
        if (rect.contains(position)) {
          return key.pitch;
        }
      }
    }

    return null;
  }
}
