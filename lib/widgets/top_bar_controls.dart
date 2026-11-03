import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../controllers/practice_controller.dart';
import '../models/chord_detector.dart';
import '../models/midi_song.dart';
import '../services/midi_parser.dart';
import 'midi_device_dialog.dart';

class TopBarControls extends StatefulWidget {
  final PracticeController controller;

  const TopBarControls({super.key, required this.controller});

  @override
  State<TopBarControls> createState() => _TopBarControlsState();
}

class _TopBarControlsState extends State<TopBarControls> {
  PracticeController get controller => widget.controller;

  Future<void> _pickMidiFile(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mid', 'midi'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final path = result.first.path!;
        final file = File(path);
        final bytes = await file.readAsBytes();
        final fileName = result.first.name.replaceAll(RegExp(r'\.midi?$'), '');
        final song = MidiParser.parseMidiBytes(bytes, title: fileName);
        controller.loadSong(song);
        if (controller.mode == PlayMode.freePlay) {
          controller.setMode(PlayMode.listen);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membaca file MIDI: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatTime(double ms) {
    final totalSec = (ms / 1000).floor();
    final min = (totalSec ~/ 60).toString().padLeft(2, '0');
    final sec = (totalSec % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _SettingsModal(
        controller: controller,
        onPickFile: () => _pickMidiFile(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isFreePlay = controller.mode == PlayMode.freePlay;
        final currentSong = controller.currentSong;
        final midiService = controller.midiService;
        final connectedDev = midiService.connectedDevice;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141312),
            border: Border(
              bottom: BorderSide(color: Color(0xFF28231E), width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main Top Bar Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  children: [
                    // --- Left: Brand Logo ---
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 4 vertical rounded bars
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildLogoBar(),
                            const SizedBox(width: 2.5),
                            _buildLogoBar(),
                            const SizedBox(width: 2.5),
                            _buildLogoBar(),
                            const SizedBox(width: 2.5),
                            _buildLogoBar(),
                          ],
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'PianoKustik',
                          style: TextStyle(
                            color: Color(0xFFEADBC8),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.5,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // --- Center: Mode Switcher & MIDI Pill ---
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mode Switcher Capsule
                        Container(
                          padding: const EdgeInsets.all(3.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1917),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF352F28)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildModePill(
                                mode: PlayMode.freePlay,
                                icon: Icons.play_arrow,
                                label: 'Free Play',
                                isSelected: controller.mode == PlayMode.freePlay,
                              ),
                              _buildModePill(
                                mode: PlayMode.listen,
                                icon: Icons.headphones_outlined,
                                label: 'Listen',
                                isSelected: controller.mode == PlayMode.listen,
                              ),
                              _buildModePill(
                                mode: PlayMode.practice,
                                icon: Icons.school_outlined,
                                label: 'Practice',
                                isSelected: controller.mode == PlayMode.practice,
                              ),
                            ],
                          ),
                        ),

                        // Vertical separator line
                        Container(
                          height: 20,
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: const Color(0xFF383129),
                        ),

                        // Piano MIDI Button Pill
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => MidiDeviceDialog.show(context, midiService),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF26221D),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: connectedDev != null
                                    ? const Color(0xFFE5C59E)
                                    : const Color(0xFF3E362E),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.piano,
                                  size: 15,
                                  color: Color(0xFFC8B8A6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  connectedDev != null ? connectedDev.name : 'Piano MIDI',
                                  style: const TextStyle(
                                    color: Color(0xFFC8B8A6),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // --- Right: Settings & Fullscreen ---
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCircleButton(
                          icon: Icons.settings,
                          tooltip: 'Pengaturan & Pilih Lagu',
                          onTap: () => _showSettingsDialog(context),
                        ),
                        const SizedBox(width: 10),
                        _buildCircleButton(
                          icon: Icons.fullscreen,
                          tooltip: 'Layar Penuh',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tekan F11 pada keyboard untuk Layar Penuh'),
                                duration: Duration(seconds: 2),
                                backgroundColor: Color(0xFF26221D),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Active glowing accent underline right below the Free Play mode (as seen in screenshot)
              if (controller.mode == PlayMode.freePlay)
                Center(
                  child: Container(
                    height: 2,
                    width: 72,
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDFB8),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x99FFDEB8),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),

              // Transport Row in Listen / Practice mode
              if (!isFreePlay) _buildTransportBar(context, currentSong),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogoBar() {
    return Container(
      width: 3.5,
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFFEADBC8),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildModePill({
    required PlayMode mode,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => controller.setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEADBC8) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF1E1A16) : const Color(0xFFC8B8A6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1E1A16) : const Color(0xFFC8B8A6),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF26221D),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3E362E)),
        ),
        child: Icon(
          icon,
          size: 16,
          color: const Color(0xFFC8B8A6),
        ),
      ),
    );
  }

