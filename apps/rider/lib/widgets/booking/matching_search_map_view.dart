import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A quiet, map-first locator that shows matching is active without obscuring
/// the route beneath it.
class MatchingSearchPulseOverlay extends StatelessWidget {
  const MatchingSearchPulseOverlay({
    super.key,
    required this.rippleControllers,
    required this.sweepController,
    required this.color,
    this.centerYFraction = 0.40,
  });

  final List<AnimationController> rippleControllers;
  final AnimationController sweepController;
  final Color color;
  final double centerYFraction;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return IgnorePointer(
      child: CustomPaint(
        painter: _MatchingSearchRadarPainter(
          rippleControllers: rippleControllers,
          sweepController: sweepController,
          color: color,
          centerYFraction: centerYFraction,
          reduceMotion: reduceMotion,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MatchingSearchRadarPainter extends CustomPainter {
  _MatchingSearchRadarPainter({
    required this.rippleControllers,
    required this.sweepController,
    required this.color,
    required this.centerYFraction,
    required this.reduceMotion,
  }) : super(
          repaint: Listenable.merge([
            ...rippleControllers,
            sweepController,
          ]),
        );

  final List<AnimationController> rippleControllers;
  final AnimationController sweepController;
  final Color color;
  final double centerYFraction;
  final bool reduceMotion;

  static const double _maxRadius = 92;
  static const double _coreRadius = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * centerYFraction);
    _drawRadarField(canvas, center);
    _drawGuideRings(canvas, center);
    if (!reduceMotion) {
      _drawRipples(canvas, center);
      _drawSweep(canvas, center);
    }
    _drawCoreBeacon(canvas, center);
  }

  void _drawRadarField(Canvas canvas, Offset center) {
    final field = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.08),
          color.withValues(alpha: 0.025),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: _maxRadius));
    canvas.drawCircle(center, _maxRadius, field);
  }

  void _drawGuideRings(Canvas canvas, Offset center) {
    for (final fraction in [0.58, 1.0]) {
      final ring = Paint()
        ..color = color.withValues(alpha: fraction == 1.0 ? 0.11 : 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(center, _maxRadius * fraction, ring);
    }
  }

  void _drawRipples(Canvas canvas, Offset center) {
    for (final controller in rippleControllers) {
      final t = Curves.easeOutCubic.transform(controller.value);
      final radius = _coreRadius + 6 + (t * (_maxRadius - _coreRadius - 6));
      final alpha = (1 - t) * 0.22;
      if (alpha <= 0.01) continue;

      final ring = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 - (t * 0.5);
      canvas.drawCircle(center, radius, ring);
    }
  }

  void _drawSweep(Canvas canvas, Offset center) {
    final angle = sweepController.value * math.pi * 2;
    final orbit = Rect.fromCircle(center: center, radius: _maxRadius * 0.78);
    final arc = Paint()
      ..color = color.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(orbit, angle, math.pi * 0.34, false, arc);
  }

  void _drawCoreBeacon(Canvas canvas, Offset center) {
    // Breathing outer halo tied to sweep phase.
    final breathe = 0.5 + 0.5 * math.sin(sweepController.value * math.pi * 2);
    final phase = reduceMotion ? 0.0 : breathe;
    final halo = Paint()..color = color.withValues(alpha: 0.08 + phase * 0.06);
    canvas.drawCircle(center, _coreRadius + 9 + phase * 3, halo);

    final coreFill = Paint()..color = color.withValues(alpha: 0.16);
    canvas.drawCircle(center, _coreRadius + 6, coreFill);

    final midRing = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, _coreRadius + 3, midRing);

    final core = Paint()..color = color;
    canvas.drawCircle(center, _coreRadius, core);

    final highlight = Paint()..color = Colors.white;
    canvas.drawCircle(center, 2.3, highlight);
  }

  @override
  bool shouldRepaint(covariant _MatchingSearchRadarPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.centerYFraction != centerYFraction ||
      oldDelegate.reduceMotion != reduceMotion;
}
