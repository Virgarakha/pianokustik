import 'midi_note.dart';

/// Represents a parsed musical piece or MIDI song
class MidiSong {
  final String id;
  final String title;
  final String composer;
  final int durationMs;
  final double bpm;
  final List<MidiNote> notes;
  final int totalTicks;
  final int division;

  MidiSong({
    required this.id,
    required this.title,
    this.composer = 'Unknown',
    required this.durationMs,
    this.bpm = 120.0,
    required this.notes,
    this.totalTicks = 0,
    this.division = 480,
  });

  /// Count of notes for right hand (treble)
  int get rightHandNoteCount =>
      notes.where((n) => n.hand == HandTrack.right).length;

  /// Count of notes for left hand (bass)
  int get leftHandNoteCount =>
      notes.where((n) => n.hand == HandTrack.left).length;

  /// Lowest pitch present in this song
  int get minPitch {
    if (notes.isEmpty) return 21;
    return notes.map((n) => n.pitch).reduce((a, b) => a < b ? a : b);
  }

  /// Highest pitch present in this song
  int get maxPitch {
    if (notes.isEmpty) return 108;
    return notes.map((n) => n.pitch).reduce((a, b) => a > b ? a : b);
  }

  /// Reset all hit/miss runtime statuses
  void resetState() {
    for (final note in notes) {
      note.isHit = false;
      note.isMissed = false;
      note.isSoundPlayed = false;
    }
  }

  /// Fast binary search windowing to find notes overlapping [fromMs, toMs].
  /// Skips thousands of off-screen notes instantly with O(log N) lookup and early break.
  List<MidiNote> getNotesInWindow(int fromMs, int toMs) {
    if (notes.isEmpty) return const [];

    final targetStart = fromMs - 6000; // max reasonable note duration tolerance
    int low = 0;
    int high = notes.length;

    while (low < high) {
      final mid = (low + high) >> 1;
      if (notes[mid].startTimeMs < targetStart) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    final result = <MidiNote>[];
    for (int i = low; i < notes.length; i++) {
      final note = notes[i];
      if (note.startTimeMs > toMs) break; // EARLY TERMINATION! Never scan future notes
      if (note.endTimeMs >= fromMs) {
        result.add(note);
      }
    }
    return result;
  }
}
