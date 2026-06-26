import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';

enum DriverMapFabVariant { standard, primary }

/// Circular map control — recenter, menu, hub (48dp touch target).
class DriverMapFab extends StatelessWidget {
  const DriverMapFab({
    super.key,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.tooltip,
    this.semanticLabel,
    this.badge,
    this.variant = DriverMapFabVariant.standard,
  });

  final IconData icon;
  final DriverColors colors;
  final VoidCallback onTap;
  final String? tooltip;
  final String? semanticLabel;
  final int? badge;
  final DriverMapFabVariant variant;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == DriverMapFabVariant.primary;
    final fill = isPrimary ? colors.primary : colors.card.withValues(alpha: 0.96);
    final iconColor = isPrimary ? colors.onPrimary : colors.primary;
    final borderColor = isPrimary
        ? colors.primary.withValues(alpha: 0.85)
        : colors.primary.withValues(alpha: 0.45);

    final button = Material(
      color: fill,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: colors.text.withValues(alpha: 0.12),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        customBorder: const CircleBorder(),
        splashColor: (isPrimary ? colors.onPrimary : colors.primary)
            .withValues(alpha: 0.12),
        child: Ink(
          width: DriverSpacing.touchTarget,
          height: DriverSpacing.touchTarget,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: DriverShadows.floating(colors),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );

    Widget child = badge != null && badge! > 0
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              button,
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.error,
                    borderRadius: BorderRadius.circular(DriverRadius.pill),
                    border: Border.all(color: colors.card, width: 1.5),
                  ),
                  child: Text(
                    badge! > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          )
        : button;

    if (tooltip != null) {
      child = Tooltip(message: tooltip!, child: child);
    }

    return Semantics(
      label: semanticLabel ?? tooltip,
      button: true,
      child: child,
    );
  }
}