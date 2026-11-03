import 'dart:math';

/// Representation of a musical hand or track assignment
enum HandTrack {
  left,  // Typically bass clef / lower octave (blue)
  right, // Typically treble clef / upper octave (green)
  both,
}

/// Represents an active or sequenced MIDI note
class MidiNote {
  final int pitch; // 21 (A0) to 108 (C8)
  final int startTimeMs;
  final int durationMs;
  final int velocity;
  final HandTrack hand;
  final int channel;

  // Runtime playback states
  bool isHit;
  bool isMissed;
  bool isSoundPlayed;

  MidiNote({
    required this.pitch,
    required this.startTimeMs,
    required this.durationMs,
    this.velocity = 80,
    this.hand = HandTrack.right,
    this.channel = 0,
    this.isHit = false,
    this.isMissed = false,
    this.isSoundPlayed = false,
  });

  int get endTimeMs => startTimeMs + durationMs;

  /// Check if this note is currently active at a given playback timestamp
  bool isActiveAt(int timeMs) {
    return timeMs >= startTimeMs && timeMs <= endTimeMs;
  }

  /// Note name with octave, e.g. "C4", "F#5", "A0"
  String get noteName {
    return pitchToNoteName(pitch);
  }

  /// Returns true if this is a black key (sharp / flat)
  bool get isBlackKey {
    return isPitchBlackKey(pitch);
  }

  static const List<String> _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  static String pitchToNoteName(int pitch) {
    if (pitch < 0 || pitch > 127) return '?';
    final name = _noteNames[pitch % 12];
    final octave = (pitch ~/ 12) - 1;
    return '$name$octave';
  }

  static bool isPitchBlackKey(int pitch) {
    final noteIndex = pitch % 12;
    // C#, D#, F#, G#, A# are 1, 3, 6, 8, 10
    return noteIndex == 1 || noteIndex == 3 || noteIndex == 6 || noteIndex == 8 || noteIndex == 10;
  }

  /// Frequency in Hz from MIDI pitch: f = 440 * 2^((pitch - 69) / 12)
  static double pitchToFrequency(int pitch) {
    return 440.0 * pow(2.0, (pitch - 69.0) / 12.0);
  }
}

/// Live MIDI Input Packet received from external hardware or user interaction
enum MidiPacketType {
  noteOn,
  noteOff,
  controlChange,
  other,
}

class LiveMidiEvent {
  final MidiPacketType type;
  final int pitch;
  final int velocity;
  final int controller;
  final int value;
  final int channel;
  final DateTime timestamp;

  LiveMidiEvent({
    required this.type,
    this.pitch = 0,
    this.velocity = 0,
    this.controller = 0,
    this.value = 0,
    this.channel = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isPedal => type == MidiPacketType.controlChange && controller == 64;
  bool get isPedalDown => isPedal && value >= 64;
}
