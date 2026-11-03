import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/practice_controller.dart';
import '../models/chord_detector.dart';
import 'piano_geometry.dart';

class _WaterfallThemePaints {
  final Paint trebleBody;
  final Paint trebleActiveBody;
  final Paint bassBody;
  final Paint bassActiveBody;
  final Paint glowAura;
  final Paint activeGlowAura;
  final Paint border;
  final Paint activeBorder;
  final Paint crownPaint;

  _WaterfallThemePaints({required NoteColorTheme theme})
      : trebleBody = Paint()
          ..color = theme.primary
          ..style = PaintingStyle.fill,
        trebleActiveBody = Paint()
          ..color = theme.primaryHighlight
          ..style = PaintingStyle.fill,
        bassBody = Paint()
          ..color = theme.secondary
          ..style = PaintingStyle.fill,
        bassActiveBody = Paint()
          ..color = theme.primaryHighlight
          ..style = PaintingStyle.fill,
        glowAura = Paint()
          ..color = theme.glow.withAlpha(55)
          ..style = PaintingStyle.fill,
        activeGlowAura = Paint()
          ..color = theme.glow.withAlpha(120)
          ..style = PaintingStyle.fill,
        border = Paint()
          ..color = theme.primaryHighlight.withAlpha(120)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
        activeBorder = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
        crownPaint = Paint()
          ..color = theme.primaryHighlight
          ..style = PaintingStyle.fill;
}

class WaterfallVisualizer extends StatefulWidget {
  final PracticeController controller;

  const WaterfallVisualizer({
    super.key,
    required this.controller,
  });

  @override
  State<WaterfallVisualizer> createState() => _WaterfallVisualizerState();
}

class _WaterfallVisualizerState extends State<WaterfallVisualizer>
    with SingleTickerProviderStateMixin {
  // Smooth native VSync anchor for Windows desktop (60Hz - 144Hz)
  late final AnimationController _vsyncController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _vsyncController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        if (widget.controller.userHeldNotes.isNotEmpty ||
            widget.controller.freePlayNotes.any((n) => n.isHeld)) {
          widget.controller.clearAllHeldNotes();
        }
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _ChampagneGoldWaterfallPainter(
          controller: widget.controller,
          repaint: Listenable.merge([widget.controller.visualizerTicker, _vsyncController]),
        ),
      ),
    );
  }
}

class _ChampagneGoldWaterfallPainter extends CustomPainter {
  final PracticeController controller;

  // --- Pre-allocated Static Paints (Zero per-frame allocations) ---
  static final Paint _bgPaint = Paint()..color = const Color(0xFF131211);

  static final Paint _laneGuidePaint = Paint()
    ..color = const Color(0x0EE8D7C3)
    ..strokeWidth = 0.8;

  static final Paint _octaveGuidePaint = Paint()
    ..color = const Color(0x1FE8D7C3)
    ..strokeWidth = 1.0;

  static final Map<NoteColorTheme, _WaterfallThemePaints> _themePaintsMap = {
    for (final theme in NoteColorTheme.values)
      theme: _WaterfallThemePaints(theme: theme),
  };

  static final Paint _strikeLinePaint = Paint()
    ..color = const Color(0x88FFE6C4)
    ..strokeWidth = 1.2;

  // Stardust Particle Mist (Fixed pre-allocated buffer: ZERO garbage collection)
  static final Paint _particleGoldPaint = Paint()
    ..color = const Color(0x66FFE3BE)
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round;

  static final Paint _particleWhitePaint = Paint()
    ..color = const Color(0x88FFFFFF)
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;

  static const int _particleCount = 48;
  static final List<Offset> _stardustBase = _initStardustBase();
  static final List<double> _stardustSpeeds = _initStardustSpeeds();
  static final List<Offset> _goldPoints = List.filled(32, Offset.zero);
  static final List<Offset> _whitePoints = List.filled(16, Offset.zero);

