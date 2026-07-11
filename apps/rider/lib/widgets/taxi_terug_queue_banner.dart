import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../models/taxi_terug_queue_status.dart';

/// Banner when a Taxi Terug ride is queued until the driver finishes their trip.
class TaxiTerugQueueBanner extends StatelessWidget {
  const TaxiTerugQueueBanner({
    super.key,
    required this.status,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final TaxiTerugQueueStatus status;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final min = status.pickupAvailableMin;
    final max = status.pickupAvailableMax;
    final pickupLine = (min != null && max != null)
        ? l10n.taxiTerugCandidatePickupWindow(min, max)
        : (status.estimatedPickupMinutes != null
            ? l10n.taxiTerugCandidateEta(status.estimatedPickupMinutes!)
            : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_taxi_rounded, color: colors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.taxiTerugQueuedConfirmed,
                  style: typo.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.taxiTerugQueuedWaitingForDriver,
            style: typo.bodySmall.copyWith(color: colors.textSoft),
          ),
          if (pickupLine != null) ...[
            const SizedBox(height: 4),
            Text(
              pickupLine,
              style: typo.labelLarge.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (status.driverName != null && status.driverName!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              status.driverVehicle != null && status.driverVehicle!.isNotEmpty
                  ? '${status.driverName} · ${status.driverVehicle}'
                  : status.driverName!,
              style: typo.bodySmall.copyWith(color: colors.text),
            ),
          ],
        ],
      ),
    );
  }
}
