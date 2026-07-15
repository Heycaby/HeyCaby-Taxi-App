import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

enum DriverAppState {
  loggedOut,
  onboardingIncomplete,
  offline,
  goingOnline,
  onlineAvailable,
  reviewingRequest,
  acceptingRide,
  assigned,
  arrived,
  inProgress,
  completingRide,
  completed,
  onBreak,
  errorRecovery,
}

@immutable
class DriverData {
  final DriverAppState appState;
  final String? driverId;
  final String? userId;
  final String? activeRideId;
  final String? riderContactName;
  final String? riderPaymentMethod;
  final String? bookingMode;
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? destinationAddress;
  final double? destinationLat;
  final double? destinationLng;
  final String? bookedDestinationAddress;
  final double? bookedDestinationLat;
  final double? bookedDestinationLng;
  final List<ActiveRideRouteStop> routeStops;
  final int routeRevision;
  final PendingRouteChange? pendingRouteChange;
  final bool radarActive;
  final bool pendingBreak;

  const DriverData({
    this.appState = DriverAppState.loggedOut,
    this.driverId,
    this.userId,
    this.activeRideId,
    this.riderContactName,
    this.riderPaymentMethod,
    this.bookingMode,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.destinationAddress,
    this.destinationLat,
    this.destinationLng,
    this.bookedDestinationAddress,
    this.bookedDestinationLat,
    this.bookedDestinationLng,
    this.routeStops = const [],
    this.routeRevision = 0,
    this.pendingRouteChange,
    this.radarActive = false,
    this.pendingBreak = false,
  });

  DriverData copyWith({
    DriverAppState? appState,
    String? driverId,
    String? userId,
    String? activeRideId,
    String? riderContactName,
    String? riderPaymentMethod,
    String? bookingMode,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? destinationAddress,
    double? destinationLat,
    double? destinationLng,
    String? bookedDestinationAddress,
    double? bookedDestinationLat,
    double? bookedDestinationLng,
    List<ActiveRideRouteStop>? routeStops,
    int? routeRevision,
    PendingRouteChange? pendingRouteChange,
    bool clearPendingRouteChange = false,
    bool? radarActive,
    bool? pendingBreak,
  }) =>
      DriverData(
        appState: appState ?? this.appState,
        driverId: driverId ?? this.driverId,
        userId: userId ?? this.userId,
        activeRideId: activeRideId ?? this.activeRideId,
        riderContactName: riderContactName ?? this.riderContactName,
        riderPaymentMethod: riderPaymentMethod ?? this.riderPaymentMethod,
        bookingMode: bookingMode ?? this.bookingMode,
        pickupAddress: pickupAddress ?? this.pickupAddress,
        pickupLat: pickupLat ?? this.pickupLat,
        pickupLng: pickupLng ?? this.pickupLng,
        destinationAddress: destinationAddress ?? this.destinationAddress,
        destinationLat: destinationLat ?? this.destinationLat,
        destinationLng: destinationLng ?? this.destinationLng,
        bookedDestinationAddress:
            bookedDestinationAddress ?? this.bookedDestinationAddress,
        bookedDestinationLat: bookedDestinationLat ?? this.bookedDestinationLat,
        bookedDestinationLng: bookedDestinationLng ?? this.bookedDestinationLng,
        routeStops: routeStops ?? this.routeStops,
        routeRevision: routeRevision ?? this.routeRevision,
        pendingRouteChange: clearPendingRouteChange
            ? null
            : (pendingRouteChange ?? this.pendingRouteChange),
        radarActive: radarActive ?? this.radarActive,
        pendingBreak: pendingBreak ?? this.pendingBreak,
      );

  static DriverData empty() =>
      const DriverData(appState: DriverAppState.loggedOut);

  ActiveRideRouteState get activeRouteState => ActiveRideRouteState(
        destinationAddress: destinationAddress ?? '',
        destinationLat: destinationLat,
        destinationLng: destinationLng,
        bookedDestinationAddress: bookedDestinationAddress,
        bookedDestinationLat: bookedDestinationLat,
        bookedDestinationLng: bookedDestinationLng,
        stops: routeStops,
        routeRevision: routeRevision,
        pendingRouteChange: pendingRouteChange,
      );
}

class DriverStateNotifier extends Notifier<DriverData> {
  @override
  DriverData build() => DriverData.empty();

  void setStatus(DriverAppState appState) =>
      state = state.copyWith(appState: appState);

  void setPendingBreak(bool value) =>
      state = state.copyWith(pendingBreak: value);

