import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_taxi_terug_queued_status.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';

/// In-ride banner: Taxi Terug booked — next ride after current trip completes.
class DriverTaxiTerugQueuedBanner extends StatelessWidget {
  const DriverTaxiTerugQueuedBanner({
    super.key,
    required this.status,
    required this.colors,
    required this.typography,
  });

  final DriverTaxiTerugQueuedStatus status;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    final dest =
        (status.destinationLabel ?? status.destinationAddress ?? '').trim();
    final destLine = dest.isNotEmpty
        ? DriverStrings.taxiTerugQueuedNextRideToward(dest)
        : DriverStrings.taxiTerugQueuedNextRideGeneric;

    final min = status.pickupAvailableMin;
    final max = status.pickupAvailableMax;
    final timingLine = (min != null && max != null)
        ? DriverStrings.taxiTerugQueuedPickupWindow(min, max)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_taxi_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DriverStrings.taxiTerugQueuedBookedTitle,
                  style: typography.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            destLine,
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
          if (timingLine != null) ...[
            const SizedBox(height: 4),
            Text(
              timingLine,
              style: typography.labelMedium.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
