import '../l10n/driver_strings.dart';
import '../services/driver_data_service.dart';
import '../models/driver_taxi_terug_stats.dart';
import '../ui/driver_status_badge.dart';

/// Status buckets for driver ride ledger screens (Today + My rides).
const driverCompletedRideStatuses = {'completed'};
const driverCancelledRideStatuses = {
  'cancelled',
  'expired',
  'no_driver',
  'declined'
};
const driverUpcomingRideStatuses = {
  'accepted',
  'assigned',
  'driver_en_route',
  'driver_arrived',
  'in_progress',
  'pending',
  'dispatched',
  'bidding',
};

DriverStatusTone driverRideStatusTone(MyRideSummary ride) {
  if (ride.manualEntry) return DriverStatusTone.warning;
  if (driverCompletedRideStatuses.contains(ride.status)) {
    return DriverStatusTone.success;
  }
  if (driverCancelledRideStatuses.contains(ride.status)) {
    return DriverStatusTone.error;
  }
  return DriverStatusTone.neutral;
}

String driverRideStatusLabel(MyRideSummary ride) {
  if (ride.manualEntry) return DriverStrings.manualRideTag;
  if (driverCompletedRideStatuses.contains(ride.status)) {
    return DriverStrings.rideCompleted;
  }
  if (driverCancelledRideStatuses.contains(ride.status)) {
    return DriverStrings.rideCancelled;
  }
  return ride.status;
}

/// Booking-mode badge: Taxi Terug, Scheduled, Marketplace, or null for instant.
String? driverRideCategoryLabel(MyRideSummary ride) {
  switch ((ride.bookingMode ?? '').trim().toLowerCase()) {
    case 'terug':
      return DriverStrings.returnTrips;
    case 'scheduled':
      return DriverStrings.scheduledRideDetailTitle;
    case 'marketplace':
      return DriverStrings.marketplace;
    default:
      return null;
  }
}

DriverStatusTone driverRideCategoryTone(MyRideSummary ride) {
  if (ride.isTaxiTerugPaidCompleted) return DriverStatusTone.success;
  if (ride.isTaxiTerugRide) return DriverStatusTone.neutral;
  if ((ride.bookingMode ?? '').trim() == 'scheduled') {
    return DriverStatusTone.neutral;
  }
  return DriverStatusTone.neutral;
}

String? driverRideTaxiTerugDetail(MyRideSummary ride) {
  if (!ride.isTaxiTerugPaidCompleted) return null;
  final km = ride.emptyKmSaved;
  final euros = ride.taxiTerugEarningsEuros ?? ride.fare;
  if (km == null && euros == null) return null;
  const stats = DriverTaxiTerugStats(ok: true);
  final kmLabel = km != null ? stats.formatKm(km) : '0';
  final euroLabel =
      euros != null ? stats.formatEuros(euros) : stats.formatEuros(0);
  return DriverStrings.myRidesTaxiTerugRideDetail(
    km: kmLabel,
    euros: euroLabel,
  );
}
