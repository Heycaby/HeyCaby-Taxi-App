import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../widgets/driver_home_premium_style.dart';

/// Premium home tile — soft depth, gradient border (replaces left-rail card).
class DriverAccentRailCard extends StatelessWidget {
  const DriverAccentRailCard({
    super.key,
    required this.colors,
    required this.child,
    this.onTap,
    this.padding,
  });

  final DriverColors colors;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: DriverRadius.lgAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.10),
            colors.border.withValues(alpha: 0.35),
            colors.primary.withValues(alpha: 0.06),
          ],
        ),
      ),
      padding: const EdgeInsets.all(1.2),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(DriverRadius.lg - 1),
          boxShadow: DriverHomePremiumStyle.tileShadow(colors),
        ),
        padding: padding ?? const EdgeInsets.all(DriverSpacing.md),
        child: child,
      ),
    );

    if (onTap == null) return inner;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DriverRadius.lgAll,
        splashColor: colors.primary.withValues(alpha: 0.10),
        highlightColor: colors.primary.withValues(alpha: 0.04),
        child: inner,
      ),
    );
  }
}
