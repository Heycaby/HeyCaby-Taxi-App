import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_runtime_models.dart';
import '../providers/driver_data_providers.dart';
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
  if (!context.mounted) return const DriverGoOnlineAttemptResult.stopped();
  if (!readiness.canGoOnline) {
    if (_hasMissingInitialTariff(readiness)) {
      await _showInitialTariffSetupSheet(context, ref);
      return const DriverGoOnlineAttemptResult.stopped();
    }
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
        return DriverGoOnlineAttemptResult.blocked(
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
  if (!context.mounted) return const DriverGoOnlineAttemptResult.stopped();
  if (v1Decision.isBlocked) {
    if (v1Decision.blockedReason == 'missing_tariff' ||
        v1Decision.redirect == '/driver/tariffs') {
      await _showInitialTariffSetupSheet(context, ref);
      return const DriverGoOnlineAttemptResult.stopped();
    }
    return DriverGoOnlineAttemptResult.blocked(
      DriverRuntimeDecisionMapper.fromStatusDecision(v1Decision),
    );
  }
  if (v1Decision.status != 'available') {
    return DriverGoOnlineAttemptResult.blocked(
      DriverRuntimeGateArgs(
        title: DriverStrings.goOnlineFailed,
        body: v1Decision.message ?? DriverStrings.failedToUpdateStatus,
        ctaLabel: DriverStrings.tryAgain,
      ),
    );
  }
  if (context.mounted) {
    unawaited(maybePromptDriverBatteryOptimization(context, ref));
  }
  unawaited(DriverLocationService().startTracking());
  unawaited(refreshDriverRuntime(ref));
  return const DriverGoOnlineAttemptResult.succeeded();
}

bool _hasMissingInitialTariff(DriverReadinessState readiness) {
  return readiness.missingItems.any((item) => item.key == 'initial_tariff');
}

Future<void> _showInitialTariffSetupSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!context.mounted) return;

  final kmController = TextEditingController(text: '2.00');
  final minuteController = TextEditingController(text: '0.35');
  final startController = TextEditingController(text: '2.50');
  final vatController = TextEditingController(text: '9');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      var saving = false;
      return StatefulBuilder(
        builder: (context, setState) {
          final inset = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, inset + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  DriverStrings.initialTariffTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  DriverStrings.initialTariffBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 20),
                _InitialTariffField(
                  controller: kmController,
                  label: DriverStrings.initialTariffPricePerKm,
                ),
                const SizedBox(height: 12),
                _InitialTariffField(
                  controller: minuteController,
                  label: DriverStrings.initialTariffPricePerMinute,
                ),
                const SizedBox(height: 12),
                _InitialTariffField(
                  controller: startController,
                  label: DriverStrings.initialTariffStartFee,
                ),
                const SizedBox(height: 12),
                _InitialTariffField(
                  controller: vatController,
                  label: DriverStrings.initialTariffVat,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final perKm = _parseAmount(kmController.text);
                          final perMin = _parseAmount(minuteController.text);
                          final startFee = _parseAmount(startController.text);
                          final vat = _parseAmount(vatController.text);
                          final valid = perKm != null &&
                              perKm > 0 &&
                              perMin != null &&
                              perMin >= 0 &&
                              startFee != null &&
                              startFee >= 0 &&
                              vat != null &&
                              vat >= 0 &&
                              vat <= 100;
                          if (!valid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text(DriverStrings.initialTariffInvalid),
                              ),
                            );
                            return;
                          }

                          setState(() => saving = true);
                          final driverId =
                              await ref.read(driverIdProvider.future);
                          if (driverId == null) {
                            setState(() => saving = false);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text(DriverStrings.initialTariffFailed),
                              ),
                            );
                            return;
                          }

                          final profile = await ref
                              .read(driverDataServiceProvider)
                              .createInitialRateProfile(
                                driverId: driverId,
                                baseFare: startFee,
                                perKmRate: perKm,
                                perMinRate: perMin,
                                vatPercentage: vat,
                              );
                          if (!context.mounted) return;
                          setState(() => saving = false);
                          if (profile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text(DriverStrings.initialTariffFailed),
                              ),
                            );
                            return;
                          }

                          ref.invalidate(driverRateProfilesProvider);
                          ref.invalidate(activeRateProfileProvider);
                          ref.invalidate(driverRuntimeSnapshotProvider);
                          ref.invalidate(driverReadinessProvider);
                          unawaited(refreshDriverRuntime(ref));
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(DriverStrings.initialTariffSaved),
                            ),
                          );
                        },
                  child: Text(
                    saving
                        ? DriverStrings.initialTariffSaving
                        : DriverStrings.initialTariffSave,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  kmController.dispose();
  minuteController.dispose();
  startController.dispose();
  vatController.dispose();
}

double? _parseAmount(String raw) {
  return double.tryParse(raw.trim().replaceAll(',', '.'));
}

class _InitialTariffField extends StatelessWidget {
  const _InitialTariffField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
      ),
    );
  }
}
