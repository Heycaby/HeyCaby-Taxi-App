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
    await HeyCabySupabase.client.functions.invoke(
      'driver-agent',
      body: {
        'event': 'driver_ping',
        'ride_request_id': rideRequestId,
        'kind': type.apiKind,
        if (etaMinutes != null) 'eta_minutes': etaMinutes,
      },
    );
    DriverPingCooldown.markSent(rideRequestId, type.apiKind);
    if (!context.mounted) return DriverPingSendResult.success;
    HapticService.success();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(DriverStrings.pingRiderSent)),
    );
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
