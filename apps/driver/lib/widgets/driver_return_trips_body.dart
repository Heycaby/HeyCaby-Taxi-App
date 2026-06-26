import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_empty_state.dart';
import 'driver_trip_planning_flow_common.dart';

/// **Return Trips** — discount control + available return offers.
class DriverReturnTripsBody extends StatelessWidget {
  const DriverReturnTripsBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.subtitle,
    required this.discountPct,
    required this.computedFareText,
    required this.chanceLabel,
    required this.chanceColor,
    required this.loading,
    required this.trips,
    required this.onBack,
    required this.onDiscountChanged,
    required this.onAcceptTrip,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String? subtitle;
  final double discountPct;
  final String computedFareText;
  final String chanceLabel;
  final Color chanceColor;
  final bool loading;
  final List<DriverReturnTripOfferItem> trips;
  final VoidCallback onBack;
  final ValueChanged<double> onDiscountChanged;
  final ValueChanged<int> onAcceptTrip;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverTripPlanningFlowScaffold(
      title: DriverStrings.returnTrips,
      subtitle: subtitle,
      colors: colors,
      typography: typography,
      centerTitle: false,
      onBack: onBack,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            DriverSpacing.screenEdge,
            DriverSpacing.lg,
            DriverSpacing.screenEdge,
            bottomPad + DriverSpacing.lg,
          ),
          children: [
            DriverReturnDiscountCard(
              colors: colors,
              typography: typography,
              valuePct: discountPct,
              computedFareText: computedFareText,
              chanceLabel: chanceLabel,
              chanceColor: chanceColor,
              onChanged: onDiscountChanged,
            ),
            const SizedBox(height: DriverSpacing.lg),
            if (loading)
              Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.primary,
                ),
              )
            else if (trips.isEmpty)
              DriverEmptyState(
                colors: colors,
                typography: typography,
                icon: Icons.sync_alt_rounded,
                title: 'Geen retourritten beschikbaar.',
              )
            else
              ...List.generate(trips.length, (index) {
                final trip = trips[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: DriverSpacing.md),
                  child: DriverReturnTripOfferCard(
                    item: trip,
                    colors: colors,
                    typography: typography,
                    onAccept: trip.canAccept ? () => onAcceptTrip(index) : null,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
