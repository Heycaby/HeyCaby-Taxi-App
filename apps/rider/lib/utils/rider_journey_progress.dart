import '../services/nearby_supply_service.dart';

/// Discrete journey steps shown on the rider active-ride timeline.
enum RiderJourneyStep {
  driverFound,
  enRouteToPickup,
  nearPickup,
  atPickup,
  tripInProgress,
}

/// Distance threshold (km) for "around the corner" proximity phase.
const double kNearPickupThresholdKm = 1.0;

/// Computes timeline step + fractional segment progress from ride status and GPS.
/// Also carries live trip metrics (distance remaining, ETA) for the progress bar.
class RiderJourneyProgress {
  const RiderJourneyProgress({
    required this.stepIndex,
    required this.trackProgress,
    required this.showLiveTrack,
    this.liveSegmentFraction,
    this.segmentLabel,
    this.remainingKm,
    this.etaMinutes,
    this.isNearPickup = false,
  });

  final int stepIndex;
  final double trackProgress;
  final bool showLiveTrack;
  final String? segmentLabel;

  /// Fractional progress within the current journey segment (0.0–1.0).
  /// Used by the trip progress bar to show live distance-based progress.
  final double? liveSegmentFraction;

  /// Live distance remaining to destination (km) during in_progress.
  final double? remainingKm;

  /// Live ETA in minutes to destination during in_progress, or to pickup during en route.
  final int? etaMinutes;

  /// True when driver is within [kNearPickupThresholdKm] of pickup during en route.
  final bool isNearPickup;

  static bool isDriverMatched(String status) {
    switch (status) {
      case 'driver_found':
      case 'accepted':
      case 'assigned':
      case 'driver_en_route':
      case 'driver_arrived':
      case 'arrived':
      case 'in_progress':
        return true;
      default:
        return false;
    }
  }

  static bool isEnRouteToPickup(String status) {
    switch (status) {
      case 'driver_en_route':
      case 'accepted':
      case 'assigned':
      case 'driver_found':
        return true;
      default:
        return false;
    }
  }

  static RiderJourneyStep stepFor({
    required String status,
    required bool driverOnMyWay,
    bool isNearPickup = false,
  }) {
    switch (status) {
      case 'in_progress':
        return RiderJourneyStep.tripInProgress;
      case 'driver_arrived':
      case 'arrived':
        return RiderJourneyStep.atPickup;
      case 'driver_en_route':
        return isNearPickup
            ? RiderJourneyStep.nearPickup
            : RiderJourneyStep.enRouteToPickup;
      case 'accepted':
      case 'assigned':
      case 'driver_found':
        if (!driverOnMyWay) return RiderJourneyStep.driverFound;
        return isNearPickup
            ? RiderJourneyStep.nearPickup
            : RiderJourneyStep.enRouteToPickup;
      default:
        return RiderJourneyStep.driverFound;
    }
  }

  static int stepIndexFor(RiderJourneyStep step) => switch (step) {
        RiderJourneyStep.driverFound => 0,
        RiderJourneyStep.enRouteToPickup => 1,
        RiderJourneyStep.nearPickup => 2,
        RiderJourneyStep.atPickup => 3,
        RiderJourneyStep.tripInProgress => 4,
      };

  static bool shouldShowLiveTrack({
    required String status,
    required bool driverOnMyWay,
  }) {
    if (status == 'in_progress' ||
        status == 'driver_arrived' ||
        status == 'arrived' ||
        status == 'driver_en_route') {
      return true;
    }
    return driverOnMyWay && isEnRouteToPickup(status);
  }

  static double segmentFraction({
    required RiderJourneyStep step,
    required double? driverLat,
    required double? driverLng,
    required double? pickupLat,
    required double? pickupLng,
    required double? destLat,
    required double? destLng,
    double? enRouteBaselineKm,
    double? tripBaselineKm,
  }) {
    if (driverLat == null ||
        driverLng == null ||
        driverLat.abs() > 90 ||
        driverLng.abs() > 180) {
      return 0;
    }

    switch (step) {
      case RiderJourneyStep.enRouteToPickup:
      case RiderJourneyStep.nearPickup:
        if (pickupLat == null || pickupLng == null) return 0;
        final remaining = NearbySupplyService.distanceKm(
          driverLat,
          driverLng,
          pickupLat,
          pickupLng,
        );
        final baseline = enRouteBaselineKm ?? remaining;
        if (baseline <= 0.08) return remaining <= 0.08 ? 1 : 0;
        return (1 - (remaining / baseline)).clamp(0.0, 1.0);
      case RiderJourneyStep.tripInProgress:
        if (destLat == null || destLng == null) return 0;
        final remaining = NearbySupplyService.distanceKm(
          driverLat,
          driverLng,
          destLat,
          destLng,
        );
        final baseline = tripBaselineKm ?? remaining;
        if (baseline <= 0.08) return remaining <= 0.08 ? 1 : 0;
        return (1 - (remaining / baseline)).clamp(0.0, 1.0);
      case RiderJourneyStep.driverFound:
      case RiderJourneyStep.atPickup:
        return step == RiderJourneyStep.atPickup ? 1 : 0;
    }
  }

