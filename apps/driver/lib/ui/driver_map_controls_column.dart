import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import 'driver_map_fab.dart';

/// Vertical stack of map FABs — recenter, hub, layers.
class DriverMapControlsColumn extends StatelessWidget {
  const DriverMapControlsColumn({
    super.key,
    required this.colors,
    required this.recenterIcon,
    required this.onRecenter,
    this.hubIcon,
    this.onHub,
    this.hubBadge,
    this.recenterTooltip,
    this.hubTooltip,
  });

  final DriverColors colors;
  final IconData recenterIcon;
  final VoidCallback onRecenter;
  final IconData? hubIcon;
  final VoidCallback? onHub;
  final int? hubBadge;
  final String? recenterTooltip;
  final String? hubTooltip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DriverMapFab(
          icon: recenterIcon,
          colors: colors,
          tooltip: recenterTooltip,
          onTap: onRecenter,
        ),
        if (hubIcon != null && onHub != null) ...[
          const SizedBox(height: DriverSpacing.sm),
          DriverMapFab(
            icon: hubIcon!,
            colors: colors,
            variant: DriverMapFabVariant.primary,
            badge: hubBadge,
            tooltip: hubTooltip,
            onTap: onHub!,
          ),
        ],
      ],
    );
  }
}
