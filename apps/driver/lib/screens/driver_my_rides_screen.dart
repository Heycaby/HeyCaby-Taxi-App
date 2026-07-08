import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:intl/intl.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import '../widgets/driver_ledger_flow_common.dart';
import '../widgets/driver_todays_ledger_body.dart';

class DriverMyRidesScreen extends ConsumerWidget {
  const DriverMyRidesScreen({super.key});

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver');
  }

  List<DriverLedgerHistoryItem> _mapItems(List<MyRideSummary> rides) {
    return rides.map((ride) {
      final date = ride.createdAt == null
          ? '—'
          : DateFormat('dd MMM yyyy, HH:mm').format(ride.createdAt!.toLocal());
      final fare = ride.fare == null
          ? '—'
          : HeyCabyRideFare.formatEuroLabel(ride.fare) ?? '—';
      final from = (ride.pickupAddress ?? '—').trim();
      final to = (ride.destinationAddress ?? '—').trim();
      final statusLabel =
          ride.manualEntry ? DriverStrings.manualRideTag : ride.status;

      return DriverLedgerHistoryItem(
        dateLabel: date,
        pickupLabel: from,
        dropoffLabel: to,
        fareLabel: fare,
        statusLabel: statusLabel,
        statusTone: ride.manualEntry
            ? DriverStatusTone.warning
            : DriverStatusTone.neutral,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final ridesAsync = ref.watch(myRidesProvider);

    return ridesAsync.when(
      data: (rides) => DriverRideHistoryBody(
        colors: colors,
        typography: typography,
        loading: false,
        errorMessage: null,
        items: _mapItems(rides),
        onBack: () => _handleBack(context),
        onItemTap: (index) =>
            context.push('/driver/my-rides/${rides[index].id}'),
      ),
      loading: () => DriverRideHistoryBody(
        colors: colors,
        typography: typography,
        loading: true,
        errorMessage: null,
        items: const [],
        onBack: () => _handleBack(context),
        onItemTap: (_) {},
      ),
      error: (_, __) => DriverRideHistoryBody(
        colors: colors,
        typography: typography,
        loading: false,
        errorMessage: DriverStrings.myRidesLoadFailed,
        items: const [],
        onBack: () => _handleBack(context),
        onItemTap: (_) {},
      ),
    );
  }
}
