import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../services/driver_ping_cooldown.dart';

/// Sends a first-class driver ping (audit + FCM). No phone numbers.
Future<DriverPingSendResult> sendDriverRiderPing({
  required BuildContext context,
  required WidgetRef ref,
  required String rideRequestId,
  required DriverPingType type,
  int? etaMinutes,
  bool silent = false,
}) async {
  if (!DriverPingCooldown.canSend(rideRequestId, type.apiKind)) {
    final remaining = DriverPingCooldown.remaining(rideRequestId, type.apiKind);
    final secs = remaining?.inSeconds ?? 30;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.pingCooldownMessage(secs))),
      );
    }
    return DriverPingSendResult.cooldown;
  }

  HapticService.mediumTap();
  try {
    final response = await HeyCabySupabase.client.functions.invoke(
      'driver-agent',
      body: {
        'event': 'driver_ping',
        'ride_request_id': rideRequestId,
        'kind': type.apiKind,
        if (etaMinutes != null) 'eta_minutes': etaMinutes,
      },
    );
    final delivery = _DriverPingDelivery.from(response.data);
    if (!delivery.ok) {
      if (delivery.error == 'ping_cooldown') {
        DriverPingCooldown.markSent(rideRequestId, type.apiKind);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                DriverStrings.pingCooldownMessage(
                  delivery.retryAfterSeconds ?? 30,
                ),
              ),
            ),
          );
        }
        return DriverPingSendResult.cooldown;
      }
      if (!context.mounted) return DriverPingSendResult.failed;
      HapticService.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForPingError(delivery.error))),
      );
      return DriverPingSendResult.failed;
    }

    DriverPingCooldown.markSent(rideRequestId, type.apiKind);
    if (!context.mounted) return DriverPingSendResult.success;
    if (!silent) {
      HapticService.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.pingRiderSent)),
      );
    }
    return DriverPingSendResult.success;
  } on Exception catch (e) {
    final msg = e.toString();
    if (msg.contains('ping_cooldown') || msg.contains('429')) {
      DriverPingCooldown.markSent(rideRequestId, type.apiKind);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.pingCooldownMessage(30))),
        );
      }
      return DriverPingSendResult.cooldown;
    }
    if (!context.mounted) return DriverPingSendResult.failed;
    HapticService.error();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_messageForPingError(_errorFromException(msg)))),
    );
    return DriverPingSendResult.failed;
  } catch (_) {
    if (!context.mounted) return DriverPingSendResult.failed;
  }

  if (!context.mounted) return DriverPingSendResult.failed;
  HapticService.error();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(DriverStrings.pingRiderFailed)),
  );
  return DriverPingSendResult.failed;
}

enum DriverPingSendResult { success, cooldown, failed }

String _messageForPingError(String? error) {
  switch (error) {
    case 'ride_not_active':
      return DriverStrings.pingRideNotActive;
    case 'ride_not_found':
    case 'missing_rider':
    case 'missing_recipient':
      return DriverStrings.pingRideContextMissing;
    case 'unauthorized':
    case 'Unauthorized':
      return DriverStrings.pingUnauthorized;
    case 'invalid_ping_kind':
    case 'notification_insert_failed':
      return DriverStrings.pingServerRejected;
    default:
      return DriverStrings.pingRiderFailed;
  }
}

String? _errorFromException(String message) {
  const known = [
    'ride_not_active',
    'ride_not_found',
    'missing_rider',
    'missing_recipient',
    'unauthorized',
    'Unauthorized',
    'invalid_ping_kind',
    'notification_insert_failed',
  ];
  for (final value in known) {
    if (message.contains(value)) return value;
  }
  return null;
}

class _DriverPingDelivery {
  const _DriverPingDelivery({
    required this.ok,
    this.error,
    this.retryAfterSeconds,
  });

  final bool ok;
  final String? error;
  final int? retryAfterSeconds;

  factory _DriverPingDelivery.from(Object? data) {
    if (data is Map) {
      final ok = data['ok'] == true;
      final error =
          data['error']?.toString() ?? (ok ? null : data['reason']?.toString());
      final retry = data['retry_after_seconds'];
      return _DriverPingDelivery(
        ok: ok && error == null,
        error: error,
        retryAfterSeconds: retry is num ? retry.round() : null,
      );
    }

    // Older deployed driver-agent versions returned plain text "OK".
    // Treat that as success so device builds remain compatible during rollout.
    return const _DriverPingDelivery(ok: true);
  }
}
