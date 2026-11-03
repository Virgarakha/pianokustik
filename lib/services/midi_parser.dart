import 'dart:typed_data';
import '../models/midi_note.dart';
import '../models/midi_song.dart';

class MidiParser {
  /// Parse raw bytes of a Standard MIDI File (.mid)
  static MidiSong parseMidiBytes(Uint8List bytes, {String title = 'Imported Song'}) {
    final reader = _ByteReader(bytes);

    // 1. Check MThd header
    final headerChunk = reader.readString(4);
    if (headerChunk != 'MThd') {
      throw FormatException('Invalid MIDI header: expected MThd, got $headerChunk');
    }

    final headerLength = reader.readUint32();
    if (headerLength < 6) {
      throw const FormatException('Invalid MThd chunk length');
    }

    /* final format = */ reader.readUint16();
    final numTracks = reader.readUint16();
    final timeDivision = reader.readUint16();
    // Skip any extra header bytes if length > 6
    if (headerLength > 6) {
      reader.skip(headerLength - 6);
    }

    int ticksPerQuarterNote = timeDivision;
    if ((timeDivision & 0x8000) != 0) {
      // SMTPE frames per second format fallback
      ticksPerQuarterNote = 480;
    }

    final List<_RawNoteEvent> rawEvents = [];
    final List<_TempoChange> tempoChanges = [];
    String parsedTitle = title;

    // 2. Read each track chunk (MTrk)
    for (int t = 0; t < numTracks && !reader.isAtEnd; t++) {
      if (reader.remainingBytes < 8) break;
      final trackChunk = reader.readString(4);
      final trackLength = reader.readUint32();

      if (trackChunk != 'MTrk') {
        // Unknown chunk, skip
        reader.skip(trackLength);
        continue;
      }

      final trackEndOffset = reader.offset + trackLength;
      int currentTick = 0;
      int runningStatus = 0;

      while (reader.offset < trackEndOffset && !reader.isAtEnd) {
        final deltaTicks = reader.readVLQ();
        currentTick += deltaTicks;

        int statusByte = reader.readUint8();
        if ((statusByte & 0x80) == 0) {
          // Running status: this byte is actually the first data byte!
          reader.offset--;
          statusByte = runningStatus;
        } else {
          runningStatus = statusByte;
        }

        final eventType = statusByte & 0xF0;
        final channel = statusByte & 0x0F;

        if (statusByte == 0xFF) {
          // Meta Event
          final metaType = reader.readUint8();
          final metaLength = reader.readVLQ();

          if (metaType == 0x51 && metaLength == 3) {
            // Set Tempo (microseconds per quarter note)
            final us1 = reader.readUint8();
            final us2 = reader.readUint8();
            final us3 = reader.readUint8();
            final usPerQuarter = (us1 << 16) | (us2 << 8) | us3;
            tempoChanges.add(_TempoChange(tick: currentTick, usPerQuarter: usPerQuarter));
          } else if (metaType == 0x03 && metaLength > 0) {
            // Track Name
            final name = reader.readString(metaLength);
            if (parsedTitle == 'Imported Song' && name.trim().isNotEmpty) {
              parsedTitle = name.trim();
            }
          } else {
            reader.skip(metaLength);
          }
        } else if (statusByte == 0xF0 || statusByte == 0xF7) {
          // Sysex Event
          final sysexLength = reader.readVLQ();
          reader.skip(sysexLength);
        } else {
          // Normal Channel Voice Message
          switch (eventType) {
            case 0x80: // Note Off
              final pitch = reader.readUint8();
              /* final velocity = */ reader.readUint8();
              rawEvents.add(_RawNoteEvent(
                tick: currentTick,
                isNoteOn: false,
                pitch: pitch,
                velocity: 0,
                channel: channel,
                trackIndex: t,
              ));
              break;

            case 0x90: // Note On (velocity 0 is Note Off)
              final pitch = reader.readUint8();
              final velocity = reader.readUint8();
              rawEvents.add(_RawNoteEvent(
                tick: currentTick,
                isNoteOn: velocity > 0,
                pitch: pitch,
                velocity: velocity,
                channel: channel,
                trackIndex: t,
              ));
              break;

            case 0xA0: // Polyphonic aftertouch
            case 0xB0: // Control change
            case 0xE0: // Pitch wheel
              reader.readUint8();
              reader.readUint8();
              break;

            case 0xC0: // Program change
            case 0xD0: // Channel pressure
              reader.readUint8();
              break;
          }
        }
      }

      // Ensure reader offset aligns with end of track
      if (reader.offset < trackEndOffset) {
        reader.offset = trackEndOffset;
      }
    }

    // 3. Setup default tempo if none specified (default 120 BPM = 500,000 us/quarter)
    if (tempoChanges.isEmpty || tempoChanges.first.tick != 0) {
      tempoChanges.insert(0, _TempoChange(tick: 0, usPerQuarter: 500000));
    }
    tempoChanges.sort((a, b) => a.tick.compareTo(b.tick));

    // Helper: convert tick to millisecond timestamp
    int tickToMs(int tick) {
      double totalMs = 0.0;
      int lastTick = 0;
      int currentUs = 500000;

      for (final tc in tempoChanges) {
        if (tick <= tc.tick) break;
        final delta = tc.tick - lastTick;
        totalMs += (delta * currentUs) / (ticksPerQuarterNote * 1000.0);
        lastTick = tc.tick;
        currentUs = tc.usPerQuarter;
      }

      final remaining = tick - lastTick;
      totalMs += (remaining * currentUs) / (ticksPerQuarterNote * 1000.0);
      return totalMs.round();
    }

    // 4. Pair NoteOn with NoteOff to produce MidiNotes
    // Sort events by tick
    rawEvents.sort((a, b) => a.tick.compareTo(b.tick));

    final Map<int, List<_PendingNote>> openNotes = {};
    final List<MidiNote> parsedNotes = [];

    for (final event in rawEvents) {
      final key = (event.channel << 8) | event.pitch;
      if (event.isNoteOn) {
        openNotes.putIfAbsent(key, () => []).add(_PendingNote(
          pitch: event.pitch,
          velocity: event.velocity,
          channel: event.channel,
          trackIndex: event.trackIndex,
          startTick: event.tick,
          startTimeMs: tickToMs(event.tick),
        ));
      } else {
        // Note Off
        final list = openNotes[key];
        if (list != null && list.isNotEmpty) {
          final pending = list.removeAt(0);
          final endMs = tickToMs(event.tick);
          int durationMs = endMs - pending.startTimeMs;
          if (durationMs < 50) durationMs = 50; // Minimum audible duration

          // Determine hand assignment
          // Format 1 usually assigns track 1 to right hand and track 2 to left hand
          HandTrack hand;
          if (numTracks > 2 && pending.trackIndex > 0) {
            hand = pending.trackIndex == 1 ? HandTrack.right : HandTrack.left;
          } else {
            // Fallback: split around Middle C (pitch 60)
            hand = pending.pitch >= 60 ? HandTrack.right : HandTrack.left;
          }

          parsedNotes.add(MidiNote(
            pitch: pending.pitch,
            startTimeMs: pending.startTimeMs,
            durationMs: durationMs,
            velocity: pending.velocity,
            hand: hand,
            channel: pending.channel,
          ));
        }
      }
    }

    // Close any unclosed notes (clamp to 500ms duration)
    openNotes.forEach((_, list) {
      for (final pending in list) {
        parsedNotes.add(MidiNote(
          pitch: pending.pitch,
          startTimeMs: pending.startTimeMs,
          durationMs: 400,
          velocity: pending.velocity,
          hand: pending.pitch >= 60 ? HandTrack.right : HandTrack.left,
          channel: pending.channel,
        ));
      }
    });

    // Sort final notes by start time
    parsedNotes.sort((a, b) => a.startTimeMs.compareTo(b.startTimeMs));

    final totalDurationMs = parsedNotes.isEmpty
        ? 0
        : parsedNotes.map((n) => n.endTimeMs).reduce((a, b) => a > b ? a : b);

    // Initial BPM from first tempo change
    final initialBpm = 60000000.0 / tempoChanges.first.usPerQuarter;

    return MidiSong(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: parsedTitle,
      composer: 'MIDI File',
      durationMs: totalDurationMs,
      bpm: initialBpm,
      notes: parsedNotes,
      division: ticksPerQuarterNote,
    );
  }

