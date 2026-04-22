import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Hero graphic for “Tell a friend” / TAF — local circle with people around a
/// network hub, sparkles, and dashed “invites” radiating outward.
class TafInviteIllustration extends StatelessWidget {
  const TafInviteIllustration({
    super.key,
    required this.accent,
    required this.muted,
    required this.nodeFill,
    this.size = 132,
  });

  final Color accent;
  final Color muted;
  final Color nodeFill;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _TafInvitePainter(
            accent: accent,
            muted: muted,
            nodeFill: nodeFill,
          ),
        ),
      ),
    );
  }
}

class _TafInvitePainter extends CustomPainter {
  _TafInvitePainter({
    required this.accent,
    required this.muted,
    required this.nodeFill,
  });

  final Color accent;
  final Color muted;
  final Color nodeFill;

  static const List<double> _avatarAngles = [
    -math.pi / 2,
    0,
    math.pi / 2,
    math.pi,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    final s = size.shortestSide;

    _drawNebula(canvas, c, r);
    _drawSparkles(canvas, c, r, s);
    _drawDashedConnectors(canvas, c, r, s);
    _drawCentralNetwork(canvas, c, r, s);
    for (var i = 0; i < 4; i++) {
      _drawAvatar(canvas, c, r, _avatarAngles[i], i, s);
    }
  }

  void _drawNebula(Canvas canvas, Offset c, double r) {
    final outer = Paint()
      ..shader = ui.Gradient.radial(
        c,
        r * 1.08,
        [
          Colors.white.withValues(alpha: 0.55),
          accent.withValues(alpha: 0.14),
          muted.withValues(alpha: 0.06),
          nodeFill.withValues(alpha: 0.02),
        ],
        const [0.0, 0.35, 0.72, 1.0],
      );
    canvas.drawCircle(c, r * 0.98, outer);

    final innerGlow = Paint()
      ..shader = ui.Gradient.radial(
        c,
        r * 0.55,
        [
          accent.withValues(alpha: 0.2),
          accent.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        const [0.0, 0.45, 1.0],
      );
    canvas.drawCircle(c, r * 0.52, innerGlow);
  }

  void _drawSparkles(Canvas canvas, Offset c, double r, double s) {
    final rnd = math.Random(42);
    final dot = Paint()..style = PaintingStyle.fill;
    const n = 22;
    for (var i = 0; i < n; i++) {
      final t = rnd.nextDouble() * 2 * math.pi;
      final dist = r * (0.15 + rnd.nextDouble() * 0.78);
      final p = Offset(c.dx + dist * math.cos(t), c.dy + dist * math.sin(t));
      if ((p - c).distance < r * 0.28) continue;
      final w = s * (0.006 + rnd.nextDouble() * 0.01);
      dot.color = Colors.white.withValues(alpha: 0.15 + rnd.nextDouble() * 0.45);
      canvas.drawCircle(p, w, dot);
      if (rnd.nextBool()) {
        dot.color = accent.withValues(alpha: 0.12 + rnd.nextDouble() * 0.28);
        canvas.drawCircle(p + Offset(w * 2.2, w), w * 0.55, dot);
      }
    }
  }

  void _drawDashedConnectors(Canvas canvas, Offset c, double r, double s) {
    final dash = math.max(2.5, s * 0.018);
    final gap = math.max(2.0, s * 0.014);
    final paint = Paint()
      ..color = muted.withValues(alpha: 0.38)
      ..strokeWidth = math.max(1.0, s * 0.01)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final a in _avatarAngles) {
      final inner = Offset(
        c.dx + r * 0.34 * math.cos(a),
        c.dy + r * 0.34 * math.sin(a),
      );
      final outer = Offset(
        c.dx + r * 0.58 * math.cos(a),
        c.dy + r * 0.58 * math.sin(a),
      );
      _dashedLine(canvas, inner, outer, paint, dash, gap);
    }
  }

