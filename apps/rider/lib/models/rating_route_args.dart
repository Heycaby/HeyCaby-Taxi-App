import '../widgets/rider_driver_info_card.dart';

/// Immutable ride context for [/rating] so submit survives provider resets.
class RatingRouteArgs {
  const RatingRouteArgs({
    this.rideRequestId,
    this.riderToken,
    this.driverInfo,
  });

  final String? rideRequestId;
  final String? riderToken;
  final RiderDriverSheetInfo? driverInfo;
}
