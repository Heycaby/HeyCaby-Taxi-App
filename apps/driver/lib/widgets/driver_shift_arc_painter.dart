import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 8-hour shift arc (progress 0..1).
class DriverShiftArcPainter extends CustomPainter {
  DriverShiftArcPainter({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
  });

  final double progress;
  final Color accentColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 5;
    const stroke = 5.5;
    final rect = Rect.fromCircle(center: c, radius: r);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    const start = -math.pi / 2;
    canvas.drawArc(rect, start, math.pi * 2, false, track);
    canvas.drawArc(rect, start, math.pi * 2 * progress.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(covariant DriverShiftArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.trackColor != trackColor;
}
