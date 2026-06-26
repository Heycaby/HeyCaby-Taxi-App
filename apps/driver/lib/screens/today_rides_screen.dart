import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_todays_ledger_body.dart';

class TodayRidesScreen extends ConsumerWidget {
  const TodayRidesScreen({super.key});

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver/work');
  }

  String _zoneName(String? addr) {
    if (addr == null || addr.isEmpty) return '—';
    final parts = addr.split(',');
    return parts.first.trim();
  }

  List<DriverTodaysLedgerRow> _mapRows(List<TodayRide> rides) {
    return rides.map((ride) {
      final timeStr = ride.completedAt != null
          ? DateFormat('HH:mm').format(ride.completedAt!.toLocal())
          : '';
      final fareStr = ride.fare != null
          ? '€${ride.fare!.toStringAsFixed(2)}'
          : '—';
      final pickup = _zoneName(ride.pickup);
      final dest = _zoneName(ride.destination);
      return DriverTodaysLedgerRow(
        routeLabel: '$pickup → $dest',
        fareLabel: fareStr,
        timeLabel: timeStr,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final ridesAsync = ref.watch(todayRidesProvider);

    return ridesAsync.when(
      data: (rides) => DriverTodaysLedgerBody(
        colors: colors,
        typography: typography,
        loading: false,
        errorMessage: null,
        rows: _mapRows(rides),
        onBack: () => _handleBack(context),
      ),
      loading: () => DriverTodaysLedgerBody(
        colors: colors,
        typography: typography,
        loading: true,
        errorMessage: null,
        rows: const [],
        onBack: () => _handleBack(context),
      ),
      error: (_, __) => DriverTodaysLedgerBody(
        colors: colors,
        typography: typography,
        loading: false,
        errorMessage: 'Kon ritten niet laden',
        rows: const [],
        onBack: () => _handleBack(context),
      ),
    );
  }
}
