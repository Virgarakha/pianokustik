import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/chord_detector.dart';
import '../models/midi_note.dart';
import '../models/midi_song.dart';
import '../services/audio_service.dart';
import '../services/midi_service.dart';

enum PlayMode {
  freePlay,  // Practice freely, live visualizer with upward flying note sticks
  listen,    // Auto-play song
  practice,  // Wait-for-key interactive mode
}

/// Represents an active or flying note stick in Free Play mode
class FreePlayNote {
  final int pitch;
  final double startMs;
  double? endMs; // null while key is currently held down
  final int velocity;

  FreePlayNote({
    required this.pitch,
    required this.startMs,
    this.endMs,
    required this.velocity,
  });

  bool get isHeld => endMs == null;
}

class PracticeController extends ChangeNotifier {
  final MidiService midiService = MidiService();
  final AudioService audioService = AudioService();

  PlayMode _mode = PlayMode.freePlay;
  MidiSong? _currentSong;

  // Dedicated ticker notifier for the 60 FPS visualizer only.
  // This avoids rebuilding Flutter widget trees on every frame!
  final ValueNotifier<int> visualizerTicker = ValueNotifier<int>(0);

  // Playback state for Listen & Practice modes
  bool _isPlaying = false;
  double _currentTimeMs = 0.0;
  double _playbackSpeed = 1.0;
  HandTrack _practicingHand = HandTrack.both;

  // Free Play state
  double _freePlayTimeMs = 0.0;
  final List<FreePlayNote> _freePlayNotes = [];
  final Map<int, FreePlayNote> _heldFreePlayNotes = {};

  // Free Play customizations
  NoteColorTheme _noteColorTheme = NoteColorTheme.gold;
  KeyLabelMode _keyLabelMode = KeyLabelMode.none;
  bool _showFlyingStickLabels = false;
  bool _showLiveChord = true;

  // Active notes
  final Map<int, int> _userHeldNotes = {};
  final Map<int, MidiNote> _songActiveNotes = {};

  // Score & stats
  int _notesHit = 0;
  int _totalNotesPassed = 0;

  int _leadTimeMs = 2500; // 2.5 seconds view window

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  StreamSubscription<LiveMidiEvent>? _midiEventSubscription;

  PracticeController() {
    _init();
  }

  PlayMode get mode => _mode;
  MidiSong? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  double get currentTimeMs => _currentTimeMs;
  double get freePlayTimeMs => _freePlayTimeMs;
  List<FreePlayNote> get freePlayNotes => _freePlayNotes;
  double get playbackSpeed => _playbackSpeed;
  HandTrack get practicingHand => _practicingHand;
  Map<int, int> get userHeldNotes => _userHeldNotes;
  Map<int, MidiNote> get songActiveNotes => _songActiveNotes;
  int get notesHit => _notesHit;
  int get totalNotesPassed => _totalNotesPassed;
  int get leadTimeMs => _leadTimeMs;

  NoteColorTheme get noteColorTheme => _noteColorTheme;
  KeyLabelMode get keyLabelMode => _keyLabelMode;
  bool get showFlyingStickLabels => _showFlyingStickLabels;
  bool get showLiveChord => _showLiveChord;
  String? get currentDetectedChord =>
      _showLiveChord ? ChordDetector.detectChord(_userHeldNotes.keys) : null;
  String? get currentDetectedChordSimple {
    if (!_showLiveChord) return null;
    final pitches = _mode == PlayMode.freePlay
        ? _userHeldNotes.keys
        : (_userHeldNotes.isNotEmpty ? _userHeldNotes.keys : _songActiveNotes.keys);
    return ChordDetector.detectSimpleChord(pitches);
  }

  double get accuracy => _totalNotesPassed == 0
      ? 100.0
      : (_notesHit / _totalNotesPassed * 100.0).clamp(0.0, 100.0);

  void _init() {
    audioService.init();
    midiService.init();

    // Listen to live hardware MIDI events
    _midiEventSubscription = midiService.onLiveEvent.listen(_handleLiveMidiEvent);

    // Setup ticker
    _ticker = Ticker(_onTick);
    _ensureTickerRunning();
  }

  void _ensureTickerRunning() {
    if (!(_ticker?.isActive ?? false)) {
      _lastTick = Duration.zero;
      _ticker?.start();
    }
  }

  /// Change play mode
  void setMode(PlayMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;

    if (_mode == PlayMode.freePlay) {
      pause();
      _songActiveNotes.clear();
      _ensureTickerRunning();
    } else {
      _heldFreePlayNotes.clear();
      _freePlayNotes.clear();
    }
    notifyListeners();
  }

