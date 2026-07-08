import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Premium radar pulse over the searching map (ripples + rotating sweep).
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
    return IgnorePointer(
      child: CustomPaint(
        painter: _MatchingSearchRadarPainter(
          rippleControllers: rippleControllers,
          sweepController: sweepController,
          color: color,
          centerYFraction: centerYFraction,
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

  static const double _maxRadius = 118;
  static const double _coreRadius = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * centerYFraction);
    _drawRadarField(canvas, center);
    _drawGuideRings(canvas, center);
    _drawCrosshairs(canvas, center, size);
    _drawRipples(canvas, center);
    _drawSweep(canvas, center);
    _drawCoreBeacon(canvas, center);
  }

  void _drawRadarField(Canvas canvas, Offset center) {
    final field = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.10),
          color.withValues(alpha: 0.04),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: _maxRadius));
    canvas.drawCircle(center, _maxRadius, field);
  }

  void _drawGuideRings(Canvas canvas, Offset center) {
    for (final fraction in [0.28, 0.52, 0.76, 1.0]) {
      final ring = Paint()
        ..color = color.withValues(alpha: fraction == 1.0 ? 0.14 : 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = fraction == 1.0 ? 1.4 : 1;
      canvas.drawCircle(center, _maxRadius * fraction, ring);
    }
  }

  void _drawCrosshairs(Canvas canvas, Offset center, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - _maxRadius, center.dy),
      Offset(center.dx + _maxRadius, center.dy),
      line,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - _maxRadius),
      Offset(center.dx, center.dy + _maxRadius),
      line,
    );
  }

  void _drawRipples(Canvas canvas, Offset center) {
    for (final controller in rippleControllers) {
      final t = Curves.easeOutCubic.transform(controller.value);
      final radius = _coreRadius + 6 + (t * (_maxRadius - _coreRadius - 6));
      final alpha = (1 - t) * 0.34;
      if (alpha <= 0.01) continue;

      final ring = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 - (t * 1.0);
      canvas.drawCircle(center, radius, ring);

      // Soft trailing halo on each ripple.
      final halo = Paint()
        ..color = color.withValues(alpha: alpha * 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      canvas.drawCircle(center, radius, halo);
    }
  }

  void _drawSweep(Canvas canvas, Offset center) {
    final angle = sweepController.value * math.pi * 2;
    const sweepWidth = math.pi / 3.2;

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: _maxRadius),
        angle - sweepWidth,
        sweepWidth,
        false,
      )
      ..close();

    final sweepPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1,
        colors: [
          color.withValues(alpha: 0.30),
          color.withValues(alpha: 0.12),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: _maxRadius));
    canvas.drawPath(path, sweepPaint);

    // Leading edge line.
    final edgeX = center.dx + _maxRadius * math.cos(angle);
    final edgeY = center.dy + _maxRadius * math.sin(angle);
    final edge = Paint()
      ..color = color.withValues(alpha: 0.42)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, Offset(edgeX, edgeY), edge);
  }

  void _drawCoreBeacon(Canvas canvas, Offset center) {
    // Breathing outer halo tied to sweep phase.
    final breathe = 0.5 + 0.5 * math.sin(sweepController.value * math.pi * 2);
    final halo = Paint()..color = color.withValues(alpha: 0.10 + breathe * 0.08);
    canvas.drawCircle(center, _coreRadius + 10 + breathe * 4, halo);

    final midRing = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, _coreRadius + 4, midRing);

    final coreFill = Paint()..color = color.withValues(alpha: 0.20);
    canvas.drawCircle(center, _coreRadius + 2, coreFill);

    final core = Paint()..color = color;
    canvas.drawCircle(center, _coreRadius, core);

    final highlight = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawCircle(
      center + const Offset(-2.5, -2.5),
      2.2,
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _MatchingSearchRadarPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.centerYFraction != centerYFraction;
}
