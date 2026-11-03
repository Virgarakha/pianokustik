import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/midi_note.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Voice pool to handle fast polyphonic piano playing
  static const int _voicePoolSize = 6;
  final List<AudioPlayer> _players = [];
  int _currentVoice = 0;

  // Cache of synthesized WAV bytes per MIDI pitch (21 to 108)
  final Map<int, Uint8List> _wavCache = {};
  bool isMuted = false;

  void init() {
    for (int i = 0; i < _voicePoolSize; i++) {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.stop);
      _players.add(player);
    }

    // Pre-warm audio cache so key strikes have instant response with zero math latency
    Future.microtask(() {
      for (int p = 21; p <= 108; p++) {
        _getOrCreateWav(p);
      }
    });
  }

  /// Play a piano note with specific pitch (21..108) and velocity (0..127)
  Future<void> playNote(int pitch, {int velocity = 100}) async {
    if (isMuted || pitch < 21 || pitch > 108) return;

    final wavBytes = _getOrCreateWav(pitch);
    final player = _players[_currentVoice];
    _currentVoice = (_currentVoice + 1) % _voicePoolSize;

    try {
      final volume = (velocity / 127.0).clamp(0.1, 1.0);
      await player.setVolume(volume);
      await player.play(BytesSource(wavBytes));
    } catch (e) {
      debugPrint('[AudioService] Play error: $e');
    }
  }

  /// Stop all voices
  void stopAll() {
    for (final p in _players) {
      p.stop();
    }
  }

  /// Generate or retrieve cached WAV PCM audio for the given pitch
  Uint8List _getOrCreateWav(int pitch) {
    if (_wavCache.containsKey(pitch)) {
      return _wavCache[pitch]!;
    }

    final freq = MidiNote.pitchToFrequency(pitch);
    final wavBytes = _generatePianoToneWav(freq);
    _wavCache[pitch] = wavBytes;
    return wavBytes;
  }

  /// Synthesize a rich acoustic piano tone as 16-bit PCM WAV (22050 Hz, mono)
  static Uint8List _generatePianoToneWav(double frequency) {
    const int sampleRate = 22050;
    final double durationSec = (0.5 + (40.0 / (frequency + 20.0))).clamp(0.4, 0.9);
    final int numSamples = (sampleRate * durationSec).toInt();
    final int byteLength = numSamples * 2;

    final totalSize = 44 + byteLength;
    final buffer = Uint8List(totalSize);
    final bdata = ByteData.view(buffer.buffer);

    // RIFF chunk descriptor
    bdata.setUint8(0, 0x52); // 'R'
    bdata.setUint8(1, 0x49); // 'I'
    bdata.setUint8(2, 0x46); // 'F'
    bdata.setUint8(3, 0x46); // 'F'
    bdata.setUint32(4, totalSize - 8, Endian.little);
    bdata.setUint8(8, 0x57);  // 'W'
    bdata.setUint8(9, 0x41);  // 'A'
    bdata.setUint8(10, 0x56); // 'V'
    bdata.setUint8(11, 0x45); // 'E'

    // fmt sub-chunk
    bdata.setUint8(12, 0x66); // 'f'
    bdata.setUint8(13, 0x6D); // 'm'
    bdata.setUint8(14, 0x74); // 't'
    bdata.setUint8(15, 0x20); // ' '
    bdata.setUint32(16, 16, Endian.little);
    bdata.setUint16(20, 1, Endian.little);
    bdata.setUint16(22, 1, Endian.little);
    bdata.setUint32(24, sampleRate, Endian.little);
    bdata.setUint32(28, sampleRate * 2, Endian.little);
    bdata.setUint16(32, 2, Endian.little);
    bdata.setUint16(34, 16, Endian.little);

    // data sub-chunk
    bdata.setUint8(36, 0x64); // 'd'
    bdata.setUint8(37, 0x61); // 'a'
    bdata.setUint8(38, 0x74); // 't'
    bdata.setUint8(39, 0x61); // 'a'
    bdata.setUint32(40, byteLength, Endian.little);

    final double decayRate = 4.2 / durationSec;
    final double omega = 2.0 * pi * frequency;

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate.toDouble();
      final double env = exp(-decayRate * t);

      double sample = sin(omega * t) * 0.65;
      sample += sin(2.0 * omega * t) * 0.25;
      sample += sin(3.0 * omega * t) * 0.12;

      if (t < 0.01) {
        final double clickEnv = 1.0 - (t / 0.01);
        sample += (sin(12.0 * omega * t) * 0.2) * clickEnv;
      }

      sample *= env;
      final int sample16 = (sample.clamp(-1.0, 1.0) * 32767.0).toInt();
      bdata.setInt16(44 + i * 2, sample16, Endian.little);
    }

    return buffer;
  }

  void dispose() {
    for (final p in _players) {
      p.dispose();
    }
    _players.clear();
  }
}