  /// Load a song
  void loadSong(MidiSong song) {
    pause();
    _currentSong = song;
    _currentSong!.resetState();
    _currentTimeMs = 0.0;
    _notesHit = 0;
    _totalNotesPassed = 0;
    _songActiveNotes.clear();
    notifyListeners();
  }

  /// Start / Resume song playback
  void play() {
    if (_isPlaying || _currentSong == null) return;
    _isPlaying = true;
    _ensureTickerRunning();
    notifyListeners();
  }

  /// Pause song playback
  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _songActiveNotes.clear();
    notifyListeners();
  }

  /// Toggle play / pause
  void togglePlay() {
    if (_mode == PlayMode.freePlay) {
      setMode(PlayMode.listen);
      play();
      return;
    }
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  /// Seek to specific millisecond
  void seekTo(double targetMs) {
    if (_currentSong == null) return;
    _currentTimeMs = targetMs.clamp(0.0, _currentSong!.durationMs.toDouble());
    _songActiveNotes.clear();
    for (final note in _currentSong!.notes) {
      if (note.startTimeMs >= _currentTimeMs) {
        note.isHit = false;
      }
    }
    notifyListeners();
  }

  void setSpeed(double speed) {
    _playbackSpeed = speed.clamp(0.25, 2.0);
    notifyListeners();
  }

  void setHand(HandTrack hand) {
    _practicingHand = hand;
    notifyListeners();
  }

  void toggleMute() {
    audioService.isMuted = !audioService.isMuted;
    notifyListeners();
  }

  void setLeadTime(int ms) {
    _leadTimeMs = ms.clamp(1000, 5000);
    notifyListeners();
  }

  void setNoteColorTheme(NoteColorTheme theme) {
    if (_noteColorTheme == theme) return;
    _noteColorTheme = theme;
    notifyListeners();
    visualizerTicker.value++;
  }

  void setKeyLabelMode(KeyLabelMode mode) {
    if (_keyLabelMode == mode) return;
    _keyLabelMode = mode;
    notifyListeners();
    visualizerTicker.value++;
  }

  void setShowFlyingStickLabels(bool show) {
    if (_showFlyingStickLabels == show) return;
    _showFlyingStickLabels = show;
    notifyListeners();
    visualizerTicker.value++;
  }

  void setShowLiveChord(bool show) {
    if (_showLiveChord == show) return;
    _showLiveChord = show;
    notifyListeners();
    visualizerTicker.value++;
  }

  /// 60 FPS animation ticker callback (High Performance: ZERO widget rebuilds)
  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final deltaSeconds = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    // --- Mode 1: Free Play Mode ---
    if (_mode == PlayMode.freePlay) {
      _freePlayTimeMs += deltaSeconds * 1000.0;

      // Auto-fix: Ensure any orphaned free play notes whose key is no longer held are closed!
      for (final n in _freePlayNotes) {
        if (n.isHeld && !_userHeldNotes.containsKey(n.pitch)) {
          n.endMs = _freePlayTimeMs;
        }
      }

      // Clean up notes that have flown off the top of the screen
      final cutoff = _freePlayTimeMs - (_leadTimeMs * 1.5);
      _freePlayNotes.removeWhere((n) => !n.isHeld && (n.endMs ?? 0) < cutoff);

      // Notify ONLY the visualizer canvas (0 widget rebuilds!)
      visualizerTicker.value++;
      return;
    }

    // --- Mode 2 & 3: Song Playback (Listen or Practice) ---
    if (!_isPlaying || _currentSong == null) return;

    final advanceMs = deltaSeconds * 1000.0 * _playbackSpeed;

    if (_mode == PlayMode.practice) {
      final requiredUnhitNotes = _getPendingPracticeNotes(_currentTimeMs.round());

      if (requiredUnhitNotes.isNotEmpty) {
        bool allPressed = true;
        for (final req in requiredUnhitNotes) {
          if (!_userHeldNotes.containsKey(req.pitch)) {
            allPressed = false;
            break;
          }
        }

        if (!allPressed) {
          visualizerTicker.value++;
          return;
        } else {
          for (final req in requiredUnhitNotes) {
            if (!req.isHit) {
              req.isHit = true;
              _notesHit++;
            }
          }
        }
      }
    }

    _currentTimeMs += advanceMs;

    if (_currentTimeMs >= _currentSong!.durationMs) {
      _currentTimeMs = _currentSong!.durationMs.toDouble();
      pause();
      return;
    }

    _updateSongActiveNotes();

    // Trigger visualizer canvas paint without rebuilding UI buttons/dropdowns!
    visualizerTicker.value++;
  }

  List<MidiNote> _getPendingPracticeNotes(int nowMs) {
    if (_currentSong == null) return [];

    return _currentSong!.notes.where((note) {
      if (_practicingHand != HandTrack.both && note.hand != _practicingHand) {
        return false;
      }
      final isAtStrikeLine = nowMs >= note.startTimeMs && nowMs <= note.startTimeMs + 180;
      return isAtStrikeLine && !note.isHit;
    }).toList();
  }

  void _updateSongActiveNotes() {
    if (_currentSong == null) return;
    final now = _currentTimeMs.round();

    _songActiveNotes.clear();
    for (final note in _currentSong!.notes) {
      if (note.isActiveAt(now)) {
        _songActiveNotes[note.pitch] = note;

        if (_mode == PlayMode.listen && (now - note.startTimeMs).abs() < 25) {
          audioService.playNote(note.pitch, velocity: note.velocity);
        }
      }
    }
  }

  /// Panic / Reset all held notes and stuck FreePlay sticks
  void clearAllHeldNotes() {
    final now = _freePlayTimeMs;
    for (final note in _freePlayNotes) {
      if (note.isHeld) {
        note.endMs = now;
      }
    }
    _heldFreePlayNotes.clear();
    _userHeldNotes.clear();
    _songActiveNotes.clear();
    notifyListeners();
    visualizerTicker.value++;
  }

  /// Clear a specific stuck note by pitch
  void clearHeldNote(int pitch) {
    _userHeldNotes.remove(pitch);
    final held = _heldFreePlayNotes.remove(pitch);
    if (held != null && held.isHeld) {
      held.endMs = _freePlayTimeMs;
    }
    for (final note in _freePlayNotes) {
      if (note.pitch == pitch && note.isHeld) {
        note.endMs = _freePlayTimeMs;
      }
    }
    notifyListeners();
    visualizerTicker.value++;
  }

  void _handleLiveMidiEvent(LiveMidiEvent event) {
    if (event.type == MidiPacketType.noteOn) {
      // If note was already held, close any dangling stick first so it doesn't get orphaned
      final prevHeld = _heldFreePlayNotes.remove(event.pitch);
      if (prevHeld != null && prevHeld.isHeld) {
        prevHeld.endMs = _freePlayTimeMs;
      }
      for (final n in _freePlayNotes) {
        if (n.pitch == event.pitch && n.isHeld) {
          n.endMs = _freePlayTimeMs;
        }
      }

      _userHeldNotes[event.pitch] = event.velocity;
      audioService.playNote(event.pitch, velocity: event.velocity);

      if (_mode == PlayMode.freePlay) {
        final note = FreePlayNote(
          pitch: event.pitch,
          startMs: _freePlayTimeMs,
          velocity: event.velocity,
        );
        _freePlayNotes.add(note);
        _heldFreePlayNotes[event.pitch] = note;
      }

      if (_mode == PlayMode.practice && _currentSong != null) {
        final pending = _getPendingPracticeNotes(_currentTimeMs.round());
        for (final p in pending) {
          if (p.pitch == event.pitch && !p.isHit) {
            p.isHit = true;
            _notesHit++;
          }
        }
      }
    } else if (event.type == MidiPacketType.noteOff) {
      _userHeldNotes.remove(event.pitch);

      if (_mode == PlayMode.freePlay) {
        final note = _heldFreePlayNotes.remove(event.pitch);
        if (note != null) {
          note.endMs = _freePlayTimeMs;
        }
        for (final n in _freePlayNotes) {
          if (n.pitch == event.pitch && n.isHeld) {
            n.endMs = _freePlayTimeMs;
          }
        }
      }
    }

    notifyListeners();
  }

  void setVirtualKeyPressed(int pitch, bool isPressed, {int velocity = 100}) {
    final event = LiveMidiEvent(
      type: isPressed ? MidiPacketType.noteOn : MidiPacketType.noteOff,
      pitch: pitch,
      velocity: isPressed ? velocity : 0,
    );

    if (isPressed) {
      // If note is already stuck/held, clicking it directly releases and clears it!
      if (_userHeldNotes.containsKey(pitch)) {
        clearHeldNote(pitch);
        return;
      }
      _handleLiveMidiEvent(event);
    } else {
      _handleLiveMidiEvent(event);
      clearHeldNote(pitch);
    }
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _ticker?.dispose();
    _midiEventSubscription?.cancel();
    visualizerTicker.dispose();
    audioService.dispose();
    super.dispose();
  }
}
