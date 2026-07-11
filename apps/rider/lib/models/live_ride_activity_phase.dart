/// Canonical Live Activity phases for the rider lock-screen timeline.
enum LiveRideActivityPhase {
  searching,
  driverFound,
  onTheWay,
  nearby,
  outsideFreeWait,
  outsidePaidWait,
  onTrip,
  paymentPending,
  paymentComplete,
}

extension LiveRideActivityPhaseX on LiveRideActivityPhase {
  /// Progress fill for the 8-segment lock-screen bar (CTO spec).
  int get progressPercent {
    switch (this) {
      case LiveRideActivityPhase.searching:
        return 15;
      case LiveRideActivityPhase.driverFound:
        return 30;
      case LiveRideActivityPhase.onTheWay:
        return 45;
      case LiveRideActivityPhase.nearby:
        return 60;
      case LiveRideActivityPhase.outsideFreeWait:
      case LiveRideActivityPhase.outsidePaidWait:
        return 70;
      case LiveRideActivityPhase.onTrip:
        return 85;
      case LiveRideActivityPhase.paymentPending:
        return 95;
      case LiveRideActivityPhase.paymentComplete:
        return 100;
    }
  }

  /// Stable string for native UI (`HeyCabyWidgetsLiveActivity.swift`).
  String get wireValue {
    switch (this) {
      case LiveRideActivityPhase.searching:
        return 'searching';
      case LiveRideActivityPhase.driverFound:
        return 'driver_found';
      case LiveRideActivityPhase.onTheWay:
        return 'on_the_way';
      case LiveRideActivityPhase.nearby:
        return 'nearby';
      case LiveRideActivityPhase.outsideFreeWait:
        return 'outside_free';
      case LiveRideActivityPhase.outsidePaidWait:
        return 'outside_paid';
      case LiveRideActivityPhase.onTrip:
        return 'on_trip';
      case LiveRideActivityPhase.paymentPending:
        return 'payment';
      case LiveRideActivityPhase.paymentComplete:
        return 'completed';
    }
  }

  String get sfSymbol {
    switch (this) {
      case LiveRideActivityPhase.searching:
        return 'magnifyingglass';
      case LiveRideActivityPhase.driverFound:
        return 'checkmark.circle.fill';
      case LiveRideActivityPhase.onTheWay:
        return 'car.fill';
      case LiveRideActivityPhase.nearby:
        return 'location.fill';
      case LiveRideActivityPhase.outsideFreeWait:
        return 'figure.wave';
      case LiveRideActivityPhase.outsidePaidWait:
        return 'timer';
      case LiveRideActivityPhase.onTrip:
        return 'arrow.triangle.turn.up.right.diamond.fill';
      case LiveRideActivityPhase.paymentPending:
        return 'creditcard.fill';
      case LiveRideActivityPhase.paymentComplete:
        return 'checkmark.seal.fill';
    }
  }
}
