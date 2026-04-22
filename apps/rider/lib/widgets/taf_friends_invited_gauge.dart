// Orbit layout matches the TAF marketing SVG (viewBox 360×300); centre count is Flutter text.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Orbit + centre hub matching the marketing SVG (360×300 viewBox), themed.
class TafFriendsInvitedGauge extends StatelessWidget {
  const TafFriendsInvitedGauge({
    super.key,
    required this.count,
    required this.loading,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final int count;
  final bool loading;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  /// Matches marketing SVG viewBox width / height.
  static const double vbW = 360;
  static const double vbH = 300;

  @override
  Widget build(BuildContext context) {
    const maxW = 300.0;
    const maxH = 240.0;
    final scale = math.min(maxW / vbW, maxH / vbH);
    final w = vbW * scale;
    final h = vbH * scale;

    return Semantics(
      label: '${l10n.tellAFriendFriendsInvitedLabel}: $count',
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(w, h),
              painter: _GaugeOrbitPainter(
                colors: colors,
                scale: scale,
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.tellAFriendFriendsInvitedLabel,
                        textAlign: TextAlign.center,
                        style: typo.labelMedium.copyWith(
                          color: colors.textMid,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (loading)
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.accent,
                          ),
                        )
                      else ...[
                        Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: typo.headingLarge.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 34,
                            height: 1.05,
                          ),
                        ),
                        if (count == 0) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              l10n.tellAFriendFriendsInvitedZeroHint,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: typo.bodySmall.copyWith(
                                color: colors.textSoft,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugeOrbitPainter extends CustomPainter {
  _GaugeOrbitPainter({
    required this.colors,
    required this.scale,
  });

  final HeyCabyColorTokens colors;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final ox = (size.width - TafFriendsInvitedGauge.vbW * scale) / 2;
    final oy = (size.height - TafFriendsInvitedGauge.vbH * scale) / 2;
    canvas.save();
    canvas.translate(ox, oy);
    canvas.scale(scale);

    const w = TafFriendsInvitedGauge.vbW;
    const h = TafFriendsInvitedGauge.vbH;
    final bg = Paint()
      ..shader = ui.Gradient.radial(
        Offset(w / 2, h / 2),
        w * 0.55,
        [
          colors.accentL.withValues(alpha: 0.85),
          colors.bg.withValues(alpha: 0.95),
        ],
        const [0.0, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bg);

    final c = Offset(w / 2, h / 2);

    final orbit = Paint()
      ..color = colors.border.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    _dashedCircle(canvas, c, 90, orbit, dash: 6, gap: 6);

    final nodePaint = Paint()..color = colors.accent;
    final nodes = <Offset>[
      const Offset(180, 60),
      const Offset(270, 120),
      const Offset(240, 220),
      const Offset(120, 220),
      const Offset(90, 120),
    ];
    for (final p in nodes) {
      canvas.drawCircle(p, 8, nodePaint);
    }

    final hubFill = Paint()..color = colors.card;
    final hubStroke = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, 50, hubFill);
    canvas.drawCircle(c, 50, hubStroke);

    final avatarFill = Paint()..color = colors.accentL.withValues(alpha: 0.75);
    final avatars = <Offset>[
      const Offset(180, 30),
      const Offset(300, 110),
      const Offset(250, 260),
      const Offset(110, 260),
      const Offset(60, 110),
    ];
    for (final p in avatars) {
      canvas.drawCircle(p, 18, avatarFill);
    }

    canvas.restore();
  }

  void _dashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final circumference = 2 * math.pi * radius;
    final step = dash + gap;
    var d = 0.0;
    while (d < circumference) {
      final startAngle = (d / circumference) * 2 * math.pi - math.pi / 2;
      final sweep = (dash / circumference) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      d += step;
    }
  }

  @override
  bool shouldRepaint(covariant _GaugeOrbitPainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.scale != scale;
  }
}
