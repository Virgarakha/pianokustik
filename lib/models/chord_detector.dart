import 'package:flutter/material.dart';

enum NoteColorTheme {
  gold(
    name: 'Champagne Gold',
    primary: Color(0xFFE8D0B0),
    primaryHighlight: Color(0xFFFFF5E6),
    secondary: Color(0xFFDCA988),
    glow: Color(0xFFDCA86A),
    railCore: Color(0xFFFFF0DC),
    railBevel: Color(0xFFD4AD80),
    accentSwatch: Color(0xFFE5C59E),
  ),
  violet(
    name: 'Neon Violet',
    primary: Color(0xFFA855F7),
    primaryHighlight: Color(0xFFF3E8FF),
    secondary: Color(0xFF7C3AED),
    glow: Color(0xFF9333EA),
    railCore: Color(0xFFFAF5FF),
    railBevel: Color(0xFFA855F7),
    accentSwatch: Color(0xFFC084FC),
  ),
  cyan(
    name: 'Electric Cyan',
    primary: Color(0xFF38BDF8),
    primaryHighlight: Color(0xFFE0F2FE),
    secondary: Color(0xFF0284C7),
    glow: Color(0xFF00E5FF),
    railCore: Color(0xFFF0F9FF),
    railBevel: Color(0xFF38BDF8),
    accentSwatch: Color(0xFF00E5FF),
  ),
  emerald(
    name: 'Emerald Mint',
    primary: Color(0xFF34D399),
    primaryHighlight: Color(0xFFECFDF5),
    secondary: Color(0xFF059669),
    glow: Color(0xFF10B981),
    railCore: Color(0xFFF0FDF4),
    railBevel: Color(0xFF34D399),
    accentSwatch: Color(0xFF10B981),
  ),
  crimson(
    name: 'Crimson Velvet',
    primary: Color(0xFFFB7185),
    primaryHighlight: Color(0xFFFFE4E6),
    secondary: Color(0xFFE11D48),
    glow: Color(0xFFF43F5E),
    railCore: Color(0xFFFFF1F2),
    railBevel: Color(0xFFFB7185),
    accentSwatch: Color(0xFFF43F5E),
  ),
  sakura(
    name: 'Sakura Pink',
    primary: Color(0xFFF472B6),
    primaryHighlight: Color(0xFFFDF2F8),
    secondary: Color(0xFFDB2777),
    glow: Color(0xFFEC4899),
    railCore: Color(0xFFFDF2F8),
    railBevel: Color(0xFFF472B6),
    accentSwatch: Color(0xFFF472B6),
  ),
  amber(
    name: 'Sunset Amber',
    primary: Color(0xFFFBBF24),
    primaryHighlight: Color(0xFFFFFBEB),
    secondary: Color(0xFFD97706),
    glow: Color(0xFFF59E0B),
    railCore: Color(0xFFFEF3C7),
    railBevel: Color(0xFFFBBF24),
    accentSwatch: Color(0xFFF59E0B),
  );

  final String name;
  final Color primary;
  final Color primaryHighlight;
  final Color secondary;
  final Color glow;
  final Color railCore;
  final Color railBevel;
  final Color accentSwatch;

  const NoteColorTheme({
    required this.name,
    required this.primary,
    required this.primaryHighlight,
    required this.secondary,
    required this.glow,
    required this.railCore,
    required this.railBevel,
    required this.accentSwatch,
  });
}

enum KeyLabelMode {
  notAngka('Not Angka (1 2 3 4 5 6 7)'),
  noteName('Nama Nada (C D E F G A B)'),
  octaveOnly('Hanya Oktaf (C1..C8)'),
  none('Polos (Tanpa Label)');

  final String label;
  const KeyLabelMode(this.label);
}

class ChordDetector {
  // Mapping semitones in octave to not angka
  // C=0 -> 1, C#=1 -> 1#, D=2 -> 2, D#=3 -> 2#, E=4 -> 3, F=5 -> 4, F#=6 -> 4#, G=7 -> 5, G#=8 -> 5#, A=9 -> 6, A#=10 -> 6#, B=11 -> 7
  static const List<String> notAngkaMap = [
    '1', '1#', '2', '2#', '3', '4', '4#', '5', '5#', '6', '6#', '7',
  ];

  static const List<String> noteNameMap = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  static String getNotAngka(int pitch) {
    final noteIndex = pitch % 12;
    final octave = (pitch ~/ 12) - 1;
    final base = notAngkaMap[noteIndex];
    // Add octave indicator for high/low
    if (octave >= 5) {
      return '$basė'; // dot above
    } else if (octave <= 3) {
      return '$basẹ'; // dot below
    }
    return base;
  }

  static String getNoteLetter(int pitch) {
    return noteNameMap[pitch % 12];
  }