  /// Built-in classic piano demo songs
  static List<MidiSong> getDemoSongs() {
    final list = [
      _createFurElise(),
      _createCanonInD(),
      _createMoonlightSonata(),
      _createTwinkle(),
    ];
    for (final song in list) {
      song.notes.sort((a, b) => a.startTimeMs.compareTo(b.startTimeMs));
    }
    return list;
  }

  // --- Demo Songs Generators ---

  static MidiSong _createFurElise() {
    // Beethoven - Für Elise (Theme intro)
    final notes = <MidiNote>[];
    int t = 800; // Initial delay
    final step = 280; // 16th note step in ms

    // Right hand main motif
    final rightMotif = [
      76, 75, 76, 75, 76, 71, 74, 72, 69 // E5, D#5, E5, D#5, E5, B4, D5, C5, A4
    ];
    final leftBass = [
      null, null, null, null, null, null, null, null, 45 // Bass A2
    ];

    for (int i = 0; i < rightMotif.length; i++) {
      notes.add(MidiNote(
        pitch: rightMotif[i],
        startTimeMs: t,
        durationMs: i == rightMotif.length - 1 ? step * 2 : step - 30,
        hand: HandTrack.right,
      ));
      if (leftBass[i] != null) {
        notes.add(MidiNote(
          pitch: leftBass[i]!,
          startTimeMs: t,
          durationMs: step * 3,
          hand: HandTrack.left,
        ));
      }
      t += step;
    }

    // Left hand arpeggio: C3, E3, A3
    notes.add(MidiNote(pitch: 48, startTimeMs: t, durationMs: step, hand: HandTrack.left)); // C3
    t += step;
    notes.add(MidiNote(pitch: 52, startTimeMs: t, durationMs: step, hand: HandTrack.left)); // E3
    t += step;
    notes.add(MidiNote(pitch: 57, startTimeMs: t, durationMs: step * 2, hand: HandTrack.left)); // A3

    // Right hand: C4, E4, B4
    notes.add(MidiNote(pitch: 60, startTimeMs: t - step, durationMs: step, hand: HandTrack.right)); // C4
    notes.add(MidiNote(pitch: 64, startTimeMs: t, durationMs: step, hand: HandTrack.right)); // E4
    t += step;
    notes.add(MidiNote(pitch: 71, startTimeMs: t, durationMs: step * 2, hand: HandTrack.right)); // B4
    notes.add(MidiNote(pitch: 40, startTimeMs: t, durationMs: step * 3, hand: HandTrack.left)); // E2
    t += step * 2;

    // Second phrase
    notes.add(MidiNote(pitch: 52, startTimeMs: t, durationMs: step, hand: HandTrack.left)); // E3
    notes.add(MidiNote(pitch: 56, startTimeMs: t + step, durationMs: step, hand: HandTrack.left)); // G#3
    notes.add(MidiNote(pitch: 64, startTimeMs: t, durationMs: step, hand: HandTrack.right)); // E4
    notes.add(MidiNote(pitch: 68, startTimeMs: t + step, durationMs: step, hand: HandTrack.right)); // G#4
    t += step * 2;
    notes.add(MidiNote(pitch: 72, startTimeMs: t, durationMs: step * 2, hand: HandTrack.right)); // C5
    notes.add(MidiNote(pitch: 45, startTimeMs: t, durationMs: step * 3, hand: HandTrack.left)); // A2
    t += step * 2;

    // Motif repeats
    final repeatMotif = [
      76, 75, 76, 75, 76, 71, 74, 72, 69
    ];
    for (int i = 0; i < repeatMotif.length; i++) {
      notes.add(MidiNote(
        pitch: repeatMotif[i],
        startTimeMs: t,
        durationMs: i == repeatMotif.length - 1 ? step * 2 : step - 30,
        hand: HandTrack.right,
      ));
      t += step;
    }

    final duration = notes.map((n) => n.endTimeMs).reduce((a, b) => a > b ? a : b) + 1000;

    return MidiSong(
      id: 'fur_elise',
      title: 'Für Elise (Theme)',
      composer: 'L. v. Beethoven',
      durationMs: duration,
      bpm: 130.0,
      notes: notes,
    );
  }

