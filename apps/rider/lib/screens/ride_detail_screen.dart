import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/ride_history_provider.dart';
import 'report_screen.dart';

class RideDetailScreen extends ConsumerWidget {
  const RideDetailScreen({super.key, required this.ride});

  final RideHistoryItem ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    Color statusColor;
    switch (ride.status) {
      case 'completed':
        statusColor = colors.success;
        break;
      case 'cancelled':
        statusColor = colors.error;
        break;
      case 'pending':
      case 'assigned':
      case 'arrived':
      case 'in_progress':
        statusColor = colors.accent;
        break;
      default:
        statusColor = colors.textMid;
    }

    String statusLabel;
    switch (ride.status) {
      case 'completed':
        statusLabel = l10n.tripComplete;
        break;
      case 'cancelled':
        statusLabel = l10n.rideStatusCancelled;
        break;
      case 'pending':
        statusLabel = l10n.searching;
        break;
      case 'assigned':
        statusLabel = l10n.driverOnTheWay;
        break;
      case 'arrived':
        statusLabel = l10n.driverArrived;
        break;
      case 'in_progress':
        statusLabel = l10n.tripInProgress;
        break;
      case 'marketplace':
        statusLabel = l10n.marketplace;
        break;
      default:
        statusLabel = ride.status;
    }

    final isActive = ['pending', 'assigned', 'arrived', 'in_progress'].contains(ride.status);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.myRides,
          style: typo.titleMedium.copyWith(color: colors.text),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.all(16),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            style: typo.labelSmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${ride.createdAt.day}/${ride.createdAt.month}/${ride.createdAt.year}',
                          style: typo.bodySmall.copyWith(color: colors.textMid),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _DetailRow(
                      icon: Icons.radio_button_checked,
                      iconColor: colors.accent,
                      label: ride.pickupAddress,
                      colors: colors,
                      typo: typo,
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 11),
                      child: Container(
                        width: 2,
                        height: 20,
                        color: colors.border,
                      ),
                    ),
                    _DetailRow(
                      icon: Icons.location_on,
                      iconColor: colors.accent,
                      label: ride.destinationAddress,
                      colors: colors,
                      typo: typo,
                    ),
                    if (ride.fare != null) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.fareEstimate,
                            style: typo.bodyMedium.copyWith(
                              color: colors.textMid,
                            ),
                          ),
                          Text(
                            '€${ride.fare!.toStringAsFixed(2)}',
                            style: typo.titleMedium.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (ride.driverName != null) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (ride.driverPhoto != null)
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: colors.accentL,
                              backgroundImage: NetworkImage(ride.driverPhoto!),
                            )
                          else
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colors.accentL,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                color: colors.accent,
                                size: 22,
                              ),
                            ),
                          const SizedBox(width: 12),
                          Text(
                            ride.driverName!,
                            style: typo.bodyLarge.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go('/active'),
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    child: Text(
                      l10n.tripInProgress,
                      style: typo.labelLarge.copyWith(color: colors.onAccent),
                    ),
                  ),
                ),
              ],
              if (ride.status == 'completed') ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/report',
                      extra: ReportRouteArgs(ridesRowId: ride.id),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.flag_outlined, color: colors.error, size: 22),
                    label: Text(
                      l10n.ridesCardReportRide,
                      style: typo.labelLarge.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: typo.bodyMedium.copyWith(color: colors.text),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
