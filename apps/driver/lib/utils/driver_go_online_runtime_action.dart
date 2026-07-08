import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_runtime_models.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_runtime_providers.dart';
import '../screens/driver_runtime_gate_screen.dart';
import '../services/location_service.dart';
import '../theme/driver_colors.dart';
import '../widgets/driver_ride_premium_style.dart';
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

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _InitialTariffSetupSheet(
      parentContext: context,
    ),
  );
}

class _InitialTariffSetupSheet extends ConsumerStatefulWidget {
  const _InitialTariffSetupSheet({
    required this.parentContext,
  });

  final BuildContext parentContext;

  @override
  ConsumerState<_InitialTariffSetupSheet> createState() =>
      _InitialTariffSetupSheetState();
}

class _InitialTariffSetupSheetState
    extends ConsumerState<_InitialTariffSetupSheet> {
  late final TextEditingController _startController;
  late final TextEditingController _kmController;
  late final TextEditingController _minuteController;
  late final TextEditingController _waitController;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: '2.50');
    _kmController = TextEditingController(text: '2.00');
    _minuteController = TextEditingController(text: '0.35');
    _waitController = TextEditingController(text: '0.25');
  }

  @override
  void dispose() {
    _startController.dispose();
    _kmController.dispose();
    _minuteController.dispose();
    _waitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final startFee = _parseAmount(_startController.text);
    final perKm = _parseAmount(_kmController.text);
    final perMin = _parseAmount(_minuteController.text);
    final waitingRate = _parseAmount(_waitController.text);
    final valid = startFee != null &&
        startFee >= 0 &&
        perKm != null &&
        perKm > 0 &&
        perMin != null &&
        perMin >= 0 &&
        waitingRate != null &&
        waitingRate >= 0;
    if (!valid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.initialTariffInvalid)),
      );
      return;
    }

    setState(() => _saving = true);
    final driverId = await ref.read(driverIdProvider.future);
    if (!mounted) return;
    if (driverId == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.initialTariffFailed)),
      );
      return;
    }

    final profile = await ref.read(driverDataServiceProvider).createInitialRateProfile(
          driverId: driverId,
          baseFare: startFee,
          perKmRate: perKm,
          perMinRate: perMin,
          waitingRate: waitingRate,
        );
    if (!mounted) return;
    if (profile == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.initialTariffFailed)),
      );
      return;
    }

    Navigator.of(context).pop();
    if (!widget.parentContext.mounted) return;
    ref.invalidate(driverRateProfilesProvider);
    ref.invalidate(activeRateProfileProvider);
    ref.invalidate(driverRuntimeSnapshotProvider);
    ref.invalidate(driverReadinessProvider);
    unawaited(refreshDriverRuntime(ref));
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(content: Text(DriverStrings.initialTariffSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final colors = DriverColors.fromTheme(
      ref.watch(colorsProvider),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, inset + 12),
      child: DriverRidePremiumStyle.glassSurface(
        colors: colors,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        blurSigma: 26,
        tintOpacity: 0.82,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                DriverStrings.initialTariffTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                DriverStrings.initialTariffBody,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 20),
              _InitialTariffField(
                controller: _startController,
                label: DriverStrings.initialTariffStartFee,
              ),
              const SizedBox(height: 12),
              _InitialTariffField(
                controller: _kmController,
                label: DriverStrings.initialTariffPricePerKm,
              ),
              const SizedBox(height: 12),
              _InitialTariffField(
                controller: _minuteController,
                label: DriverStrings.initialTariffPricePerMinute,
              ),
              const SizedBox(height: 12),
              _InitialTariffField(
                controller: _waitController,
                label: DriverStrings.initialTariffWaitingRate,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving
                      ? DriverStrings.initialTariffSaving
                      : DriverStrings.initialTariffSave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