  static MidiSong _createCanonInD() {
    // Pachelbel - Canon in D
    final notes = <MidiNote>[];
    int t = 800;
    final beat = 600; // Quarter note ms

    // Famous 8-chord bass progression: D - A - Bm - F#m - G - D - G - A
    final bassNotes = [38, 33, 35, 30, 31, 26, 31, 33]; // D2, A1, B1, F#1, G1, D1, G1, A1
    final rightMelody = [
      // F#5, E5, D5, C#5, B4, A4, B4, C#5
      78, 76, 74, 73, 71, 69, 71, 73,
      // F#5, G5, A5, A4, B4, C#5, D5, E5
      78, 79, 81, 69, 71, 73, 74, 76
    ];

    // Bass line loop
    for (int loop = 0; loop < 2; loop++) {
      for (int i = 0; i < bassNotes.length; i++) {
        final bassTime = t + (loop * bassNotes.length + i) * beat * 2;
        notes.add(MidiNote(
          pitch: bassNotes[i],
          startTimeMs: bassTime,
          durationMs: beat * 2 - 50,
          hand: HandTrack.left,
        ));
      }
    }

    // Right hand melody
    for (int i = 0; i < rightMelody.length; i++) {
      notes.add(MidiNote(
        pitch: rightMelody[i],
        startTimeMs: t + (i * beat),
        durationMs: beat - 40,
        hand: HandTrack.right,
      ));
    }

    final duration = notes.map((n) => n.endTimeMs).reduce((a, b) => a > b ? a : b) + 1200;

    return MidiSong(
      id: 'canon_in_d',
      title: 'Canon in D',
      composer: 'Johann Pachelbel',
      durationMs: duration,
      bpm: 100.0,
      notes: notes,
    );
  }