  Widget _buildTransportBar(BuildContext context, MidiSong? currentSong) {
    final demoSongs = MidiParser.getDemoSongs();
    final maxDuration = currentSong?.durationMs.toDouble() ?? 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF191715),
        border: Border(
          top: BorderSide(color: Color(0xFF28231E), width: 0.8),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Play / Pause Button
            IconButton(
              icon: Icon(
                controller.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: const Color(0xFFEADBC8),
                size: 26,
              ),
              onPressed: () => controller.togglePlay(),
            ),

            // Replay
            IconButton(
              icon: const Icon(Icons.replay, color: Color(0xFFC8B8A6), size: 17),
              tooltip: 'Ulang dari awal',
              onPressed: () => controller.seekTo(0),
            ),
            const SizedBox(width: 4),

            // Time
            Text(
              '${_formatTime(controller.currentTimeMs)} / ${_formatTime(maxDuration)}',
              style: const TextStyle(
                color: Color(0xFFC8B8A6),
                fontSize: 11.5,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 14),

            // Scrub Slider
            SizedBox(
              width: 240,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                  activeTrackColor: const Color(0xFFEADBC8),
                  inactiveTrackColor: const Color(0xFF332D26),
                  thumbColor: const Color(0xFFFFF7ED),
                ),
                child: Slider(
                  value: controller.currentTimeMs.clamp(0.0, maxDuration),
                  max: maxDuration,
                  onChanged: (val) => controller.seekTo(val),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Quick Song Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF24201B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF383129)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currentSong?.id,
                  dropdownColor: const Color(0xFF1E1A16),
                  hint: const Text(
                    'Pilih Lagu',
                    style: TextStyle(color: Color(0xFFC8B8A6), fontSize: 11),
                  ),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFEADBC8), size: 18),
                  items: demoSongs.map((song) {
                    return DropdownMenuItem<String>(
                      value: song.id,
                      child: Text(
                        '${song.title} (${song.composer})',
                        style: const TextStyle(color: Color(0xFFFAF6F0), fontSize: 11.5),
                      ),
                    );
                  }).toList(),
                  onChanged: (songId) {
                    if (songId != null) {
                      final selected = demoSongs.firstWhere((s) => s.id == songId);
                      controller.loadSong(selected);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Open Custom MIDI file
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEADBC8),
                side: const BorderSide(color: Color(0xFF383129)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.folder_open, size: 13),
              label: const Text('Buka MIDI', style: TextStyle(fontSize: 11)),
              onPressed: () => _pickMidiFile(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings & Customization Modal in Obsidian Champagne Gold
class _SettingsModal extends StatefulWidget {
  final PracticeController controller;
  final VoidCallback onPickFile;

  const _SettingsModal({
    required this.controller,
    required this.onPickFile,
  });

  @override
  State<_SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<_SettingsModal> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    // Default to Free Play & Tampilan if in Free Play mode, otherwise Lagu & MIDI
    _selectedTab = widget.controller.mode == PlayMode.freePlay ? 0 : 1;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final demoSongs = MidiParser.getDemoSongs();

        return Dialog(
          backgroundColor: const Color(0xFF161514),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF352F28), width: 1),
          ),
          child: Container(
            width: 540,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Color(0xFFEADBC8), size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      'Pengaturan & Kustomisasi',
                      style: TextStyle(
                        color: Color(0xFFEADBC8),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Segmented Tab Switcher
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF221E1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF332D26)),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          title: 'Tampilan & Free Play',
                          icon: Icons.palette_outlined,
                          isSelected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildTabButton(
                          title: 'Pilihan Lagu & MIDI',
                          icon: Icons.queue_music_rounded,
                          isSelected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Scrollable Body
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.65,
                  ),
                  child: SingleChildScrollView(
                    child: _selectedTab == 0
                        ? _buildAppearanceTab(controller)
                        : _buildSongsTab(controller, demoSongs),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF383027) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFFFFDFB8) : Colors.white54,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFFDFB8) : Colors.white60,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceTab(PracticeController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Color Palette Themes
        const Text(
          'Warna Tema Stick & Rel Piano',
          style: TextStyle(
            color: Color(0xFFC8B8A6),
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pilih warna untuk balok nada stick terbang, tuts aktif, dan rel cahaya di atas piano.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final theme in NoteColorTheme.values)
              _buildThemeSwatchCard(
                theme: theme,
                isSelected: controller.noteColorTheme == theme,
                onTap: () => controller.setNoteColorTheme(theme),
              ),
          ],
        ),

        const Divider(color: Color(0xFF28231E), height: 26),

        // 2. Piano Key Labels
        const Text(
          'Notasi Label pada Tuts Piano',
          style: TextStyle(
            color: Color(0xFFC8B8A6),
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tampilkan not angka (1 2 3 4 5 6 7) atau nama nada (C D E F G A B) pada tuts putih & hitam.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final mode in KeyLabelMode.values)
              _buildLabelModeChip(
                label: mode.label,
                isSelected: controller.keyLabelMode == mode,
                onTap: () => controller.setKeyLabelMode(mode),
              ),
          ],
        ),

        const Divider(color: Color(0xFF28231E), height: 26),

        // 3. Flying Stick Labels Toggle
        _buildSwitchTile(
          title: 'Not Angka pada Stick Terbang',
          subtitle: 'Menampilkan angka notasi di dalam balok stick saat meluncur naik',
          value: controller.showFlyingStickLabels,
          onChanged: (val) => controller.setShowFlyingStickLabels(val),
        ),

        const SizedBox(height: 10),

        // 4. Live Chord Recognition Toggle
        _buildSwitchTile(
          title: 'Deteksi Akor Otomatis (Live Chord)',
          subtitle: 'Mendeteksi akor (misal C Maj 1-3-5, G7, Em) saat beberapa tuts ditekan',
          value: controller.showLiveChord,
          onChanged: (val) => controller.setShowLiveChord(val),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildThemeSwatchCard({
    required NoteColorTheme theme,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 152,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A231C) : const Color(0xFF1E1A16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.accentSwatch : const Color(0xFF332B22),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.accentSwatch.withAlpha(50),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [theme.primaryHighlight, theme.primary, theme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.glow.withAlpha(120),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                theme.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFFDFB8) : Colors.white70,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, size: 14, color: theme.accentSwatch),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelModeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3D3227) : const Color(0xFF201B17),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFE5C59E) : const Color(0xFF352B21),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFFEAD0) : Colors.white70,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF302820)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFEADBC8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFFEADBC8),
            activeTrackColor: const Color(0xFF6B4D2B),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: const Color(0xFF28231E),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSongsTab(PracticeController controller, List<MidiSong> demoSongs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lagu Contoh Klasik',
          style: TextStyle(color: Color(0xFFC8B8A6), fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final song in demoSongs)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            title: Text(
              song.title,
              style: TextStyle(
                color: controller.currentSong?.id == song.id
                    ? const Color(0xFFFFDFB8)
                    : Colors.white70,
                fontWeight: controller.currentSong?.id == song.id
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 12.5,
              ),
            ),
            subtitle: Text(
              '${song.composer} • ${song.notes.length} nada',
              style: const TextStyle(color: Colors.white38, fontSize: 10.5),
            ),
            trailing: controller.currentSong?.id == song.id
                ? const Icon(Icons.check, color: Color(0xFFEADBC8), size: 16)
                : null,
            onTap: () {
              controller.loadSong(song);
              Navigator.of(context).pop();
            },
          ),

        const SizedBox(height: 12),
        // Custom MIDI File
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A241E),
              foregroundColor: const Color(0xFFEADBC8),
              side: const BorderSide(color: Color(0xFF3F362C)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Buka File MIDI dari Komputer (.mid)'),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onPickFile();
            },
          ),
        ),

        const Divider(color: Color(0xFF2C2620), height: 24),

        // Playback Speed
        Row(
          children: [
            const Text(
              'Kecepatan Putar:',
              style: TextStyle(color: Color(0xFFC8B8A6), fontSize: 12),
            ),
            const Spacer(),
            for (final spd in [0.5, 0.75, 1.0, 1.25, 1.5])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => controller.setSpeed(spd),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: controller.playbackSpeed == spd
                          ? const Color(0xFFEADBC8)
                          : const Color(0xFF26211C),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${spd}x',
                      style: TextStyle(
                        color: controller.playbackSpeed == spd
                            ? const Color(0xFF1E1A16)
                            : const Color(0xFFC8B8A6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
