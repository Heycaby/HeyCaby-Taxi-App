import '../models/live_ride_activity_phase.dart';
import '../models/ride_waiting_info.dart';

/// Builds the App Group payload for iOS Live Activities.
///
/// Keys must stay in sync with `HeyCabyWidgetsLiveActivity.swift`.
class LiveRideActivityPayload {
  const LiveRideActivityPayload._({
    required this.phase,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.nextAction,
    required this.eta,
    required this.progressPercent,
    required this.graceRemaining,
    required this.waitFeeLine,
    required this.heroMetric,
    required this.compactTrailing,
    required this.waitPhase,
  });

  final LiveRideActivityPhase phase;
  final String title;
  final String subtitle;
  final String status;
  final String nextAction;
  final String eta;
  final int progressPercent;
  final String graceRemaining;
  final String waitFeeLine;
  final String heroMetric;
  final String compactTrailing;
  final String waitPhase;

  Map<String, dynamic> toActivityMap() => {
        'phase': phase.wireValue,
        'title': title,
        'subtitle': subtitle,
        'status': status,
        'nextAction': nextAction,
        'eta': eta,
        'progressPercent': '$progressPercent',
        'timelineStep': '${_legacyTimelineStep(phase)}',
        'graceRemaining': graceRemaining,
        'waitFee': waitFeeLine,
        'totalFare': '',
        'heroMetric': heroMetric,
        'compactTrailing': compactTrailing,
        'waitPhase': waitPhase,
      };

  static int _legacyTimelineStep(LiveRideActivityPhase phase) {
    switch (phase) {
      case LiveRideActivityPhase.searching:
        return 0;
      case LiveRideActivityPhase.driverFound:
      case LiveRideActivityPhase.onTheWay:
      case LiveRideActivityPhase.nearby:
        return 1;
      case LiveRideActivityPhase.outsideFreeWait:
      case LiveRideActivityPhase.outsidePaidWait:
        return 2;
      case LiveRideActivityPhase.onTrip:
        return 3;
      case LiveRideActivityPhase.paymentPending:
      case LiveRideActivityPhase.paymentComplete:
        return 4;
    }
  }

  static String formatSearchElapsed(int elapsedSeconds) {
    if (elapsedSeconds <= 0) return '';
    final mins = (elapsedSeconds / 60).ceil().clamp(1, 999);
    return mins == 1 ? '1 min' : '$mins min';
  }

  static LiveRideActivityPayload searching({
    required String routeLine,
    int driversNotified = 0,
    int elapsedSeconds = 0,
  }) {
    const phase = LiveRideActivityPhase.searching;
    final notified = driversNotified > 0
        ? '$driversNotified driver${driversNotified == 1 ? '' : 's'} notified'
        : 'Matching nearby taxis';
    final elapsedLabel = formatSearchElapsed(elapsedSeconds);
    return LiveRideActivityPayload._(
      phase: phase,
      title: 'Looking for a driver',
      subtitle: routeLine.isEmpty ? 'HeyCaby ride' : routeLine,
      status: notified,
      nextAction: "We're notifying nearby drivers.",
      eta: '',
      progressPercent: phase.progressPercent,
      graceRemaining: '',
      waitFeeLine: '',
      heroMetric: elapsedLabel,
      compactTrailing: driversNotified > 0 ? '$driversNotified' : elapsedLabel,
      waitPhase: 'none',
    );
  }

