import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_empty_state.dart';
import 'driver_trip_planning_flow_common.dart';

/// **Scheduled Rides** — requests vs confirmed tabs + ride cards.
class DriverScheduledRidesBody extends StatelessWidget {
  const DriverScheduledRidesBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.requestsSelected,
    required this.loading,
    required this.emptyMessage,
    required this.errorMessage,
    required this.rides,
    required this.onBack,
    required this.onRequestsTap,
    required this.onConfirmedTap,
    required this.onRideTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool requestsSelected;
  final bool loading;
  final String? emptyMessage;
  final String? errorMessage;
  final List<DriverScheduledRideListItem> rides;
  final VoidCallback onBack;
  final VoidCallback onRequestsTap;
  final VoidCallback onConfirmedTap;
  final ValueChanged<int> onRideTap;

  @override
  Widget build(BuildContext context) {
    return DriverTripPlanningFlowScaffold(
      title: DriverStrings.scheduledRides,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: Column(
        children: [
          DriverScheduledTabBar(
            colors: colors,
            typography: typography,
            requestsSelected: requestsSelected,
            onRequestsTap: onRequestsTap,
            onConfirmedTap: onConfirmedTap,
          ),
          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  )
                : errorMessage != null
                    ? DriverEmptyState(
                        colors: colors,
                        typography: typography,
                        icon: Icons.error_outline_rounded,
                        title: errorMessage!,
                      )
                    : rides.isEmpty
                        ? DriverEmptyState(
                            colors: colors,
                            typography: typography,
                            icon: Icons.event_rounded,
                            title: emptyMessage ?? 'No rides',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DriverSpacing.screenEdge,
                            ),
                            itemCount: rides.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: DriverSpacing.lg,
                                ),
                                child: DriverScheduledRideCard(
                                  item: rides[index],
                                  colors: colors,
                                  typography: typography,
                                  onTap: () => onRideTap(index),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