  static List<Offset> _initStardustBase() {
    final rng = Random(42);
    return List.generate(_particleCount, (_) => Offset(rng.nextDouble(), rng.nextDouble()));
  }

  static List<double> _initStardustSpeeds() {
    final rng = Random(42);
    return List.generate(_particleCount, (_) => 0.025 + rng.nextDouble() * 0.05);
  }

  // Reusable burst geometries (0 allocations per frame)
  static final Path _cachedCrownPath = Path();
  static final Path _cachedInnerPath = Path();
  static final Paint _burstBaseLinePaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round;

  static final Paint _burstAuraPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _burstCorePaint = Paint()
    ..color = const Color(0xDDFFFFFF)
    ..style = PaintingStyle.fill;

  static final Paint _burstInnerPaint = Paint()
    ..color = const Color(0xF2FFFFFF)
    ..style = PaintingStyle.fill;

  static const List<double> _peakRelX = [
    -0.95, -0.80, -0.65, -0.49, -0.33, -0.17, 0.0, 0.17, 0.33, 0.49, 0.65, 0.80, 0.95
  ];

  static const List<double> _peakBaseH = [
    8.0, 16.0, 11.0, 20.0, 16.0, 25.0, 28.0, 24.0, 17.0, 21.0, 12.0, 17.0, 8.0
  ];

  static String? _lastChordText;
  static TextPainter? _cachedChordPainter;

