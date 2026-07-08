import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_state_provider.dart';
import '../services/sound_service.dart';

final _handledRiderCancelRideIds = <String>{};

/// Dedupes FCM + realtime + poll for the same cancellation.
bool markRiderCancelHandled(String rideId) =>
    _handledRiderCancelRideIds.add(rideId);

bool shouldHandleRiderCancel({
  required String rideId,
  required DriverData state,
  required String path,
}) {
  if (state.activeRideId == rideId) return true;
  return path.contains(rideId);
}

/// L1-3 — full-screen modal, clear ride, return home.
Future<void> handleDriverRiderCancelled({
  required WidgetRef ref,
  required BuildContext context,
  required String rideId,
}) async {
  if (!context.mounted) return;

  final state = ref.read(driverStateProvider);
  final path = GoRouterState.of(context).uri.path;
  if (!shouldHandleRiderCancel(rideId: rideId, state: state, path: path)) {
    return;
  }
  if (!markRiderCancelHandled(rideId)) return;

  SoundService().stopRideRequest();
  unawaited(SoundService().playRiderCancelled());
  HapticService.heavyTap();

  ref.read(driverStateProvider.notifier).clearActiveRide();
  ref.invalidate(driverShiftStatsProvider);
  ref.invalidate(driverEarningsProvider);

  if (!context.mounted) return;
  await showDriverRiderCancelledModal(context, ref);
  if (!context.mounted) return;
  context.go('/driver');
}

Future<void> showDriverRiderCancelledModal(
  BuildContext context,
  WidgetRef ref,
) {
  final themeColors = ref.read(colorsProvider);
  final typo = ref.read(typographyProvider);
  return showHeyCabyAcknowledgeSheet(
    context,
    colors: themeColors,
    typography: typo,
    title: DriverStrings.riderCancelledTitle,
    message: DriverStrings.riderCancelledBody,
    actionLabel: DriverStrings.riderCancelledCta,
    icon: Icons.person_off_outlined,
    iconColor: themeColors.warning,
    barrierDismissible: false,
  );
}
