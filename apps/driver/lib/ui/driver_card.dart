import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../widgets/driver_ride_premium_style.dart';

/// Elevated surface card — soft shadow, token radii.
class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.child,
    required this.colors,
    this.padding,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final DriverColors colors;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(DriverSpacing.lg),
      decoration: DriverRidePremiumStyle.frostedFill(
        colors,
        borderRadius: DriverRadius.mdAll,
        tint: colors.card,
        tintOpacity: 0.62,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DriverRadius.mdAll,
        child: content,
      ),
    );
  }
}
