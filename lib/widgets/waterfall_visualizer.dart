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
          ..strokeWidth = 1.5;
}

class WaterfallVisualizer extends StatelessWidget {
  final PracticeController controller;

  const WaterfallVisualizer({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          // If visualizer is clicked while notes are held/stuck, clear them immediately!
          if (controller.userHeldNotes.isNotEmpty || controller.freePlayNotes.any((n) => n.isHeld)) {
            controller.clearAllHeldNotes();
          }
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: _ChampagneGoldWaterfallPainter(
            controller: controller,
            repaint: controller.visualizerTicker,
          ),
        ),
      ),
    );
  }
}

class _ChampagneGoldWaterfallPainter extends CustomPainter {
  final PracticeController controller;

  // --- Pre-allocated Static Paints (Zero per-frame allocations) ---
  // Background: Warm Obsidian Charcoal
  static final Paint _bgPaint = Paint()..color = const Color(0xFF131211);

  // Piano Key Vertical Guides (Very subtle warm gold hairline)
  static final Paint _laneGuidePaint = Paint()
    ..color = const Color(0x0EE8D7C3)
    ..strokeWidth = 0.8;

  static final Paint _octaveGuidePaint = Paint()
    ..color = const Color(0x1FE8D7C3)
    ..strokeWidth = 1.0;

  // Static Theme Paints mapped by NoteColorTheme
  static final Map<NoteColorTheme, _WaterfallThemePaints> _themePaintsMap = {
    for (final theme in NoteColorTheme.values)
      theme: _WaterfallThemePaints(theme: theme),
  };

  // Crystal Inner Gloss Reflection
  static final Paint _glossPaint = Paint()
    ..color = const Color(0x55FFFFFF) // Subtle specular glass highlight
    ..style = PaintingStyle.fill;

  // Strike line & Flare
  static final Paint _strikeLinePaint = Paint()
    ..color = const Color(0x88FFE6C4)
    ..strokeWidth = 1.2;

  // Stardust Particle Mist (Precomputed 120 points)
  static final Paint _particleGoldPaint = Paint()
    ..color = const Color(0x66FFE3BE)
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round;

  static final Paint _particleWhitePaint = Paint()
    ..color = const Color(0x88FFFFFF)
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;

  static final List<Offset> _stardustPoints = _initStardust();
  static final List<double> _stardustSpeeds = _initStardustSpeeds();

  static List<Offset> _initStardust() {
    final rng = Random(42);
    return List.generate(120, (_) => Offset(rng.nextDouble(), rng.nextDouble()));
  }

  static List<double> _initStardustSpeeds() {
    final rng = Random(42);
    return List.generate(120, (_) => 0.025 + rng.nextDouble() * 0.05);
  }

  _ChampagneGoldWaterfallPainter({
    required this.controller,
    required super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final t = controller.mode == PlayMode.freePlay
        ? controller.freePlayTimeMs / 1000.0
        : controller.currentTimeMs / 1000.0;

    // 1. Warm Obsidian Charcoal background
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), _bgPaint);

    // 2. Piano key vertical grid lines
    _drawLaneGuides(canvas, width, height);

    // 3. Stardust particle mist
    _drawStardust(canvas, width, height, t);

    // 5. Render notes
    if (controller.mode == PlayMode.freePlay) {
      _drawFreePlayNotes(canvas, width, height);
    } else {
      if (controller.currentSong != null) {
        _drawSongNotes(canvas, width, height);
      }
    }

    // 6. Strike line at the base
    final lineY = height - 1.0;
    canvas.drawLine(Offset(0, lineY), Offset(width, lineY), _strikeLinePaint);

    // 7. Glowing strike bursts on active keys (Synthesia sharp spiky sparks & radiant glow)
    _drawActiveStrikeGlows(canvas, width, height, t * 1000.0);

    // 8. Chord display at bottom-left above piano (Simple & semi-transparent)
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
    final goldPoints = <Offset>[];
    final whitePoints = <Offset>[];

    for (int i = 0; i < _stardustPoints.length; i++) {
      final base = _stardustPoints[i];
      final speed = _stardustSpeeds[i];
      // Float upward gently
      final curY = ((base.dy - (t * speed)) % 1.0) * height;
      final curX = base.dx * width;

      if (i % 3 == 0) {
        whitePoints.add(Offset(curX, curY));
      } else {
        goldPoints.add(Offset(curX, curY));
      }
    }

