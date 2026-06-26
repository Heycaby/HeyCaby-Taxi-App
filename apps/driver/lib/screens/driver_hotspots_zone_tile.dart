import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../l10n/driver_strings.dart';
import '../services/driver_data_service.dart';
import '../theme/app_icons.dart';
import 'driver_hotspots_models.dart';

/// One row in the Hotspots bottom sheet — matches reference layout (score disc, zone, stats, trips/hr).
class HotspotsZoneTile extends StatelessWidget {
  const HotspotsZoneTile({
    super.key,
    required this.zone,
    required this.isBest,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  final ZoneDemand zone;
  final bool isBest;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tier = hotspotTierForDemand(zone.waitingPassengers);
    final fill = hotspotTierFill(colors, tier);
    final score = zone.waitingPassengers.clamp(0, 99);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill.withValues(alpha: 0.2),
                  border: Border.all(color: fill.withValues(alpha: 0.55), width: 2),
                  boxShadow: tier == HotspotDemandTier.high
                      ? [
                          BoxShadow(
                            color: fill.withValues(alpha: 0.35),
                            blurRadius: 14,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '$score',
                  style: typo.titleMedium.copyWith(
                    color: fill,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            zone.zoneName ?? zone.zoneId,
                            style: typo.bodyLarge.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isBest)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.success.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: colors.success.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              DriverStrings.hotspotsBestNow,
                              style: typo.labelSmall.copyWith(
                                color: colors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hotspotSublineForZone(zone),
                      style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(LucideIcons.usersRound, size: 14, color: colors.textMid),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            DriverStrings.hotspotsOnlineDrivers(zone.onlineDriversInZone),
                            style: typo.labelSmall.copyWith(color: colors.textMid, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(LucideIcons.history, size: 14, color: colors.textMid),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            DriverStrings.hotspotsRecentRides120m(zone.recentBookings120m),
                            style: typo.labelSmall.copyWith(
                              color: colors.textMid,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DriverStrings.hotspotsDemandLabel(hotspotDemandLevelLine(zone)),
                      style: typo.labelSmall.copyWith(
                        color: tier == HotspotDemandTier.high ? colors.error : colors.textSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DriverStrings.hotspotsActivityCaption,
                    style: typo.labelSmall.copyWith(color: colors.textSoft, fontSize: 10),
                  ),
                  Text(
                    '${zone.recentBookings120m}',
                    style: typo.titleSmall.copyWith(
                      color: fill,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Icon(AppIcons.chevronRight, size: 18, color: colors.textSoft),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