  /// Detect chord name from a collection of active pitches
  static String? detectChord(Iterable<int> pitches) {
    if (pitches.length < 2) return null;

    final sortedPitches = pitches.toList()..sort();
    final uniqueSemitones = sortedPitches.map((p) => p % 12).toSet().toList()..sort();

    if (uniqueSemitones.length < 2) return null;

    // Check all possible roots
    for (final root in uniqueSemitones) {
      // Calculate intervals from this root (0..11)
      final intervals = uniqueSemitones.map((s) => (s - root + 12) % 12).toSet();
      final rootName = noteNameMap[root];
      final rootAngka = notAngkaMap[root];

      // Major Triad: 0, 4, 7
      if (intervals.containsAll({0, 4, 7}) && intervals.length <= 4) {
        if (intervals.contains(10)) {
          return '$rootName 7 ($rootAngka-3-5-b7)';
        } else if (intervals.contains(11)) {
          return '$rootName Maj7 ($rootAngka-3-5-7)';
        }
        return '$rootName Major ($rootAngka • 3 • 5)';
      }

      // Minor Triad: 0, 3, 7
      if (intervals.containsAll({0, 3, 7}) && intervals.length <= 4) {
        if (intervals.contains(10)) {
          return '$rootName m7 ($rootAngka-b3-5-b7)';
        }
        return '$rootName Minor ($rootAngka • b3 • 5)';
      }

      // Suspended 4th: 0, 5, 7
      if (intervals.containsAll({0, 5, 7})) {
        return '$rootName sus4 ($rootAngka • 4 • 5)';
      }

      // Suspended 2nd: 0, 2, 7
      if (intervals.containsAll({0, 2, 7})) {
        return '$rootName sus2 ($rootAngka • 2 • 5)';
      }

      // Diminished Triad: 0, 3, 6
      if (intervals.containsAll({0, 3, 6})) {
        return '$rootName dim ($rootAngka • b3 • b5)';
      }

      // Augmented Triad: 0, 4, 8
      if (intervals.containsAll({0, 4, 8})) {
        return '$rootName aug ($rootAngka • 3 • #5)';
      }
    }

    // Power chord / 5th: 0, 7
    for (final root in uniqueSemitones) {
      final intervals = uniqueSemitones.map((s) => (s - root + 12) % 12).toSet();
      if (intervals.containsAll({0, 7}) && intervals.length == 2) {
        return '${noteNameMap[root]}5 (${notAngkaMap[root]} • 5)';
      }
    }

    // Octaves / Unison
    if (uniqueSemitones.length == 1) {
      final root = uniqueSemitones.first;
      return '${noteNameMap[root]} Oktaf (${notAngkaMap[root]})';
    }

    // Fallback: list of notes
    final noteNames = uniqueSemitones.map((s) => noteNameMap[s]).join(' - ');
    final angkaNames = uniqueSemitones.map((s) => notAngkaMap[s]).join('-');
    return '$noteNames ($angkaNames)';
  }

  /// Simple, elegant chord name (e.g. "A major", "C minor", "G 7")
  static String? detectSimpleChord(Iterable<int> pitches) {
    if (pitches.length < 2) return null;

    final sortedPitches = pitches.toList()..sort();
    final uniqueSemitones = sortedPitches.map((p) => p % 12).toSet().toList()..sort();
    if (uniqueSemitones.length < 2) return null;

    for (final root in uniqueSemitones) {
      final intervals = uniqueSemitones.map((s) => (s - root + 12) % 12).toSet();
      final rootName = noteNameMap[root];

      // Major Triad: 0, 4, 7
      if (intervals.containsAll({0, 4, 7}) && intervals.length <= 4) {
        if (intervals.contains(10)) {
          return '$rootName 7';
        } else if (intervals.contains(11)) {
          return '$rootName maj7';
        }
        return '$rootName major';
      }

      // Minor Triad: 0, 3, 7
      if (intervals.containsAll({0, 3, 7}) && intervals.length <= 4) {
        if (intervals.contains(10)) {
          return '$rootName m7';
        }
        return '$rootName minor';
      }

      // Suspended 4th: 0, 5, 7
      if (intervals.containsAll({0, 5, 7})) {
        return '$rootName sus4';
      }

      // Suspended 2nd: 0, 2, 7
      if (intervals.containsAll({0, 2, 7})) {
        return '$rootName sus2';
      }

      // Diminished Triad: 0, 3, 6
      if (intervals.containsAll({0, 3, 6})) {
        return '$rootName dim';
      }

      // Augmented Triad: 0, 4, 8
      if (intervals.containsAll({0, 4, 8})) {
        return '$rootName aug';
      }
    }

    // Power chord / 5th: 0, 7
    for (final root in uniqueSemitones) {
      final intervals = uniqueSemitones.map((s) => (s - root + 12) % 12).toSet();
      if (intervals.containsAll({0, 7}) && intervals.length == 2) {
        return '${noteNameMap[root]} 5';
      }
    }

    return null;
  }
}