    canvas.drawPoints(PointMode.points, goldPoints, _particleGoldPaint);
    canvas.drawPoints(PointMode.points, whitePoints, _particleWhitePaint);
  }

  /// Synthesia Free Play: Notes fly UPWARDS as glowing pill sticks with selected theme color
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
      final bodyPaint = isBass
          ? (note.isHeld ? themePaints.bassActiveBody : themePaints.bassBody)
          : (note.isHeld ? themePaints.trebleActiveBody : themePaints.trebleBody);

      // 1. Draw glowing aura around the note
      final glowRect = Rect.fromCenter(
        center: rect.center,
        width: noteWidth + 10.0,
        height: renderedHeight + 8.0,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(glowRect, const Radius.circular(8.0)),
        note.isHeld ? themePaints.activeGlowAura : themePaints.glowAura,
      );

      // 2. Draw note pill body
      canvas.drawRRect(rrect, bodyPaint);

      // 3. Draw inner gloss reflection highlight
      final glossRect = Rect.fromLTWH(
        left + 1.0,
        yBottom - renderedHeight + 1.0,
        max(1.5, noteWidth * 0.35),
        renderedHeight - 2.0,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(glossRect, const Radius.circular(2.0)), _glossPaint);

      // 4. Draw crisp glowing border
      canvas.drawRRect(rrect, note.isHeld ? themePaints.activeBorder : themePaints.border);

      // 5. Draw flying stick label (Not Angka / Note Name inside the pill stick)
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

      // 1. Outer Glow Aura
      final glowRect = Rect.fromCenter(
        center: rect.center,
        width: noteWidth + 8.0,
        height: noteHeight + 6.0,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(glowRect, const Radius.circular(7.0)),
        isCurrentlyActive ? themePaints.activeGlowAura : themePaints.glowAura,
      );

      // 2. Note body
      canvas.drawRRect(rrect, bodyPaint);

      // 3. Inner gloss highlight
      final glossRect = Rect.fromLTWH(
        left + 1.0,
        topY + 1.0,
        max(1.5, noteWidth * 0.35),
        noteHeight - 2.0,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(glossRect, const Radius.circular(2.0)), _glossPaint);

      // 4. Glowing border
      canvas.drawRRect(rrect, isCurrentlyActive ? themePaints.activeBorder : themePaints.border);

      // 5. Draw stick label if enabled
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

  // --- Synthesia Glowing Strike Flare & Starburst ---
  static final Paint _burstBaseLinePaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round;

  static const List<double> _peakRelX = [
    -0.95, -0.80, -0.65, -0.49, -0.33, -0.17, 0.0, 0.17, 0.33, 0.49, 0.65, 0.80, 0.95
  ];

  static const List<double> _peakBaseH = [
    8.0, 16.0, 11.0, 20.0, 16.0, 25.0, 28.0, 24.0, 17.0, 21.0, 12.0, 17.0, 8.0
  ];

  static String? _lastChordText;
  static TextPainter? _cachedChordPainter;

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

  /// Synthesia Strike Flare: Sharp spiky sparks radiating upward with luminous bloom glow
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

    // 1. Soft Outward Radial Glow Aura (colored halo bloom)
    final auraRect = Rect.fromCenter(
      center: Offset(cx, baseY - 8.0),
      width: burstWidth * 2.2,
      height: 52.0,
    );
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          theme.glow.withValues(alpha: 0.60),
          theme.glow.withValues(alpha: 0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(auraRect);
    canvas.drawOval(auraRect, auraPaint);

    // 2. High-Intensity Core Bloom (brilliant white-hot center)
    final coreRect = Rect.fromCenter(
      center: Offset(cx, baseY - 4.0),
      width: burstWidth * 1.25,
      height: 26.0,
    );
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFFFF),
          theme.primaryHighlight.withValues(alpha: 0.85),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(coreRect);
    canvas.drawOval(coreRect, corePaint);

    // 3. Spiky Starburst Crown (sharp jagged sparks radiating upward - matching reference image)
    final path = Path();
    path.moveTo(cx - halfW, baseY);

    const peakCount = 13;
    for (int i = 0; i < peakCount; i++) {
      // Micro-shimmer oscillation for live electrical/spark feel
      final shimmer = sin((nowMs * 0.04) + (i * 1.6)) * 2.5;
      final peakH = max(5.0, _peakBaseH[i] + shimmer);
      final px = cx + (_peakRelX[i] * halfW);
      final py = baseY - peakH;

      // Valley between peaks
      if (i > 0) {
        final prevPx = cx + (_peakRelX[i - 1] * halfW);
        final vx = (prevPx + px) / 2.0;
        final vy = baseY - (2.0 + (i % 2 == 0 ? 2.0 : 0.0));
        path.lineTo(vx, vy);
      }
      path.lineTo(px, py);
    }
    path.lineTo(cx + halfW, baseY);
    path.close();

    // Fill crown with vertical gradient: white at base to theme highlight at tips
    final crownRect = Rect.fromLTWH(cx - halfW, baseY - 32.0, burstWidth, 32.0);
    final crownPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFFFFFF),
          theme.primaryHighlight,
          theme.primary.withValues(alpha: 0.9),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(crownRect);
    canvas.drawPath(path, crownPaint);

    // 4. Inner sharp needle sparks (core bright white needles)
    final innerPath = Path();
    innerPath.moveTo(cx - (halfW * 0.6), baseY);
    for (int i = 3; i <= 9; i++) {
      final shimmer = sin((nowMs * 0.04) + (i * 1.6)) * 2.0;
      final peakH = max(4.0, (_peakBaseH[i] * 0.72) + shimmer);
      final px = cx + (_peakRelX[i] * halfW * 0.85);
      final py = baseY - peakH;
      if (i > 3) {
        final prevPx = cx + (_peakRelX[i - 1] * halfW * 0.85);
        final vx = (prevPx + px) / 2.0;
        innerPath.lineTo(vx, baseY - 1.5);
      }
      innerPath.lineTo(px, py);
    }
    innerPath.lineTo(cx + (halfW * 0.6), baseY);
    innerPath.close();

    final innerPaint = Paint()
      ..color = const Color(0xF2FFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, innerPaint);

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

  /// Chord display at bottom-left above piano (Simple & semi-transparent as seen in reference image)
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