  void _dashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint,
    double dashLen,
    double gapLen,
  ) {
    final v = p2 - p1;
    final len = v.distance;
    if (len < 0.001) return;
    final dir = v / len;
    var d = 0.0;
    while (d < len) {
      final start = p1 + dir * d;
      final end = p1 + dir * math.min(d + dashLen, len);
      canvas.drawLine(start, end, paint);
      d += dashLen + gapLen;
    }
  }

  void _drawCentralNetwork(Canvas canvas, Offset c, double r, double s) {
    final ringR = r * 0.42;
    final ringPaint = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, s * 0.016);

    canvas.drawCircle(c, ringR, ringPaint);

    const start = -math.pi / 2;
    final triR = r * 0.24;
    final nodes = List.generate(3, (i) {
      final a = start + i * 2 * math.pi / 3;
      return Offset(
        c.dx + triR * math.cos(a),
        c.dy + triR * math.sin(a),
      );
    });

    final mesh = Paint()
      ..color = muted.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.1, s * 0.012)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      canvas.drawLine(nodes[i], nodes[(i + 1) % 3], mesh);
    }

    final hubGlow = Paint()
      ..shader = ui.Gradient.radial(
        c,
        r * 0.16,
        [
          accent.withValues(alpha: 0.45),
          accent.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawCircle(c, r * 0.16, hubGlow);

    final nodeR = r * 0.065;
    final fill = Paint()..color = nodeFill;
    final ring = Paint()
      ..color = accent.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, s * 0.022);

    for (final p in nodes) {
      canvas.drawCircle(p, nodeR, fill);
      canvas.drawCircle(p, nodeR, ring);
    }

    final hubFill = Paint()..color = accent.withValues(alpha: 0.95);
    final hubR = r * 0.072;
    canvas.drawCircle(c, hubR, hubFill);
    canvas.drawCircle(
      c,
      hubR,
      Paint()
        ..color = nodeFill.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, s * 0.01),
    );

    final pulse = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.012);
    canvas.drawCircle(c, r * 0.31, pulse);
  }

  Color _skinTone(int variant) {
    const skins = [
      Color(0xFFF3D4C4),
      Color(0xFFD9A88C),
      Color(0xFFC6865A),
      Color(0xFFEAD6C8),
    ];
    return skins[variant % skins.length];
  }

  Color _hairColor(int variant) {
    const hairs = [
      Color(0xFF2C2420),
      Color(0xFF4A3728),
      Color(0xFF1A1512),
      Color(0xFF5C4033),
    ];
    return hairs[variant % hairs.length];
  }

  void _drawAvatar(
    Canvas canvas,
    Offset c,
    double r,
    double angle,
    int variant,
    double s,
  ) {
    final dist = r * 0.78;
    final ac = Offset(
      c.dx + dist * math.cos(angle),
      c.dy + dist * math.sin(angle),
    );
    final headR = r * 0.13;
    final skin = _skinTone(variant);
    final hair = _hairColor(variant);

    final shadow = Paint()
      ..color = muted.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: ac + Offset(0, headR * 0.35),
        width: headR * 2.1,
        height: headR * 0.55,
      ),
      shadow,
    );

    final face = Paint()..color = skin;
    canvas.drawCircle(ac, headR, face);

    final hairPaint = Paint()..color = hair;
    switch (variant) {
      case 0:
        canvas.drawArc(
          Rect.fromCircle(center: ac + Offset(0, -headR * 0.08), radius: headR * 1.05),
          math.pi * 1.05,
          math.pi * 0.9,
          true,
          hairPaint,
        );
        break;
      case 1:
        final path = Path()
          ..addOval(Rect.fromCenter(
            center: ac + Offset(headR * 0.15, -headR * 0.35),
            width: headR * 1.5,
            height: headR * 0.95,
          ));
        canvas.drawPath(path, hairPaint);
        break;
      case 2:
        canvas.drawArc(
          Rect.fromCircle(center: ac + Offset(0, -headR * 0.02), radius: headR * 1.12),
          math.pi * 1.0,
          math.pi * 1.0,
          true,
          hairPaint,
        );
        break;
      default:
        canvas.drawArc(
          Rect.fromCircle(center: ac + Offset(-headR * 0.1, -headR * 0.12), radius: headR * 1.08),
          math.pi * 1.15,
          math.pi * 0.75,
          true,
          hairPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(ac.dx - headR * 0.55, ac.dy - headR * 0.15, headR * 0.35, headR * 0.9),
          hairPaint,
        );
    }

    final eye = Paint()..color = muted.withValues(alpha: 0.55);
    final eyeY = ac.dy - headR * 0.08;
    canvas.drawCircle(Offset(ac.dx - headR * 0.28, eyeY), headR * 0.1, eye);
    canvas.drawCircle(Offset(ac.dx + headR * 0.28, eyeY), headR * 0.1, eye);

    final smile = Paint()
      ..color = muted.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.009)
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: ac + Offset(0, headR * 0.12), width: headR * 0.9, height: headR * 0.55),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      smile,
    );

    final cheek = Paint()..color = accent.withValues(alpha: 0.18);
    canvas.drawCircle(Offset(ac.dx - headR * 0.42, ac.dy + headR * 0.05), headR * 0.12, cheek);
    canvas.drawCircle(Offset(ac.dx + headR * 0.42, ac.dy + headR * 0.05), headR * 0.12, cheek);
  }

  @override
  bool shouldRepaint(covariant _TafInvitePainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.muted != muted ||
        oldDelegate.nodeFill != nodeFill;
  }
}