  static MidiSong _createMoonlightSonata() {
    // Beethoven - Moonlight Sonata (Adagio sostenuto)
    final notes = <MidiNote>[];
    int t = 800;
    final triplet = 320; // Triplet 8th note in ms

    // Bass pedal notes (C#2 + C#3 octave)
    notes.add(MidiNote(pitch: 37, startTimeMs: t, durationMs: triplet * 12, hand: HandTrack.left)); // C#2
    notes.add(MidiNote(pitch: 49, startTimeMs: t, durationMs: triplet * 12, hand: HandTrack.left)); // C#3

    // Famous triplet arpeggios: G#3, C#4, E4
    final tripletArp = [56, 61, 64]; // G#3, C#4, E4
    for (int rep = 0; rep < 4; rep++) {
      for (int i = 0; i < 3; i++) {
        notes.add(MidiNote(
          pitch: tripletArp[i],
          startTimeMs: t + (rep * 3 + i) * triplet,
          durationMs: triplet * 2,
          hand: HandTrack.right,
        ));
      }
    }

    // Treble melody note G#4 enters on 4th beat
    notes.add(MidiNote(
      pitch: 68, // G#4
      startTimeMs: t + 9 * triplet,
      durationMs: triplet * 3,
      hand: HandTrack.right,
    ));

    t += 12 * triplet;

    // Second measure: Bass B1 + B2
    notes.add(MidiNote(pitch: 35, startTimeMs: t, durationMs: triplet * 12, hand: HandTrack.left));
    notes.add(MidiNote(pitch: 47, startTimeMs: t, durationMs: triplet * 12, hand: HandTrack.left));

    // Arpeggio: G#3, B3, E4
    final tripletArp2 = [56, 59, 64];
    for (int rep = 0; rep < 4; rep++) {
      for (int i = 0; i < 3; i++) {
        notes.add(MidiNote(
          pitch: tripletArp2[i],
          startTimeMs: t + (rep * 3 + i) * triplet,
          durationMs: triplet * 2,
          hand: HandTrack.right,
        ));
      }
    }

    final duration = notes.map((n) => n.endTimeMs).reduce((a, b) => a > b ? a : b) + 1500;

    return MidiSong(
      id: 'moonlight_sonata',
      title: 'Moonlight Sonata (Op. 27 No. 2)',
      composer: 'L. v. Beethoven',
      durationMs: duration,
      bpm: 60.0,
      notes: notes,
    );
  }

