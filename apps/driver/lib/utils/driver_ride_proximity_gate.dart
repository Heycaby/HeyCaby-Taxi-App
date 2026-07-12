import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

Future<bool> checkDriverRideProximity({
  required BuildContext context,
  required WidgetRef ref,
  required String rideId,
  required String action,
  Future<void> Function()? onExitRide,
}) async {
  final result = await ref.read(driverApiProvider).checkRideActionProximity(
        rideRequestId: rideId,
        action: action,
      );
  if (result['ok'] != true) {
    throw DriverRideLifecycleException(
      result['error']?.toString() ?? 'proximity_unavailable',
    );
  }
  if (result['allowed'] == true) return true;
  if (!context.mounted) return false;

  final meters = (result['distance_m'] as num?)?.round() ?? 0;
  final distance =
      meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '$meters m';
  final isDropoff = action == 'complete_dropoff';
  final colors = ref.read(colorsProvider);
  final typography = ref.read(typographyProvider);
  final continueCloser = await showHeyCabyConfirmSheet(
    context,
    colors: colors,
    typography: typography,
    title: isDropoff ? DriverStrings.destination : DriverStrings.pickupAddress,
    message: isDropoff
        ? DriverStrings.distanceFromDropoff(distance)
        : DriverStrings.distanceFromPickup(distance),
    dismissLabel: isDropoff && onExitRide != null
        ? DriverStrings.stillCancelRide
        : DriverStrings.back,
    confirmLabel: DriverStrings.continueCurrentRide,
    icon: Icons.near_me_rounded,
  );
  if (continueCloser == false && isDropoff && onExitRide != null) {
    await onExitRide();
  }
  return false;
}
