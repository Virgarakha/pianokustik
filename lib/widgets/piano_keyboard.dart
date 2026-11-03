import 'package:flutter/material.dart';
import '../controllers/practice_controller.dart';
import '../models/chord_detector.dart';
import 'piano_geometry.dart';

class PianoKeyboard extends StatefulWidget {
  final PracticeController controller;
  final double height;

  const PianoKeyboard({
    super.key,
    required this.controller,
    this.height = 145.0,
  });

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  final Map<int, int> _pointerPitches = {};

  void _handlePointerDown(PointerDownEvent event, Size size) {
    final pitch = PianoGeometry.getPitchAt(event.localPosition, size.width, size.height);
    if (pitch != null) {
      // If note was stuck/already held, clicking it immediately clears it!
      if (widget.controller.userHeldNotes.containsKey(pitch)) {
        widget.controller.clearHeldNote(pitch);
        _pointerPitches.remove(event.pointer);
        return;
      }

      _pointerPitches[event.pointer] = pitch;
      widget.controller.setVirtualKeyPressed(pitch, true);
    }
  }

  void _handlePointerMove(PointerMoveEvent event, Size size) {
    final pitch = PianoGeometry.getPitchAt(event.localPosition, size.width, size.height);
    final oldPitch = _pointerPitches[event.pointer];
    if (pitch != oldPitch) {
      if (oldPitch != null) {
        widget.controller.setVirtualKeyPressed(oldPitch, false);
      }
      if (pitch != null) {
        _pointerPitches[event.pointer] = pitch;
        widget.controller.setVirtualKeyPressed(pitch, true);
      } else {
        _pointerPitches.remove(event.pointer);
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final oldPitch = _pointerPitches.remove(event.pointer);
    if (oldPitch != null) {
      widget.controller.setVirtualKeyPressed(oldPitch, false);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    final oldPitch = _pointerPitches.remove(event.pointer);
    if (oldPitch != null) {
      widget.controller.setVirtualKeyPressed(oldPitch, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, widget.height);

            return Listener(
              onPointerDown: (e) => _handlePointerDown(e, size),
              onPointerMove: (e) => _handlePointerMove(e, size),
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              child: CustomPaint(
                size: size,
                painter: _PhotorealisticPianoPainter(
                  controller: widget.controller,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PhotorealisticPianoPainter extends CustomPainter {
  final PracticeController controller;

  // Height of the luminous champagne gold rail at the top
  static const double goldRailHeight = 5.0;
  static const double frontLipHeight = 6.0;

  // Pre-allocated static paints (Zero per-frame allocations)
  static final Paint _whiteGapPaint = Paint()
    ..color = const Color(0xFF28231E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static final Paint _blackDropShadowPaint = Paint()
    ..color = const Color(0x88000000); // Realistic 3D cast shadow

  static final Paint _blackBorderPaint = Paint()
    ..color = const Color(0xFF141210)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  _PhotorealisticPianoPainter({
    required this.controller,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalWidth = size.width;
    final totalHeight = size.height;

    // 1. Draw Spotlight Beams shining down from active notes
    _drawSpotlightBeams(canvas, totalWidth, totalHeight);

    // 2. Draw all White Keys with realistic warm ivory gradients and 3D front lips
    for (final key in PianoGeometry.allKeys) {
      if (!key.isBlack) {
        _drawRealisticWhiteKey(canvas, key, totalWidth, totalHeight);
      }
    }

    // 3. Draw all Black Keys with 3D bevels, slopes, and drop shadows
    for (final key in PianoGeometry.allKeys) {
      if (key.isBlack) {
        _drawRealisticBlackKey(canvas, key, totalWidth, totalHeight);
      }
    }

    // 4. Draw the Luminous Light Rail at the top
    _drawLightRail(canvas, totalWidth);
  }

  /// Luminous Light Rail running above the keys, styled with the active color theme
  void _drawLightRail(Canvas canvas, double totalWidth) {
    final theme = controller.noteColorTheme;

    // 1. Ambient warm upward light spill into waterfall
    final topGlowRect = Rect.fromLTWH(0, 0, totalWidth, 6.0);
    final topGlowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [theme.glow.withValues(alpha: 0.35), Colors.transparent],
      ).createShader(topGlowRect);
    canvas.drawRect(topGlowRect, topGlowPaint);

    // 2. Base brass/bronze rail bevel
    final railRect = Rect.fromLTWH(0, 0, totalWidth, goldRailHeight);
    final railPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          theme.primaryHighlight.withValues(alpha: 0.8),
          theme.railCore,
          theme.railBevel,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(railRect);
    canvas.drawRect(railRect, railPaint);

    // 3. Super bright specular neon filament line in the center
    final filamentPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(0, 2.2), Offset(totalWidth, 2.2), filamentPaint);

    // 4. Ambient glow cast downwards onto keys
    final shadowRect = Rect.fromLTWH(0, goldRailHeight, totalWidth, 4.0);
    final glowDownPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.glow.withValues(alpha: 0.35), Colors.transparent],
      ).createShader(shadowRect);
    canvas.drawRect(shadowRect, glowDownPaint);

    // 5. Crease line directly under the rail
    final creasePaint = Paint()
      ..color = const Color(0xFF1E1A16)
      ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(0, goldRailHeight), Offset(totalWidth, goldRailHeight), creasePaint);
  }

  void _drawSpotlightBeams(Canvas canvas, double totalWidth, double totalHeight) {
    final activePitches = <int>{
      ...controller.userHeldNotes.keys,
      ...controller.songActiveNotes.keys,
    };

    if (activePitches.isEmpty) return;
    final theme = controller.noteColorTheme;

    for (final pitch in activePitches) {
      final (left, right) = PianoGeometry.getHorizontalBounds(pitch, totalWidth);
      final isBass = pitch < 60;
      final beamColor = isBass ? theme.secondary : theme.primaryHighlight;

      final path = Path()
        ..moveTo(left - 2.0, goldRailHeight)
        ..lineTo(right + 2.0, goldRailHeight)
        ..lineTo(right + 8.0, totalHeight)
        ..lineTo(left - 8.0, totalHeight)
        ..close();

      final beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            beamColor.withValues(alpha: 0.50),
            beamColor.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(left - 8.0, goldRailHeight, (right - left) + 16.0, totalHeight));

      canvas.drawPath(path, beamPaint);
    }
  }

  void _drawRealisticWhiteKey(
    Canvas canvas,
    PianoKeyInfo key,
    double totalWidth,
    double totalHeight,
  ) {
    final (rawLeft, rawRight) = PianoGeometry.getHorizontalBounds(key.pitch, totalWidth);
    final left = rawLeft + 0.5;
    final right = rawRight - 0.5;
    final keyWidth = right - left;

    final isUserPressed = controller.userHeldNotes.containsKey(key.pitch);
    final isSongActive = controller.songActiveNotes.containsKey(key.pitch);
    final isPressed = isUserPressed || isSongActive;
    final isBass = key.pitch < 60;

    // A real white key starts right under the champagne gold rail
    final keyTop = goldRailHeight;
    final keyBottom = totalHeight;
    final keyHeight = keyBottom - keyTop;

    // When pressed, the key has a subtle 2px physical depression
    final pressOffset = isPressed ? 2.0 : 0.0;

    // Main surface rect
    final surfaceRect = Rect.fromLTWH(
      left,
      keyTop + pressOffset,
      keyWidth,
      keyHeight - frontLipHeight - pressOffset,
    );

    // Front 3D lip rect (the physical vertical block thickness of real piano keys)
    final lipRect = Rect.fromLTWH(
      left,
      keyBottom - frontLipHeight,
      keyWidth,
      frontLipHeight,
    );

    final rrect = RRect.fromRectAndCorners(
      Rect.fromLTWH(left, keyTop + pressOffset, keyWidth, keyHeight - pressOffset),
      bottomLeft: const Radius.circular(2.5),
      bottomRight: const Radius.circular(2.5),
    );

    if (isPressed) {
      // Active glowing key based on user chosen theme
      final theme = controller.noteColorTheme;
      final activeColor1 = theme.primaryHighlight;
      final activeColor2 = isBass ? theme.secondary : theme.primary;

      final activePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, activeColor1, activeColor2],
          stops: const [0.0, 0.25, 1.0],
        ).createShader(surfaceRect);
      canvas.drawRRect(rrect, activePaint);
    } else {
      // Photorealistic Warm Vintage Ivory White Key shading
      final ivoryPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFFECE6DC), // Soft ambient shadow under gold rail
            Color(0xFFFAF7F2), // Warm ivory sheen
            Color(0xFFF3ECE2), // Pure ivory middle
            Color(0xFFE5DDD2), // Slight shading towards bottom
          ],
          stops: const [0.0, 0.15, 0.85, 1.0],
        ).createShader(surfaceRect);
      canvas.drawRect(surfaceRect, ivoryPaint);

      // Draw the 3D Front Lip of the white key
      final lipPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD8D0C4), // Joint crease shadow
            Color(0xFFEAE3D8), // Front reflection
            Color(0xFFC8BFB2), // Bottom rounded edge
          ],
        ).createShader(lipRect);

      final lipRRect = RRect.fromRectAndCorners(
        lipRect,
        bottomLeft: const Radius.circular(2.5),
        bottomRight: const Radius.circular(2.5),
      );
      canvas.drawRRect(lipRRect, lipPaint);
    }

    // Crisp gap divider line between white keys
    canvas.drawLine(
      Offset(right, keyTop + pressOffset),
      Offset(right, keyBottom),
      _whiteGapPaint,
    );

    // Key Labels based on controller.keyLabelMode
    switch (controller.keyLabelMode) {
      case KeyLabelMode.notAngka:
        final tp = PianoGeometry.notAngkaTextPainters[key.pitch];
        if (tp != null) {
          final textOffset = Offset(
            left + (keyWidth - tp.width) / 2.0,
            keyBottom - frontLipHeight - tp.height - 3.0,
          );
          tp.paint(canvas, textOffset);
        }
        break;
      case KeyLabelMode.noteName:
        final tp = PianoGeometry.noteNameTextPainters[key.pitch];
        if (tp != null) {
          final textOffset = Offset(
            left + (keyWidth - tp.width) / 2.0,
            keyBottom - frontLipHeight - tp.height - 3.0,
          );
          tp.paint(canvas, textOffset);
        }
        break;
      case KeyLabelMode.octaveOnly:
        if (key.pitch % 12 == 0) {
          final tp = PianoGeometry.octaveTextPainters[key.pitch];
          if (tp != null) {
            final textOffset = Offset(
              left + (keyWidth - tp.width) / 2.0,
              keyBottom - frontLipHeight - tp.height - 3.0,
            );
            tp.paint(canvas, textOffset);
          }
        }
        break;
      case KeyLabelMode.none:
        break;
    }
  }

  void _drawRealisticBlackKey(
    Canvas canvas,
    PianoKeyInfo key,
    double totalWidth,
    double totalHeight,
  ) {
    final (rawLeft, rawRight) = PianoGeometry.getHorizontalBounds(key.pitch, totalWidth);
    final keyWidth = rawRight - rawLeft;
    final left = rawLeft;

    final isUserPressed = controller.userHeldNotes.containsKey(key.pitch);
    final isSongActive = controller.songActiveNotes.containsKey(key.pitch);
    final isPressed = isUserPressed || isSongActive;
    final isBass = key.pitch < 60;

    final keyTop = goldRailHeight;
    final keyLength = (totalHeight - goldRailHeight) * 0.64;
    final pressOffset = isPressed ? 1.5 : 0.0;

    // 1. Realistic 3D Cast Drop Shadow onto adjacent white keys
    final shadowRRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(left + 2.5, keyTop + pressOffset + 2.0, keyWidth + 1.0, keyLength + 3.0),
      bottomLeft: const Radius.circular(2.5),
      bottomRight: const Radius.circular(2.5),
    );
    canvas.drawRRect(shadowRRect, _blackDropShadowPaint);

    // 2. Black Key Body Rect
    final bodyRect = Rect.fromLTWH(
      left,
      keyTop + pressOffset,
      keyWidth,
      keyLength,
    );
    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      bottomLeft: const Radius.circular(2.0),
      bottomRight: const Radius.circular(2.0),
    );

    if (isPressed) {
      final theme = controller.noteColorTheme;
      final activeColor1 = isBass ? theme.secondary : theme.primaryHighlight;
      final activeColor2 = theme.primary;

      final activePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [activeColor1, activeColor2],
        ).createShader(bodyRect);
      canvas.drawRRect(bodyRRect, activePaint);
    } else {
      // 3. Realistic Matte Ebony Wood Texture with 3D Bevel
      final ebonyPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF38332C), // Top edge catch light
            Color(0xFF26221D), // Matte ebony upper body
            Color(0xFF191714), // Deep ebony lower body
            Color(0xFF100F0D), // Bottom tip
          ],
          stops: [0.0, 0.15, 0.8, 1.0],
        ).createShader(bodyRect);
      canvas.drawRRect(bodyRRect, ebonyPaint);

      // 4. Top Surface Bevel Highlight (the slight rounded ridge of real black keys)
      final ridgeRect = Rect.fromLTWH(left + 1.2, keyTop + pressOffset + 1.0, keyWidth - 2.4, keyLength * 0.88);
      final ridgePaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0x33FFFFFF), // Left specular edge
            Colors.transparent,
            Color(0x22FFFFFF), // Right specular edge
          ],
        ).createShader(ridgeRect);
      canvas.drawRRect(RRect.fromRectAndRadius(ridgeRect, const Radius.circular(1.0)), ridgePaint);

      // 5. Front Beveled Slope at the bottom of the black key
      final frontSlope = Rect.fromLTWH(left + 0.8, keyTop + pressOffset + keyLength - 7.0, keyWidth - 1.6, 6.0);
      final slopePaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF38322A), Color(0xFF181512)],
        ).createShader(frontSlope);
      canvas.drawRRect(RRect.fromRectAndRadius(frontSlope, const Radius.circular(1.5)), slopePaint);
    }

    // Labels on black keys if in notAngka or noteName mode
    if (controller.keyLabelMode == KeyLabelMode.notAngka) {
      final tp = PianoGeometry.notAngkaTextPainters[key.pitch];
      if (tp != null) {
        final textOffset = Offset(
          left + (keyWidth - tp.width) / 2.0,
          keyTop + pressOffset + keyLength - 18.0,
        );
        tp.paint(canvas, textOffset);
      }
    } else if (controller.keyLabelMode == KeyLabelMode.noteName) {
      final tp = PianoGeometry.noteNameTextPainters[key.pitch];
      if (tp != null) {
        final textOffset = Offset(
          left + (keyWidth - tp.width) / 2.0,
          keyTop + pressOffset + keyLength - 18.0,
        );
        tp.paint(canvas, textOffset);
      }
    }

    // Crisp outline
    canvas.drawRRect(bodyRRect, _blackBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _PhotorealisticPianoPainter oldDelegate) => true;
}