  static MidiSong _createTwinkle() {
    // Twinkle Twinkle Little Star
    final notes = <MidiNote>[];
    int t = 600;
    final beat = 500;

    // C4, C4, G4, G4, A4, A4, G4
    final melody = [60, 60, 67, 67, 69, 69, 67, 65, 65, 64, 64, 62, 62, 60];
    final durations = [1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2];
    // Simple bass harmony: C3, G2, F2, C3...
    final bass = [48, 48, 43, 43, 41, 41, 43, 41, 41, 48, 48, 43, 43, 48];

    for (int i = 0; i < melody.length; i++) {
      final dur = durations[i] * beat;
      notes.add(MidiNote(
        pitch: melody[i],
        startTimeMs: t,
        durationMs: dur - 50,
        hand: HandTrack.right,
      ));
      notes.add(MidiNote(
        pitch: bass[i],
        startTimeMs: t,
        durationMs: dur - 50,
        hand: HandTrack.left,
      ));
      t += dur;
    }

    final duration = notes.map((n) => n.endTimeMs).reduce((a, b) => a > b ? a : b) + 800;

    return MidiSong(
      id: 'twinkle',
      title: 'Twinkle Twinkle Little Star',
      composer: 'Traditional',
      durationMs: duration,
      bpm: 110.0,
      notes: notes,
    );
  }
}

// Internal helper for binary stream reading
class _ByteReader {
  final Uint8List bytes;
  int offset = 0;

  _ByteReader(this.bytes);

  bool get isAtEnd => offset >= bytes.length;
  int get remainingBytes => bytes.length - offset;

  int readUint8() {
    if (offset >= bytes.length) return 0;
    return bytes[offset++];
  }

  int readUint16() {
    final b1 = readUint8();
    final b2 = readUint8();
    return (b1 << 8) | b2;
  }

  int readUint32() {
    final b1 = readUint8();
    final b2 = readUint8();
    final b3 = readUint8();
    final b4 = readUint8();
    return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
  }

  String readString(int length) {
    final end = (offset + length).clamp(0, bytes.length);
    final strBytes = bytes.sublist(offset, end);
    offset = end;
    return String.fromCharCodes(strBytes);
  }

  int readVLQ() {
    int value = 0;
    while (!isAtEnd) {
      final b = readUint8();
      value = (value << 7) | (b & 0x7F);
      if ((b & 0x80) == 0) break;
    }
    return value;
  }

  void skip(int count) {
    offset = (offset + count).clamp(0, bytes.length);
  }
}

class _RawNoteEvent {
  final int tick;
  final bool isNoteOn;
  final int pitch;
  final int velocity;
  final int channel;
  final int trackIndex;

  _RawNoteEvent({
    required this.tick,
    required this.isNoteOn,
    required this.pitch,
    required this.velocity,
    required this.channel,
    required this.trackIndex,
  });
}

class _PendingNote {
  final int pitch;
  final int velocity;
  final int channel;
  final int trackIndex;
  final int startTick;
  final int startTimeMs;

  _PendingNote({
    required this.pitch,
    required this.velocity,
    required this.channel,
    required this.trackIndex,
    required this.startTick,
    required this.startTimeMs,
  });
}

class _TempoChange {
  final int tick;
  final int usPerQuarter;

  _TempoChange({required this.tick, required this.usPerQuarter});
}
