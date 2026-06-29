import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_runtime_providers.dart';
import '../screens/driver_runtime_gate_screen.dart';
import '../services/location_service.dart';
import '../utils/driver_network_guard.dart';
import '../utils/driver_go_online_onboarding.dart';
import 'driver_battery_optimization_prompt.dart';
import 'driver_runtime_decision_mapper.dart';
import 'driver_runtime_refresh.dart';

class DriverGoOnlineAttemptResult {
  const DriverGoOnlineAttemptResult._({
    required this.succeeded,
    this.gateArgs,
  });

  final bool succeeded;
  final DriverRuntimeGateArgs? gateArgs;

  bool get isBlocked => gateArgs != null;

  const DriverGoOnlineAttemptResult.succeeded() : this._(succeeded: true);

  const DriverGoOnlineAttemptResult.stopped() : this._(succeeded: false);

  const DriverGoOnlineAttemptResult.blocked(DriverRuntimeGateArgs args)
      : this._(succeeded: false, gateArgs: args);
}

/// Loads GPS then runs [attemptDriverGoOnline]. Shows a snackbar if location is unavailable.
Future<DriverGoOnlineAttemptResult> attemptDriverGoOnlineWithLocationGuard(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!await ensureDriverNetworkForAction(context, ref)) {
    return const DriverGoOnlineAttemptResult.stopped();
  }
  final position = await requestAndGetLocation();
  if (!context.mounted) return const DriverGoOnlineAttemptResult.stopped();
  if (position == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(DriverStrings.locationRequiredMessage)),
    );
    return const DriverGoOnlineAttemptResult.stopped();
  }
  return attemptDriverGoOnline(
    context: context,
    ref: ref,
    latitude: position.latitude,
    longitude: position.longitude,
  );
}

Future<DriverGoOnlineAttemptResult> attemptDriverGoOnline({
  required BuildContext context,
  required WidgetRef ref,
  required double latitude,
  required double longitude,
}) async {
  if (!await ensureDriverGoOnlineOnboarding(context, ref)) {
    return const DriverGoOnlineAttemptResult.stopped();
  }

  final runtimeService = ref.read(driverRuntimeServiceProvider);

  final readiness = await runtimeService.fetchReadiness();
  if (!readiness.canGoOnline) {
    return DriverGoOnlineAttemptResult.blocked(
      DriverRuntimeDecisionMapper.fromReadiness(readiness),
    );
  }

  if (!context.mounted) return const DriverGoOnlineAttemptResult.stopped();

  var skipBillingGate = readiness.gatesSkipped;
  if (!skipBillingGate) {
    try {
      final runtime = await runtimeService.fetchRuntime();
      skipBillingGate = runtime.config.skipGoOnlineGates;
      if (!skipBillingGate && !runtime.billingAllowed) {
        return const DriverGoOnlineAttemptResult.blocked(
          DriverRuntimeGateArgs(
            title: DriverStrings.runtimePaymentBlockedTitle,
            body: DriverStrings.runtimePaymentBlockedBody,
            ctaLabel: DriverStrings.runtimeOpenBilling,
            ctaRoute: '/driver/billing',
          ),
        );
      }
    } catch (_) {
      skipBillingGate =
          (readiness.statusMessage ?? '').toLowerCase().contains('test mode');
    }
  }

  final v1Decision = await runtimeService.setStatusV1(
    status: 'available',
    lat: latitude,
    lng: longitude,
  );
  if (v1Decision.isBlocked) {
    return DriverGoOnlineAttemptResult.blocked(
      DriverRuntimeDecisionMapper.fromStatusDecision(v1Decision),
    );
  }
  if (context.mounted) {
    unawaited(maybePromptDriverBatteryOptimization(context, ref));
  }
  unawaited(refreshDriverRuntime(ref));
  return const DriverGoOnlineAttemptResult.succeeded();
}
