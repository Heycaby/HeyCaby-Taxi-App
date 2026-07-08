import 'package:flutter/material.dart';

/// Solid silhouette of stacked banknotes — readable at small sizes.
class MoneySilhouetteIcon extends StatelessWidget {
  const MoneySilhouetteIcon({
    super.key,
    required this.color,
    this.size = 28,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MoneySilhouettePainter(color: color),
    );
  }
}

class _MoneySilhouettePainter extends CustomPainter {
  _MoneySilhouettePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    void drawBill({
      required double left,
      required double top,
      required double width,
      required double height,
      required double rotationDeg,
    }) {
      canvas.save();
      canvas.translate(left + width / 2, top + height / 2);
      canvas.rotate(rotationDeg * 3.14159265 / 180);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: width,
          height: height,
        ),
        Radius.circular(height * 0.14),
      );
      canvas.drawRRect(rect, paint);

      final notch = Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(-width * 0.18, 0),
        height * 0.11,
        notch,
      );
      canvas.drawCircle(
        Offset(width * 0.18, 0),
        height * 0.11,
        notch,
      );
      canvas.restore();
    }

    drawBill(
      left: w * 0.08,
      top: h * 0.18,
      width: w * 0.78,
      height: h * 0.42,
      rotationDeg: -10,
    );
    drawBill(
      left: w * 0.14,
      top: h * 0.34,
      width: w * 0.78,
      height: h * 0.42,
      rotationDeg: 6,
    );
  }

  @override
  bool shouldRepaint(covariant _MoneySilhouettePainter oldDelegate) =>
      oldDelegate.color != color;
}
