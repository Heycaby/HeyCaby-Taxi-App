import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../widgets/booking/booking_flow_screen_header.dart';
import '../providers/ride_history_provider.dart';
import 'report_screen.dart';

final riderReceiptProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, rideId) async {
  final api = ref.read(riderApiProvider);
  return api.fetchRideReceipt(rideRequestId: rideId);
});

class RideDetailScreen extends ConsumerWidget {
  const RideDetailScreen({super.key, required this.ride});

  final RideHistoryItem ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final receiptAsync = ref.watch(riderReceiptProvider(ride.id));

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

    final isActive =
        ['pending', 'assigned', 'arrived', 'in_progress'].contains(ride.status);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.rideDetails,
              icon: Icons.receipt_long_rounded,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 32),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settlement reminder',
                        style: typo.bodyMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'You pay the driver directly. Keep this ride for your accounting records.',
                        style: typo.bodySmall.copyWith(color: colors.textMid),
                      ),
                      if (ride.fare != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Estimated amount: €${ride.fare!.toStringAsFixed(2)}',
                          style: typo.bodySmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      receiptAsync.when(
                        data: (receipt) {
                          if (receipt == null) {
                            return Text(
                              'Receipt not available yet.',
                              style: typo.bodySmall
                                  .copyWith(color: colors.textSoft),
                            );
                          }
                          final expected =
                              _tryParseAmount(receipt['expected_amount']);
                          final paid = _tryParseAmount(receipt['paid_amount']);
                          final method = receipt['payment_method']?.toString();
                          final diff = (expected != null && paid != null)
                              ? (paid - expected)
                              : null;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receipt',
                                style: typo.bodySmall.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (expected != null)
                                Text(
                                  'Expected: €${expected.toStringAsFixed(2)}',
                                  style: typo.bodySmall
                                      .copyWith(color: colors.textMid),
                                ),
                              if (paid != null)
                                Text(
                                  'Paid: €${paid.toStringAsFixed(2)}',
                                  style: typo.bodySmall
                                      .copyWith(color: colors.textMid),
                                ),
                              if (method != null && method.isNotEmpty)
                                Text(
                                  'Method: $method',
                                  style: typo.bodySmall
                                      .copyWith(color: colors.textMid),
                                ),
                              if (diff != null && diff < 0)
                                Text(
                                  'Outstanding: €${diff.abs().toStringAsFixed(2)}',
                                  style: typo.bodySmall.copyWith(
                                    color: colors.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (diff != null && diff > 0)
                                Text(
                                  'Overpaid: €${diff.toStringAsFixed(2)}',
                                  style: typo.bodySmall.copyWith(
                                    color: colors.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (diff != null && diff == 0)
                                Text(
                                  'Settlement complete',
                                  style: typo.bodySmall.copyWith(
                                    color: colors.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () => SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.accent,
                          ),
                        ),
                        error: (_, __) => Text(
                          l10n.rideDetailReceiptLoadFailed,
                          style:
                              typo.bodySmall.copyWith(color: colors.textSoft),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/receipt/${ride.id}'),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(l10n.rideDetailViewReceipt),
                  ),
                ),
                const SizedBox(height: 12),
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
                      side: BorderSide(
                          color: colors.error.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.flag_outlined,
                        color: colors.error, size: 22),
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
          ],
        ),
      ),
    );
  }
}

double? _tryParseAmount(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
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
