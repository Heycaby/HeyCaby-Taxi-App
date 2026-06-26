import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// Shared premium styling for the Money Dashboard home sheet.
abstract final class DriverHomePremiumStyle {
  DriverHomePremiumStyle._();

  static const sheetTopGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF4FBF6),
      Color(0xFFFCFDFC),
      Color(0xFFFFFFFF),
    ],
    stops: [0.0, 0.35, 1.0],
  );

  static List<BoxShadow> heroGlow(DriverColors colors) => [
        BoxShadow(
          color: colors.primary.withValues(alpha: 0.14),
          blurRadius: 28,
          offset: const Offset(0, 10),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: colors.text.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> tileShadow(DriverColors colors, {Color? tint}) => [
        BoxShadow(
          color: (tint ?? colors.primary).withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 6),
          spreadRadius: -6,
        ),
        BoxShadow(
          color: colors.text.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static LinearGradient heroGradient(DriverColors colors) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.primary.withValues(alpha: 0.14),
          colors.card,
          colors.primary.withValues(alpha: 0.06),
        ],
        stops: const [0.0, 0.55, 1.0],
      );

  static LinearGradient earningsShader(DriverColors colors) => LinearGradient(
        colors: [
          colors.text,
          colors.primary.withValues(alpha: 0.85),
        ],
      );

  static LinearGradient iconOrbGradient(DriverColors colors) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.primary.withValues(alpha: 0.22),
          colors.primary.withValues(alpha: 0.08),
        ],
      );
}

/// Gradient icon orb for home quick-action tiles.
class DriverHomeIconOrb extends StatelessWidget {
  const DriverHomeIconOrb({
    super.key,
    required this.icon,
    required this.colors,
    this.size = 46,
    this.iconSize = 24,
  });

  final IconData icon;
  final DriverColors colors;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: DriverHomePremiumStyle.iconOrbGradient(colors),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: colors.primary, size: iconSize),
    );
  }
}

/// Drag handle with brand accent.
class DriverHomeSheetHandle extends StatelessWidget {
  const DriverHomeSheetHandle({super.key, required this.colors});

  final DriverColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(
          top: DriverSpacing.sm,
          bottom: DriverSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DriverRadius.pill),
          gradient: LinearGradient(
            colors: [
              colors.primary.withValues(alpha: 0.35),
              colors.primary.withValues(alpha: 0.12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Metric emphasis for tile footers.
class DriverHomeMetricText extends StatelessWidget {
  const DriverHomeMetricText({
    super.key,
    required this.value,
    required this.colors,
    required this.typography,
  });

  final String value;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          DriverHomePremiumStyle.earningsShader(colors).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        value,
        style: typography.displaySmall.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: -1,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
