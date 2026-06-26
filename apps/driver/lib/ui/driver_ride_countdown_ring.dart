import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion.dart';
import '../theme/driver_typography.dart';

/// Urgent countdown ring — Opportunity Screen and timed offers.
class DriverRideCountdownRing extends StatelessWidget {
  const DriverRideCountdownRing({
    super.key,
    required this.secondsRemaining,
    required this.totalSeconds,
    required this.colors,
    required this.typography,
    this.size = 120,
  });

  final int secondsRemaining;
  final int totalSeconds;
  final DriverColors colors;
  final DriverTypography typography;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0
        ? (secondsRemaining / totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final urgent = secondsRemaining <= 10;
    final ringColor = urgent ? colors.warning : colors.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              color: ringColor,
              backgroundColor: colors.border.withValues(alpha: 0.45),
            ),
          ),
          AnimatedSwitcher(
            duration: DriverMotion.fast,
            child: Text(
              '$secondsRemaining',
              key: ValueKey<int>(secondsRemaining),
              style: typography.displaySmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