  static LiveRideActivityPhase resolveActivePhase({
    required String rideStatus,
    RideWaitingInfo? waitingInfo,
    double? driverKmToPickup,
    bool paymentPending = false,
    bool paymentComplete = false,
  }) {
    if (paymentComplete || rideStatus == 'payment_confirmed') {
      return LiveRideActivityPhase.paymentComplete;
    }
    if (paymentPending) return LiveRideActivityPhase.paymentPending;

    final st = rideStatus.trim().toLowerCase();
    if (st == 'completed') return LiveRideActivityPhase.paymentPending;
    if (st == 'in_progress') return LiveRideActivityPhase.onTrip;

    if (st == 'driver_arrived' || st == 'arrived') {
      if (waitingInfo != null) {
        if (waitingInfo.isInGracePeriod) {
          return LiveRideActivityPhase.outsideFreeWait;
        }
        if (waitingInfo.waitingFeeCentsNow() > 0 && !waitingInfo.waived) {
          return LiveRideActivityPhase.outsidePaidWait;
        }
      }
      return LiveRideActivityPhase.outsideFreeWait;
    }

    if (st == 'driver_nearby') return LiveRideActivityPhase.nearby;

    if (driverKmToPickup != null && driverKmToPickup <= 1.0) {
      final enRoute = st == 'driver_en_route' ||
          st == 'accepted' ||
          st == 'assigned' ||
          st == 'driver_found' ||
          st == 'driver_nearby';
      if (enRoute) return LiveRideActivityPhase.nearby;
    }

    if (st == 'driver_en_route') return LiveRideActivityPhase.onTheWay;

    if (st == 'accepted' ||
        st == 'assigned' ||
        st == 'driver_found') {
      return LiveRideActivityPhase.driverFound;
    }

    return LiveRideActivityPhase.onTheWay;
  }