  static double trackProgressFor({
    required int stepIndex,
    required double segmentFraction,
    int stepCount = 5,
  }) {
    final segments = stepCount - 1;
    if (segments <= 0) return 1;
    return ((stepIndex + segmentFraction.clamp(0.0, 1.0)) / segments)
        .clamp(0.0, 1.0);
  }

  static RiderJourneyProgress compute({
    required String status,
    required bool driverOnMyWay,
    double? driverLat,
    double? driverLng,
    double? pickupLat,
    double? pickupLng,
    double? destLat,
    double? destLng,
    double? enRouteBaselineKm,
    double? tripBaselineKm,
  }) {
    // Check proximity to pickup for "around the corner" phase.
    final distToPickupKm = (driverLat != null &&
            driverLng != null &&
            pickupLat != null &&
            pickupLng != null)
        ? NearbySupplyService.distanceKm(
            driverLat, driverLng, pickupLat, pickupLng)
        : double.infinity;
    final isNearPickup = distToPickupKm <= kNearPickupThresholdKm &&
        status != 'driver_arrived' &&
        status != 'arrived' &&
        status != 'in_progress';

    final step = stepFor(
      status: status,
      driverOnMyWay: driverOnMyWay,
      isNearPickup: isNearPickup,
    );
    final index = stepIndexFor(step);
    final showLive = shouldShowLiveTrack(
      status: status,
      driverOnMyWay: driverOnMyWay,
    );
    final fraction = showLive
        ? segmentFraction(
            step: step,
            driverLat: driverLat,
            driverLng: driverLng,
            pickupLat: pickupLat,
            pickupLng: pickupLng,
            destLat: destLat,
            destLng: destLng,
            enRouteBaselineKm: enRouteBaselineKm,
            tripBaselineKm: tripBaselineKm,
          )
        : 0.0;

    // Compute live trip metrics for progress bar.
    double? remainingKm;
    int? etaMinutes;
    if (step == RiderJourneyStep.tripInProgress &&
        destLat != null &&
        destLng != null &&
        driverLat != null &&
        driverLng != null) {
      remainingKm = NearbySupplyService.distanceKm(
        driverLat, driverLng, destLat, destLng,
      );
      etaMinutes = ((remainingKm / 28.0) * 60.0).ceil().clamp(1, 90);
    } else if ((step == RiderJourneyStep.enRouteToPickup ||
            step == RiderJourneyStep.nearPickup) &&
        pickupLat != null &&
        pickupLng != null &&
        driverLat != null &&
        driverLng != null) {
      remainingKm = NearbySupplyService.distanceKm(
        driverLat, driverLng, pickupLat, pickupLng,
      );
      etaMinutes = ((remainingKm / 28.0) * 60.0).ceil().clamp(1, 90);
    }

    return RiderJourneyProgress(
      stepIndex: index,
      trackProgress: trackProgressFor(
        stepIndex: index,
        segmentFraction: fraction,
      ),
      showLiveTrack: showLive,
      liveSegmentFraction: fraction,
      remainingKm: remainingKm,
      etaMinutes: etaMinutes,
      isNearPickup: isNearPickup,
    );
  }

  /// True when the driver has sent an on-my-way ping for this ride.
  static bool timelineIncludesOnMyWay(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final event = row['event']?.toString() ?? '';
      if (!event.startsWith('driver.ping_')) continue;
      final kind = event
          .replaceFirst('driver.ping_', '')
          .split('.')
          .first
          .trim();
      if (kind == 'on_my_way' || kind == 'nearby') return true;
    }
    return false;
  }
}
