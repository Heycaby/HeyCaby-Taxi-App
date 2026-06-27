import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_state_provider.dart';
import '../utils/driver_rider_cancelled_flow.dart';
import '../utils/driver_session_revoked_flow.dart';
import '../models/driver_shift_handover_prompt_args.dart';
import '../utils/driver_shift_handover_security_alert.dart';
import '../utils/driver_taxi_session_revoked_flow.dart';
import 'driver_fcm_payload.dart';
import 'driver_notification_router.dart';
import 'sound_service.dart';
import '../widgets/driver_shift_handover_prompt.dart';

/// Routes + side effects for driver FCM categories (Program 3C).
class DriverFcmHandler {
  const DriverFcmHandler._();

  static Future<void> dispatch({
    required DriverFcmPayload payload,
    required WidgetRef ref,
    required BuildContext context,
    required bool fromTap,
    bool foreground = false,
  }) async {
    final category = payload.effectiveCategory ?? '';
    switch (category) {
      case 'incoming_ride':
        await _handleIncomingRide(
          payload: payload,
          ref: ref,
          context: context,
          foreground: foreground,
        );
      case 'ride_phase':
        await _handleRidePhase(
          payload: payload,
          ref: ref,
          context: context,
        );
      case 'session_revoked':
        await handleDriverSessionRevoked(context: context, ref: ref);
      case 'shift_handover':
        final requestId = payload.requestId;
        if (requestId != null && requestId.isNotEmpty && context.mounted) {
          await showDriverShiftHandoverPrompt(
            context: context,
            ref: ref,
            args: DriverShiftHandoverPromptArgs.fromNotification(
              requestId: requestId,
              data: payload.rawData,
            ),
          );
        }
      case 'shift_handover_fleet':
      case 'shift_handover_private_attempt':
        if (context.mounted) {
          await showDriverShiftHandoverSecurityAlert(
            context: context,
            ref: ref,
            category: category,
            title: payload.title ?? '',
            body: payload.body ?? '',
          );
        }
      case 'taxi_session_revoked':
        if (context.mounted) {
          await handleDriverTaxiSessionRevoked(
            context: context,
            ref: ref,
            plate: payload.rawData?['plate']?.toString() ??
                payload.rawData?['plate_normalized']?.toString(),
            reason: payload.rawData?['reason']?.toString(),
            voluntaryEnd: payload.rawData?['status']?.toString() == 'approved',
          );
        }
      case 'chat':
        await dispatchDriverNotification(
          context: context,
          category: payload.effectiveCategory,
          title: '',
          body: '',
          data: {
            if (payload.rideRequestId != null)
              'ride_request_id': payload.rideRequestId,
          },
          fromTap: fromTap,
          foreground: foreground,
        );
      case 'rating':
        await dispatchDriverNotification(
          context: context,
          category: payload.effectiveCategory,
          title: '',
          body: '',
          data: null,
          fromTap: fromTap,
          foreground: foreground,
        );
      default:
        await dispatchDriverNotification(
          context: context,
          category: payload.effectiveCategory,
          title: '',
          body: '',
          data: {
            if (payload.rideRequestId != null)
              'ride_request_id': payload.rideRequestId,
          },
          fromTap: fromTap,
          foreground: foreground,
        );
    }
  }

  static Future<void> _handleIncomingRide({
    required DriverFcmPayload payload,
    required WidgetRef ref,
    required BuildContext context,
    required bool foreground,
  }) async {
    final rideId = payload.rideRequestId;
    if (rideId == null || rideId.isEmpty) return;

    final appState = ref.read(driverStateProvider).appState;
    if (appState != DriverAppState.onlineAvailable) return;

    if (!context.mounted) return;
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/driver/ride/new/')) return;
    if (path.contains('/driver/ride/new/$rideId')) return;

    HapticService.heavyTap();
    if (foreground) {
      unawaited(SoundService().playRideRequest());
    }

    if (!context.mounted) return;
    context.push('/driver/ride/new/$rideId');
  }

  static Future<void> _handleRidePhase({
    required DriverFcmPayload payload,
    required WidgetRef ref,
    required BuildContext context,
  }) async {
    final rideId = payload.rideRequestId;
    if (rideId == null || rideId.isEmpty) return;
    await handleDriverRiderCancelled(
      ref: ref,
      context: context,
      rideId: rideId,
    );
  }
}
