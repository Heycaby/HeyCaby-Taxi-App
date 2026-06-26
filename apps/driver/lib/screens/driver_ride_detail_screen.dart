import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:intl/intl.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import '../widgets/driver_ledger_flow_common.dart';
import '../widgets/driver_ping_history_section.dart';
import '../widgets/driver_trip_receipt_body.dart';

class DriverRideDetailScreen extends ConsumerWidget {
  const DriverRideDetailScreen({super.key, required this.rideId});

  final String rideId;

  DriverStatusTone _statusTone(String status) {
    final s = status.toLowerCase();
    if (s.contains('complete') || s.contains('paid')) {
      return DriverStatusTone.success;
    }
    if (s.contains('cancel')) {
      return DriverStatusTone.error;
    }
    return DriverStatusTone.neutral;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final detailAsync = ref.watch(myRideDetailsProvider(rideId));

    return detailAsync.when(
      data: (ride) {
        if (ride == null) {
          return DriverTripReceiptBody(
            colors: colors,
            typography: typography,
            loading: false,
            errorMessage: null,
            notFound: true,
            fareLabel: '—',
            subtitle: '',
            statusLabel: '',
            statusTone: DriverStatusTone.neutral,
            details: const [],
            onBack: () => context.pop(),
          );
        }

        final date = ride.createdAt == null
            ? '—'
            : DateFormat('dd MMM yyyy, HH:mm').format(ride.createdAt!.toLocal());
        final fare = ride.fare == null
            ? '—'
            : '${ride.currency ?? 'EUR'} ${ride.fare!.toStringAsFixed(2)}';
        final earnings = ride.driverEarningsCents == null
            ? '—'
            : '${ride.currency ?? 'EUR'} ${(ride.driverEarningsCents! / 100).toStringAsFixed(2)}';
        final fee = ride.platformFeeCents == null
            ? '—'
            : '${ride.currency ?? 'EUR'} ${(ride.platformFeeCents! / 100).toStringAsFixed(2)}';

        return DriverTripReceiptBody(
          colors: colors,
          typography: typography,
          loading: false,
          errorMessage: null,
          notFound: false,
          fareLabel: fare,
          subtitle: date,
          statusLabel: ride.status,
          statusTone: _statusTone(ride.status),
          footerSections: [
            const SizedBox(height: DriverSpacing.lg),
            DriverPingHistorySection(
              rideRequestId: rideId,
              colors: colors,
              typography: typography,
              initiallyExpanded: true,
              collapsible: false,
              showTopSpacing: false,
            ),
          ],
          details: [
            DriverLedgerDetailItem(
              label: DriverStrings.type,
              value: ride.manualEntry
                  ? DriverStrings.manualRideTag
                  : DriverStrings.standardRideTag,
            ),
            DriverLedgerDetailItem(
              label: DriverStrings.pickup,
              value: ride.pickupAddress ?? '—',
            ),
            DriverLedgerDetailItem(
              label: DriverStrings.dropoff,
              value: ride.destinationAddress ?? '—',
            ),
            DriverLedgerDetailItem(
              label: DriverStrings.paymentMethod,
              value: ride.paymentMethod ?? '—',
            ),
            DriverLedgerDetailItem(
              label: DriverStrings.driverEarnings,
              value: earnings,
              emphasize: true,
            ),
            DriverLedgerDetailItem(
              label: DriverStrings.platformFee,
              value: fee,
            ),
          ],
          onBack: () => context.pop(),
        );
      },
      loading: () => DriverTripReceiptBody(
        colors: colors,
        typography: typography,
        loading: true,
        errorMessage: null,
        notFound: false,
        fareLabel: '—',
        subtitle: '',
        statusLabel: '',
        statusTone: DriverStatusTone.neutral,
        details: const [],
        onBack: () => context.pop(),
      ),
      error: (_, __) => DriverTripReceiptBody(
        colors: colors,
        typography: typography,
        loading: false,
        errorMessage: DriverStrings.myRidesLoadFailed,
        notFound: false,
        fareLabel: '—',
        subtitle: '',
        statusLabel: '',
        statusTone: DriverStatusTone.neutral,
        details: const [],
        onBack: () => context.pop(),
      ),
    );
  }
}
