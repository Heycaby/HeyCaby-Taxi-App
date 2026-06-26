import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final bool radarActive;

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
    this.radarActive = false,
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
    bool? radarActive,
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
        radarActive: radarActive ?? this.radarActive,
      );

  static DriverData empty() =>
      const DriverData(appState: DriverAppState.loggedOut);
}

class DriverStateNotifier extends Notifier<DriverData> {
  @override
  DriverData build() => DriverData.empty();

  void setStatus(DriverAppState appState) =>
      state = state.copyWith(appState: appState);

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
        bookingMode: bookingMode,
        riderContactName: riderName,
        appState: DriverAppState.assigned,
      );

  void clearActiveRide({DriverAppState? nextState}) {
    state = DriverData(
      appState: nextState ?? DriverAppState.onlineAvailable,
      driverId: state.driverId,
      userId: state.userId,
      radarActive: state.radarActive,
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