  static LiveRideActivityPayload activeRide({
    required String rideStatus,
    required String driverName,
    required String vehicleLabel,
    required String plate,
    int? etaMinutes,
    String? destination,
    RideWaitingInfo? waitingInfo,
    double? driverKmToPickup,
    bool paymentPending = false,
    bool paymentComplete = false,
    String? paymentMethodLabel,
  }) {
    final phase = resolveActivePhase(
      rideStatus: rideStatus,
      waitingInfo: waitingInfo,
      driverKmToPickup: driverKmToPickup,
      paymentPending: paymentPending,
      paymentComplete: paymentComplete,
    );

    final name = driverName.trim().isEmpty ? 'Your driver' : driverName.trim();
    final vehicle = [vehicleLabel, plate].where((s) => s.trim().isNotEmpty).join(' · ');
    final etaStr = etaMinutes != null && etaMinutes > 0 ? '$etaMinutes min' : '';

    switch (phase) {
      case LiveRideActivityPhase.paymentComplete:
        return LiveRideActivityPayload._(
          phase: phase,
          title: 'Payment received',
          subtitle: 'Thank you for riding with HeyCaby',
          status: '',
          nextAction: 'See you on your next ride.',
          eta: '',
          progressPercent: phase.progressPercent,
          graceRemaining: '',
          waitFeeLine: '',
          heroMetric: '✓',
          compactTrailing: 'Done',
          waitPhase: 'none',
        );
      case LiveRideActivityPhase.paymentPending:
        return LiveRideActivityPayload._(
          phase: phase,
          title: 'Payment',
          subtitle: paymentMethodLabel?.trim().isNotEmpty == true
              ? paymentMethodLabel!.trim()
              : 'Confirm with your driver',
          status: 'Waiting for confirmation',
          nextAction: 'Confirm payment with your driver.',
          eta: '',
          progressPercent: phase.progressPercent,
          graceRemaining: '',
          waitFeeLine: '',
          heroMetric: 'Pay',
          compactTrailing: 'Pay',
          waitPhase: 'none',
        );
      case LiveRideActivityPhase.onTrip:
        return LiveRideActivityPayload._(
          phase: phase,
          title: 'On your way',
          subtitle: destination?.trim().isNotEmpty == true
              ? destination!.trim()
              : 'Trip in progress',
          status: etaStr.isNotEmpty ? 'Arriving in $etaStr' : 'En route to destination',
          nextAction: "Relax — we'll keep you updated.",
          eta: etaStr,
          progressPercent: phase.progressPercent,
          graceRemaining: '',
          waitFeeLine: '',
          heroMetric: etaStr,
          compactTrailing: etaStr.isNotEmpty ? etaStr : 'Trip',
          waitPhase: 'none',
        );
      case LiveRideActivityPhase.outsideFreeWait:
        final grace = waitingInfo != null
            ? _formatGrace(waitingInfo.remainingGraceSecondsNow())
            : '';
        return LiveRideActivityPayload._(
          phase: phase,
          title: 'Driver outside',
          subtitle: vehicle.isEmpty ? name : vehicle,
          status: grace.isNotEmpty ? 'Free wait · $grace left' : 'Meet at your pickup point',
          nextAction: vehicle.isEmpty
              ? 'Your driver is waiting for you.'
              : 'Look for $vehicle.',
          eta: '',
          progressPercent: phase.progressPercent,
          graceRemaining: grace,
          waitFeeLine: '',
          heroMetric: grace.isNotEmpty ? grace : 'Outside',
          compactTrailing: grace.isNotEmpty ? '$grace free' : 'Outside',
          waitPhase: 'free',
        );
      case LiveRideActivityPhase.outsidePaidWait:
        final feeCents = waitingInfo?.waitingFeeCentsNow() ?? 0;
        final feeLine = feeCents > 0
            ? '€${(feeCents / 100).toStringAsFixed(2)} added'
            : 'Waiting fee active';
        return LiveRideActivityPayload._(
          phase: phase,
          title: 'Waiting fee active',
          subtitle: vehicle.isEmpty ? name : vehicle,
          status: feeLine,
          nextAction: 'Please join your driver at the pickup point.',
          eta: '',
          progressPercent: phase.progressPercent,
          graceRemaining: '',
          waitFeeLine: feeLine,
          heroMetric: feeLine,
          compactTrailing: feeCents > 0
              ? '€${(feeCents / 100).toStringAsFixed(2)}'
              : 'Wait',
          waitPhase: 'paid',
        );
      case LiveRideActivityPhase.nearby:
        return LiveRideActivityPayload._(
          phase: phase,
          title: 'Driver nearby',
          subtitle: vehicle.isEmpty ? name : vehicle,
          status: 'Please head to pickup',
          nextAction: 'Please head downstairs.',
          eta: etaStr,
          progressPercent: phase.progressPercent,
          graceRemaining: '',
          waitFeeLine: '',
          heroMetric: 'Nearby',
          compactTrailing: etaStr.isNotEmpty ? etaStr : 'Near',
          waitPhase: 'none',
        );
      case LiveRideActivityPhase.driverFound:
        return LiveRideActivityPayload._(
          phase: phase,
          title: '$name accepted',
          subtitle: vehicleLabel.trim().isNotEmpty ? vehicleLabel.trim() : vehicle,
          status: etaStr.isNotEmpty ? 'Pickup in $etaStr' : 'Heading to pickup',
          nextAction: 'Meet your driver at the pickup point.',
          eta: etaStr,
          progressPercent: phase.progressPercent,
          graceRemaining: '',
          waitFeeLine: '',
          heroMetric: etaStr.isNotEmpty ? etaStr : 'Found',
          compactTrailing: etaStr.isNotEmpty ? etaStr : 'Found',
          waitPhase: 'none',
        );
      case LiveRideActivityPhase.onTheWay:
        return LiveRideActivityPayload._(
          phase: phase,
          title: etaStr.isNotEmpty ? 'Pickup in $etaStr' : 'Driver on the way',
          subtitle: vehicle.isEmpty ? name : vehicle,
          status: '$name is heading to you',
          nextAction: '$name is heading to you.',
          eta: etaStr,
          progressPercent: phase.progressPercent,
          graceRemaining: '',
          waitFeeLine: '',
          heroMetric: etaStr,
          compactTrailing: etaStr.isNotEmpty ? etaStr : 'En route',
          waitPhase: 'none',
        );
      case LiveRideActivityPhase.searching:
        return searching(routeLine: destination ?? '');
    }
  }

  static String _formatGrace(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final m = safe ~/ 60;
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
