import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controllers/practice_controller.dart';
import 'models/midi_note.dart';
import 'services/midi_parser.dart';
import 'widgets/piano_keyboard.dart';
import 'widgets/top_bar_controls.dart';
import 'widgets/waterfall_visualizer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PianoKustikApp());
}

class PianoKustikApp extends StatelessWidget {
  const PianoKustikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PianoKustik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030307),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFA855F7),
          secondary: Color(0xFFC084FC),
          surface: Color(0xFF0D0D14),
        ),
        fontFamily: 'sans-serif',
      ),
      home: const PianoScreen(),
    );
  }
}

typedef SynthesiaPianoApp = PianoKustikApp;

class PianoScreen extends StatefulWidget {
  const PianoScreen({super.key});

  @override
  State<PianoScreen> createState() => _PianoScreenState();
}

class _PianoScreenState extends State<PianoScreen> {
  late final PracticeController _controller;
  final FocusNode _keyboardFocusNode = FocusNode();

  // Mapping computer QWERTY keyboard to Middle C octave (notes 60 to 72)
  static final Map<LogicalKeyboardKey, int> _computerKeyMap = {
    LogicalKeyboardKey.keyA: 60, // C4
    LogicalKeyboardKey.keyW: 61, // C#4
    LogicalKeyboardKey.keyS: 62, // D4
    LogicalKeyboardKey.keyE: 63, // D#4
    LogicalKeyboardKey.keyD: 64, // E4
    LogicalKeyboardKey.keyF: 65, // F4
    LogicalKeyboardKey.keyT: 66, // F#4
    LogicalKeyboardKey.keyG: 67, // G4
    LogicalKeyboardKey.keyY: 68, // G#4
    LogicalKeyboardKey.keyH: 69, // A4
    LogicalKeyboardKey.keyU: 70, // A#4
    LogicalKeyboardKey.keyJ: 71, // B4
    LogicalKeyboardKey.keyK: 72, // C5
  };

  @override
  void initState() {
    super.initState();
    _controller = PracticeController();

    // Load initial demo song
    final demoSongs = MidiParser.getDemoSongs();
    if (demoSongs.isNotEmpty) {
      _controller.loadSong(demoSongs.first);
    }
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Spacebar toggles Play/Pause
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _controller.togglePlay();
        return;
      }
      // Esc pauses
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _controller.pause();
        return;
      }
      // Computer QWERTY keyboard mapping
      final pitch = _computerKeyMap[event.logicalKey];
      if (pitch != null && !_controller.userHeldNotes.containsKey(pitch)) {
        _controller.setVirtualKeyPressed(pitch, true);
      }
    } else if (event is KeyUpEvent) {
      final pitch = _computerKeyMap[event.logicalKey];
      if (pitch != null) {
        _controller.setVirtualKeyPressed(pitch, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF131211),
        body: Column(
          children: [
            // Top Controls Bar
            TopBarControls(controller: _controller),

            // Waterfall Visualizer Area
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: WaterfallVisualizer(controller: _controller),
                    ),
                  ),

                  // Mode Overlay Badge / Instruction
                  Positioned(
                    top: 14,
                    right: 18,
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) {
                        return _buildStatusOverlay(_controller);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Interactive 88-Key Piano Keyboard
            RepaintBoundary(
              child: PianoKeyboard(
                controller: _controller,
                height: 135.0,
              ),
            ),

            // Bottom Footer Info Bar
            _buildFooterBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverlay(PracticeController controller) {
    if (controller.mode == PlayMode.practice) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1815).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5C59E).withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, size: 16, color: Color(0xFFEADBC8)),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mode Latihan: Wait for Notes',
                  style: TextStyle(
                    color: Color(0xFFFAF6F0),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Tekan tuts yang menyala di piano Anda untuk melanjutkan lagu!',
                  style: TextStyle(color: Color(0xFFC8B8A6), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildFooterBar() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final heldNotes = _controller.userHeldNotes.keys.toList();
        final heldNames = heldNotes.map(MidiNote.pitchToNoteName).join(', ');

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF100F0E),
            border: Border(
              top: BorderSide(color: Color(0xFF221E1A), width: 1.0),
            ),
          ),
          width: double.infinity,
          child: Row(
            children: [
              // Active Keys Display (Clickable to reset stuck notes)
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: heldNotes.isEmpty ? null : () => _controller.clearAllHeldNotes(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note, size: 14, color: Color(0xFFC8B8A6)),
                    const SizedBox(width: 8),
                    Text(
                      heldNotes.isEmpty ? 'Tuts aktif: –' : 'Tuts aktif: $heldNames',
                      style: const TextStyle(
                        color: Color(0xFFC8B8A6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),
              const Text(
                '|',
                style: TextStyle(color: Color(0xFF383129), fontSize: 12),
              ),
              const SizedBox(width: 14),

              // Quick Hint for QWERTY Keys
              const Text(
                'Shortcut: Keyboard [A–K] = C4–C5   [Spasi] = Play/Pause',
                style: TextStyle(color: Color(0xFF7D7166), fontSize: 11),
              ),

              const Spacer(),

              // Accuracy in Practice Mode
              if (_controller.mode == PlayMode.practice) ...[
                Text(
                  'Hit: ${_controller.notesHit}',
                  style: const TextStyle(
                    color: Color(0xFFE5C59E),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 14),
              ],

              // Engine indicator
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5C59E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                '60 FPS Engine',
                style: TextStyle(color: Color(0xFFC8B8A6), fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}
