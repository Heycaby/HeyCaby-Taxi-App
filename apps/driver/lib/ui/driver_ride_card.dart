import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_card.dart';
import 'driver_status_badge.dart';

/// Incoming / active ride summary card.
class DriverRideCard extends StatelessWidget {
  const DriverRideCard({
    super.key,
    required this.colors,
    required this.typography,
    required this.pickupLabel,
    required this.dropoffLabel,
    this.fareLabel,
    this.metaLabel,
    this.statusLabel,
    this.statusTone = DriverStatusTone.neutral,
    this.onTap,
    this.trailing,
    this.incomingPulse = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupLabel;
  final String dropoffLabel;
  final String? fareLabel;
  final String? metaLabel;
  final String? statusLabel;
  final DriverStatusTone statusTone;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool incomingPulse;

  @override
  Widget build(BuildContext context) {
    final card = DriverCard(
      colors: colors,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (statusLabel != null) ...[
            DriverStatusBadge(
              label: statusLabel!,
              colors: colors,
              typography: typography,
              tone: statusTone,
            ),
            const SizedBox(height: DriverSpacing.md),
          ],
          Text(
            pickupLabel,
            style: typography.titleMedium.copyWith(color: colors.text),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DriverSpacing.xs),
          Text(
            dropoffLabel,
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (fareLabel != null || metaLabel != null || trailing != null) ...[
            const SizedBox(height: DriverSpacing.lg),
            Row(
              children: [
                if (fareLabel != null)
                  Text(
                    fareLabel!,
                    style: typography.numberMedium(colors),
                  ),
                if (metaLabel != null) ...[
                  const SizedBox(width: DriverSpacing.md),
                  Expanded(
                    child: Text(
                      metaLabel!,
                      style: typography.bodySmall.copyWith(color: colors.textMuted),
                    ),
                  ),
                ],
                if (trailing != null) trailing!,
              ],
            ),
          ],
        ],
      ),
    );

    return incomingPulse
        ? card.driverRideIncomingPulse().driverFadeSlideIn(staggerIndex: 1)
        : card;
  }
}
