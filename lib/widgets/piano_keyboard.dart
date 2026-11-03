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

  static const double goldRailHeight = 5.0;
  static const double frontLipHeight = 6.0;

  // Pre-allocated static paints
  static final Paint _whiteGapPaint = Paint()
    ..color = const Color(0xFF28231E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static final Paint _blackDropShadowPaint = Paint()
    ..color = const Color(0x88000000);

  static final Paint _blackBorderPaint = Paint()
    ..color = const Color(0xFF141210)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static final Paint _filamentPaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 1.2;

  static final Paint _creasePaint = Paint()
    ..color = const Color(0xFF1E1A16)
    ..strokeWidth = 0.8;

  // Cached shaders and gradient paints (reused across all 88 keys with 0 allocations)
  static double _cachedTotalHeight = 0.0;
  static double _cachedTotalWidth = 0.0;
  static NoteColorTheme? _cachedTheme;

  static late Paint _cachedIvoryPaint;
  static late Paint _cachedLipPaint;
  static late Paint _cachedEbonyPaint;
  static late Paint _cachedSlopePaint;
  static late Paint _cachedRidgePaint;
  static late Paint _cachedRailPaint;
  static late Paint _cachedTopGlowPaint;
  static late Paint _cachedGlowDownPaint;
  static late Paint _activeTrebleWhitePaint;
  static late Paint _activeBassWhitePaint;
  static late Paint _activeTrebleBlackPaint;
  static late Paint _activeBassBlackPaint;

  static void _ensurePaintsInitialized(double totalWidth, double totalHeight, NoteColorTheme theme) {
    if (_cachedTotalHeight == totalHeight &&
        _cachedTotalWidth == totalWidth &&
        _cachedTheme == theme) {
      return;
    }
    _cachedTotalHeight = totalHeight;
    _cachedTotalWidth = totalWidth;
    _cachedTheme = theme;

    final keyHeight = totalHeight - goldRailHeight;
    final surfaceHeight = keyHeight - frontLipHeight;
    final keyLength = keyHeight * 0.64;

    _cachedIvoryPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFECE6DC),
          Color(0xFFFAF7F2),
          Color(0xFFF3ECE2),
          Color(0xFFE5DDD2),
        ],
        stops: const [0.0, 0.15, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, goldRailHeight, 1, surfaceHeight));

    _cachedLipPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFD8D0C4),
          Color(0xFFEAE3D8),
          Color(0xFFC8BFB2),
        ],
      ).createShader(Rect.fromLTWH(0, totalHeight - frontLipHeight, 1, frontLipHeight));

    _cachedEbonyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF38332C),
          Color(0xFF26221D),
          Color(0xFF191714),
          Color(0xFF100F0D),
        ],
        stops: [0.0, 0.15, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, goldRailHeight, 1, keyLength));

    _cachedSlopePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF38322A), Color(0xFF181512)],
      ).createShader(const Rect.fromLTWH(0, 0, 1, 6.0));

    _cachedRidgePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0x33FFFFFF),
          Colors.transparent,
          Color(0x22FFFFFF),
        ],
      ).createShader(const Rect.fromLTWH(0, 0, 10.0, 1.0));

    _cachedTopGlowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [theme.glow.withAlpha(89), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, totalWidth, 6.0));

    _cachedRailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          theme.primaryHighlight.withAlpha(204),
          theme.railCore,
          theme.railBevel,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, totalWidth, goldRailHeight));

    _cachedGlowDownPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.glow.withAlpha(89), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, goldRailHeight, totalWidth, 4.0));

    _activeTrebleWhitePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, theme.primaryHighlight, theme.primary],
        stops: const [0.0, 0.25, 1.0],
      ).createShader(Rect.fromLTWH(0, goldRailHeight, 1, surfaceHeight));

    _activeBassWhitePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, theme.primaryHighlight, theme.secondary],
        stops: const [0.0, 0.25, 1.0],
      ).createShader(Rect.fromLTWH(0, goldRailHeight, 1, surfaceHeight));

    _activeTrebleBlackPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.primaryHighlight, theme.primary],
      ).createShader(Rect.fromLTWH(0, goldRailHeight, 1, keyLength));

    _activeBassBlackPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.secondary, theme.primary],
      ).createShader(Rect.fromLTWH(0, goldRailHeight, 1, keyLength));
  }

  _PhotorealisticPianoPainter({
    required this.controller,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalWidth = size.width;
    final totalHeight = size.height;

    _ensurePaintsInitialized(totalWidth, totalHeight, controller.noteColorTheme);

    // 1. Draw Spotlight Beams shining down from active notes
    _drawSpotlightBeams(canvas, totalWidth, totalHeight);

    // 2. Draw all White Keys
    for (final key in PianoGeometry.allKeys) {
      if (!key.isBlack) {
        _drawRealisticWhiteKey(canvas, key, totalWidth, totalHeight);
      }
    }

    // 3. Draw all Black Keys
    for (final key in PianoGeometry.allKeys) {
      if (key.isBlack) {
        _drawRealisticBlackKey(canvas, key, totalWidth, totalHeight);
      }
    }

    // 4. Draw the Luminous Light Rail at the top
    _drawLightRail(canvas, totalWidth);
  }

  void _drawLightRail(Canvas canvas, double totalWidth) {
    // 1. Ambient warm upward light spill
    final topGlowRect = Rect.fromLTWH(0, 0, totalWidth, 6.0);
    canvas.drawRect(topGlowRect, _cachedTopGlowPaint);

    // 2. Base brass/bronze rail bevel
    final railRect = Rect.fromLTWH(0, 0, totalWidth, goldRailHeight);
    canvas.drawRect(railRect, _cachedRailPaint);

    // 3. Super bright specular filament line
    canvas.drawLine(const Offset(0, 2.2), Offset(totalWidth, 2.2), _filamentPaint);

    // 4. Ambient glow cast downwards
    final shadowRect = Rect.fromLTWH(0, goldRailHeight, totalWidth, 4.0);
    canvas.drawRect(shadowRect, _cachedGlowDownPaint);

    // 5. Crease line directly under the rail
    canvas.drawLine(const Offset(0, goldRailHeight), Offset(totalWidth, goldRailHeight), _creasePaint);
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
            beamColor.withAlpha(128),
            beamColor.withAlpha(38),
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

    final keyTop = goldRailHeight;
    final keyBottom = totalHeight;
    final keyHeight = keyBottom - keyTop;
    final pressOffset = isPressed ? 2.0 : 0.0;

    final surfaceRect = Rect.fromLTWH(
      left,
      keyTop + pressOffset,
      keyWidth,
      keyHeight - frontLipHeight - pressOffset,
    );

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
      canvas.drawRRect(rrect, isBass ? _activeBassWhitePaint : _activeTrebleWhitePaint);
    } else {
      canvas.drawRect(surfaceRect, _cachedIvoryPaint);

      final lipRRect = RRect.fromRectAndCorners(
        lipRect,
        bottomLeft: const Radius.circular(2.5),
        bottomRight: const Radius.circular(2.5),
      );
      canvas.drawRRect(lipRRect, _cachedLipPaint);
    }

    // Crisp gap divider line
    canvas.drawLine(
      Offset(right, keyTop + pressOffset),
      Offset(right, keyBottom),
      _whiteGapPaint,
    );

    // Key Labels
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

    // 1. Cast shadow
    final shadowRRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(left + 2.5, keyTop + pressOffset + 2.0, keyWidth + 1.0, keyLength + 3.0),
      bottomLeft: const Radius.circular(2.5),
      bottomRight: const Radius.circular(2.5),
    );
    canvas.drawRRect(shadowRRect, _blackDropShadowPaint);

    // 2. Black Key Body
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
      canvas.drawRRect(bodyRRect, isBass ? _activeBassBlackPaint : _activeTrebleBlackPaint);
    } else {
      canvas.drawRRect(bodyRRect, _cachedEbonyPaint);

      final ridgeRect = Rect.fromLTWH(left + 1.2, keyTop + pressOffset + 1.0, keyWidth - 2.4, keyLength * 0.88);
      canvas.drawRRect(RRect.fromRectAndRadius(ridgeRect, const Radius.circular(1.0)), _cachedRidgePaint);

      final frontSlope = Rect.fromLTWH(left + 0.8, keyTop + pressOffset + keyLength - 7.0, keyWidth - 1.6, 6.0);
      canvas.drawRRect(RRect.fromRectAndRadius(frontSlope, const Radius.circular(1.5)), _cachedSlopePaint);
    }

    // Labels
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
  bool shouldRepaint(covariant _PhotorealisticPianoPainter oldDelegate) {
    if (oldDelegate.controller.noteColorTheme != controller.noteColorTheme ||
        oldDelegate.controller.keyLabelMode != controller.keyLabelMode) {
      return true;
    }
    final oldHeld = oldDelegate.controller.userHeldNotes;
    final newHeld = controller.userHeldNotes;
    if (oldHeld.length != newHeld.length) return true;
    for (final k in newHeld.keys) {
      if (!oldHeld.containsKey(k)) return true;
    }
    final oldSong = oldDelegate.controller.songActiveNotes;
    final newSong = controller.songActiveNotes;
    if (oldSong.length != newSong.length) return true;
    for (final k in newSong.keys) {
      if (!oldSong.containsKey(k)) return true;
    }
    return false;
  }
}