  /// Returns true if [clearActiveRide] consumed a pending break.
  bool consumePendingBreak() {
    final wasPending = state.pendingBreak;
    if (wasPending) {
      state = state.copyWith(pendingBreak: false);
    }
    return wasPending;
  }

  void setActiveRide({
    required String rideId,
    required String? paymentMethod,
    required String? pickupAddress,
    required double? pickupLat,
    required double? pickupLng,
    required String? destinationAddress,
    required double? destLat,
    required double? destLng,
    required String? bookingMode,
    required String? riderName,
  }) =>
      state = state.copyWith(
        activeRideId: rideId,
        riderPaymentMethod: paymentMethod,
        pickupAddress: pickupAddress,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        destinationAddress: destinationAddress,
        destinationLat: destLat,
        destinationLng: destLng,
        bookedDestinationAddress: destinationAddress,
        bookedDestinationLat: destLat,
        bookedDestinationLng: destLng,
        routeStops: const [],
        routeRevision: 0,
        pendingRouteChange: null,
        bookingMode: bookingMode,
        riderContactName: riderName,
        appState: DriverAppState.assigned,
      );

  void patchActiveRouteFromRow(Map<String, dynamic> row) {
    final route = ActiveRideRouteState.fromRideRow(row);
    if (route.destinationAddress.isEmpty) return;
    state = state.copyWith(
      destinationAddress: route.destinationAddress,
      destinationLat: route.destinationLat,
      destinationLng: route.destinationLng,
      bookedDestinationAddress:
          route.bookedDestinationAddress ?? state.bookedDestinationAddress,
      bookedDestinationLat:
          route.bookedDestinationLat ?? state.bookedDestinationLat,
      bookedDestinationLng:
          route.bookedDestinationLng ?? state.bookedDestinationLng,
      routeStops: route.stops,
      routeRevision: route.routeRevision,
      pendingRouteChange: route.pendingRouteChange,
      clearPendingRouteChange: true,
    );
  }

  void patchRideCoords({
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
  }) =>
      state = state.copyWith(
        pickupLat: pickupLat ?? state.pickupLat,
        pickupLng: pickupLng ?? state.pickupLng,
        destinationLat: destinationLat ?? state.destinationLat,
        destinationLng: destinationLng ?? state.destinationLng,
      );

  void clearActiveRide({DriverAppState? nextState}) {
    final wasPendingBreak = consumePendingBreak();
    state = DriverData(
      appState: wasPendingBreak
          ? DriverAppState.onBreak
          : (nextState ?? DriverAppState.onlineAvailable),
      driverId: state.driverId,
      userId: state.userId,
      radarActive: state.radarActive,
      pendingBreak: state.pendingBreak,
    );
  }

  /// Program 3B — apply server snapshot after cold start / login.
  void applyOperationalRestore({
    required DriverAppState appState,
    String? activeRideId,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? destinationAddress,
    double? destinationLat,
    double? destinationLng,
    String? bookedDestinationAddress,
    double? bookedDestinationLat,
    double? bookedDestinationLng,
    List<ActiveRideRouteStop>? routeStops,
    int? routeRevision,
    String? bookingMode,
    String? paymentMethod,
    String? riderContactName,
    bool clearActiveRide = false,
  }) {
    if (clearActiveRide) {
      state = DriverData(
        appState: appState,
        driverId: state.driverId,
        userId: state.userId,
        radarActive: state.radarActive,
      );
      return;
    }
    state = DriverData(
      appState: appState,
      driverId: state.driverId,
      userId: state.userId,
      activeRideId: activeRideId,
      pickupAddress: pickupAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destinationAddress: destinationAddress,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      bookedDestinationAddress:
          bookedDestinationAddress ?? destinationAddress,
      bookedDestinationLat: bookedDestinationLat ?? destinationLat,
      bookedDestinationLng: bookedDestinationLng ?? destinationLng,
      routeStops: routeStops ?? const [],
      routeRevision: routeRevision ?? 0,
      bookingMode: bookingMode,
      riderPaymentMethod: paymentMethod,
      riderContactName: riderContactName,
      radarActive: state.radarActive,
    );
  }

  void setUser(String userId, String? driverId) => state = state.copyWith(
        userId: userId,
        driverId: driverId ?? state.driverId,
      );

  void logout() => state = DriverData.empty();
}

final driverStateProvider =
    NotifierProvider<DriverStateNotifier, DriverData>(DriverStateNotifier.new);