  _ChampagneGoldWaterfallPainter({
    required this.controller,
    required super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Hardware scissor clip (zero offscreen buffer overhead)
    canvas.clipRect(Offset.zero & size);

    final t = controller.mode == PlayMode.freePlay
        ? controller.freePlayTimeMs / 1000.0
        : controller.currentTimeMs / 1000.0;

    // 1. Warm Obsidian Charcoal background
    canvas.drawRect(Offset.zero & size, _bgPaint);

    // 2. Piano key vertical grid lines
    _drawLaneGuides(canvas, width, height);

    // 3. Stardust particle mist (zero allocation)
    _drawStardust(canvas, width, height, t);

    // 4. Render notes
    if (controller.mode == PlayMode.freePlay) {
      _drawFreePlayNotes(canvas, width, height);
    } else {
      if (controller.currentSong != null) {
        _drawSongNotes(canvas, width, height);
      }
    }

    // 5. Strike line at the base
    final lineY = height - 1.0;
    canvas.drawLine(Offset(0, lineY), Offset(width, lineY), _strikeLinePaint);

    // 6. Glowing strike bursts on active keys
    _drawActiveStrikeGlows(canvas, width, height, t * 1000.0);

    // 7. Chord display at bottom-left above piano (Simple & semi-transparent)
    if (controller.showLiveChord) {
      _drawBottomLeftChord(canvas, height);
    }
  }

  void _drawLaneGuides(Canvas canvas, double width, double height) {
    for (int i = 0; i <= PianoGeometry.totalWhiteKeys; i++) {
      final (x, _) = PianoGeometry.getHorizontalBounds(
        PianoGeometry.allKeys[min(i * 12 ~/ 7, PianoGeometry.allKeys.length - 1)].pitch,
        width,
      );
      canvas.drawLine(Offset(x, 0), Offset(x, height), _laneGuidePaint);
    }

    // Octave guide lines
    for (final key in PianoGeometry.allKeys) {
      if (key.pitch % 12 == 0 && !key.isBlack) {
        final (x, _) = PianoGeometry.getHorizontalBounds(key.pitch, width);
        canvas.drawLine(Offset(x, 0), Offset(x, height), _octaveGuidePaint);
      }
    }
  }

  void _drawStardust(Canvas canvas, double width, double height, double t) {
    int gIdx = 0;
    int wIdx = 0;

    for (int i = 0; i < _particleCount; i++) {
      final base = _stardustBase[i];
      final speed = _stardustSpeeds[i];
      final curY = ((base.dy - (t * speed)) % 1.0) * height;
      final curX = base.dx * width;

      if (i % 3 == 0) {
        if (wIdx < 16) {
          _whitePoints[wIdx++] = Offset(curX, curY);
        }
      } else {
        if (gIdx < 32) {
          _goldPoints[gIdx++] = Offset(curX, curY);
        }
      }
    }

    canvas.drawPoints(PointMode.points, _goldPoints, _particleGoldPaint);
    canvas.drawPoints(PointMode.points, _whitePoints, _particleWhitePaint);
  }

  /// Synthesia Free Play: Notes fly UPWARDS with selected theme color
  void _drawFreePlayNotes(Canvas canvas, double width, double height) {
    final nowMs = controller.freePlayTimeMs;
    final leadTimeMs = controller.leadTimeMs.toDouble();
    final themePaints = _themePaintsMap[controller.noteColorTheme] ?? _themePaintsMap[NoteColorTheme.gold]!;

    for (final note in controller.freePlayNotes) {
      final (rawLeft, rawRight) = PianoGeometry.getHorizontalBounds(note.pitch, width);
      final left = rawLeft + 1.0;
      final right = rawRight - 1.0;
      final noteWidth = max(3.0, right - left);

      final startAge = nowMs - note.startMs;
      final endAge = note.isHeld ? 0.0 : (nowMs - note.endMs!);

      final yBottom = height - (endAge / leadTimeMs * height);
      final yTop = height - (startAge / leadTimeMs * height);

      if (yBottom < 0 || yTop > height) continue;

      final renderedHeight = max(8.0, yBottom - yTop);
      final rect = Rect.fromLTWH(left, yBottom - renderedHeight, noteWidth, renderedHeight);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5.0));

      final isBass = note.pitch < 60;
      final isHeld = note.isHeld;
      final bodyPaint = isBass
          ? (isHeld ? themePaints.bassActiveBody : themePaints.bassBody)
          : (isHeld ? themePaints.trebleActiveBody : themePaints.trebleBody);

      // 1. Draw glowing aura ONLY for held/striking notes (saves 50% GPU fill-rate)
      if (isHeld) {
        final glowRect = Rect.fromCenter(
          center: rect.center,
          width: noteWidth + 10.0,
          height: renderedHeight + 8.0,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(glowRect, const Radius.circular(8.0)),
          themePaints.activeGlowAura,
        );
      }

      // 2. Draw note pill body
      canvas.drawRRect(rrect, bodyPaint);

      // 3. Draw crisp border
      canvas.drawRRect(rrect, isHeld ? themePaints.activeBorder : themePaints.border);

      // 4. Draw stick label if enabled
      if (controller.showFlyingStickLabels && renderedHeight >= 14.0) {
        final tp = controller.keyLabelMode == KeyLabelMode.noteName
            ? PianoGeometry.flyingStickNoteNamePainters[note.pitch]
            : PianoGeometry.flyingStickLabelPainters[note.pitch];
        if (tp != null && noteWidth >= (tp.width - 2)) {
          final labelY = (yBottom - renderedHeight + 2.0).clamp(2.0, height - tp.height - 2.0);
          final labelX = rect.center.dx - (tp.width / 2.0);
          tp.paint(canvas, Offset(labelX, labelY));
        }
      }
    }
  }

  /// Song Playback: Falling notes in chosen color theme
  void _drawSongNotes(Canvas canvas, double width, double height) {
    final currentMs = controller.currentTimeMs;
    final leadTimeMs = controller.leadTimeMs;
    final viewEndMs = (currentMs + leadTimeMs).round();
    final viewStartMs = (currentMs - 250).round();
    final themePaints = _themePaintsMap[controller.noteColorTheme] ?? _themePaintsMap[NoteColorTheme.gold]!;

    // Fast binary search windowing (finds visible slice in O(log N))
    final visibleNotes = controller.currentSong!.getNotesInWindow(viewStartMs, viewEndMs);

    for (final note in visibleNotes) {
      final (rawLeft, rawRight) = PianoGeometry.getHorizontalBounds(note.pitch, width);
      final left = rawLeft + 1.0;
      final right = rawRight - 1.0;
      final noteWidth = max(3.0, right - left);

      final bottomY = height - ((note.startTimeMs - currentMs) / leadTimeMs * height);
      final topY = height - ((note.endTimeMs - currentMs) / leadTimeMs * height);
      final noteHeight = max(8.0, bottomY - topY);

      final rect = Rect.fromLTWH(left, topY, noteWidth, noteHeight);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5.0));

      final isBass = note.pitch < 60;
      final isCurrentlyActive = note.isActiveAt(currentMs.round());

      final bodyPaint = isBass
          ? (isCurrentlyActive ? themePaints.bassActiveBody : themePaints.bassBody)
          : (isCurrentlyActive ? themePaints.trebleActiveBody : themePaints.trebleBody);

      // 1. Outer Glow Aura (only on active notes)
      if (isCurrentlyActive) {
        final glowRect = Rect.fromCenter(
          center: rect.center,
          width: noteWidth + 8.0,
          height: noteHeight + 6.0,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(glowRect, const Radius.circular(7.0)),
          themePaints.activeGlowAura,
        );
      }

      // 2. Note body
      canvas.drawRRect(rrect, bodyPaint);

      // 3. Glowing border
      canvas.drawRRect(rrect, isCurrentlyActive ? themePaints.activeBorder : themePaints.border);

      // 4. Draw stick label if enabled
      if (controller.showFlyingStickLabels && noteHeight >= 14.0) {
        final tp = controller.keyLabelMode == KeyLabelMode.noteName
            ? PianoGeometry.flyingStickNoteNamePainters[note.pitch]
            : PianoGeometry.flyingStickLabelPainters[note.pitch];
        if (tp != null && noteWidth >= (tp.width - 2)) {
          final labelY = (bottomY - tp.height - 2.0).clamp(2.0, height - tp.height - 2.0);
          final labelX = rect.center.dx - (tp.width / 2.0);
          tp.paint(canvas, Offset(labelX, labelY));
        }
      }
    }
  }

  /// Renders active glowing spark bursts directly over the strike line for all held/striking keys
  void _drawActiveStrikeGlows(Canvas canvas, double width, double height, double nowMs) {
    final activePitches = <int>{
      ...controller.userHeldNotes.keys,
    };

    if (controller.mode == PlayMode.freePlay) {
      for (final n in controller.freePlayNotes) {
        if (n.isHeld) activePitches.add(n.pitch);
      }
    } else if (controller.currentSong != null) {
      for (final p in controller.songActiveNotes.keys) {
        activePitches.add(p);
      }
    }

    if (activePitches.isEmpty) return;

    final theme = controller.noteColorTheme;

    for (final pitch in activePitches) {
      final (rawLeft, rawRight) = PianoGeometry.getHorizontalBounds(pitch, width);
      final cx = (rawLeft + rawRight) / 2.0;
      final kw = max(6.0, rawRight - rawLeft);

      _drawStrikeGlowBurst(canvas, cx, kw, height, theme, nowMs);
    }
  }

  /// Synthesia Strike Flare: Sharp spiky sparks radiating upward with zero shader allocation
  void _drawStrikeGlowBurst(
    Canvas canvas,
    double cx,
    double kw,
    double height,
    NoteColorTheme theme,
    double nowMs,
  ) {
    final burstWidth = max(kw * 1.45, 24.0);
    final halfW = burstWidth / 2.0;
    final baseY = height - 1.0;

    final themePaints = _themePaintsMap[theme] ?? _themePaintsMap[NoteColorTheme.gold]!;

    // 1. Soft Outward Glow Aura
    _burstAuraPaint.color = theme.glow.withAlpha(65);
    final auraRect = Rect.fromCenter(
      center: Offset(cx, baseY - 8.0),
      width: burstWidth * 2.0,
      height: 48.0,
    );
    canvas.drawOval(auraRect, _burstAuraPaint);

    // 2. High-Intensity Core Bloom
    final coreRect = Rect.fromCenter(
      center: Offset(cx, baseY - 4.0),
      width: burstWidth * 1.15,
      height: 24.0,
    );
    canvas.drawOval(coreRect, _burstCorePaint);

    // 3. Spiky Starburst Crown (reuse static Path)
    _cachedCrownPath.reset();
    _cachedCrownPath.moveTo(cx - halfW, baseY);

    const peakCount = 13;
    for (int i = 0; i < peakCount; i++) {
      final shimmer = sin((nowMs * 0.04) + (i * 1.6)) * 2.5;
      final peakH = max(5.0, _peakBaseH[i] + shimmer);
      final px = cx + (_peakRelX[i] * halfW);
      final py = baseY - peakH;

      if (i > 0) {
        final prevPx = cx + (_peakRelX[i - 1] * halfW);
        final vx = (prevPx + px) / 2.0;
        final vy = baseY - (2.0 + (i % 2 == 0 ? 2.0 : 0.0));
        _cachedCrownPath.lineTo(vx, vy);
      }
      _cachedCrownPath.lineTo(px, py);
    }
    _cachedCrownPath.lineTo(cx + halfW, baseY);
    _cachedCrownPath.close();

    canvas.drawPath(_cachedCrownPath, themePaints.crownPaint);

    // 4. Inner sharp needle sparks (core bright white needles)
    _cachedInnerPath.reset();
    _cachedInnerPath.moveTo(cx - (halfW * 0.6), baseY);
    for (int i = 3; i <= 9; i++) {
      final shimmer = sin((nowMs * 0.04) + (i * 1.6)) * 2.0;
      final peakH = max(4.0, (_peakBaseH[i] * 0.72) + shimmer);
      final px = cx + (_peakRelX[i] * halfW * 0.85);
      final py = baseY - peakH;
      if (i > 3) {
        final prevPx = cx + (_peakRelX[i - 1] * halfW * 0.85);
        final vx = (prevPx + px) / 2.0;
        _cachedInnerPath.lineTo(vx, baseY - 1.5);
      }
      _cachedInnerPath.lineTo(px, py);
    }
    _cachedInnerPath.lineTo(cx + (halfW * 0.6), baseY);
    _cachedInnerPath.close();

    canvas.drawPath(_cachedInnerPath, _burstInnerPaint);

    // 5. White-Hot Horizontal Baseline Flare (where key contacts strike line)
    final baseLineRect = Rect.fromCenter(
      center: Offset(cx, baseY),
      width: burstWidth * 0.95,
      height: 3.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseLineRect, const Radius.circular(2.0)),
      _burstBaseLinePaint,
    );
  }

  /// Chord display at bottom-left above piano (Simple & semi-transparent)
  void _drawBottomLeftChord(Canvas canvas, double height) {
    final chord = controller.currentDetectedChordSimple;
    if (chord == null || chord.isEmpty) {
      _lastChordText = null;
      _cachedChordPainter = null;
      return;
    }

    if (_lastChordText != chord || _cachedChordPainter == null) {
      _lastChordText = chord;
      _cachedChordPainter = TextPainter(
        text: TextSpan(
          text: chord,
          style: const TextStyle(
            color: Color(0x8CFFFFFF), // ~55% transparent white, simple & non-intrusive
            fontSize: 16.0,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.6,
            fontFamily: 'sans-serif',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    // Position at bottom-left, just above the strike line (matching reference image)
    const paddingLeft = 20.0;
    final yPos = height - _cachedChordPainter!.height - 12.0;
    _cachedChordPainter!.paint(canvas, Offset(paddingLeft, yPos));
  }

  @override
  bool shouldRepaint(covariant _ChampagneGoldWaterfallPainter oldDelegate) => true;
}
