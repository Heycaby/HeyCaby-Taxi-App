import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_runtime_models.dart';
import '../models/driver_start_shift_args.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_runtime_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_status_badge.dart';
import '../utils/driver_go_online_onboarding.dart';
import '../utils/driver_readiness_routes.dart';
import '../widgets/driver_shift_handover_step_up_sheet.dart';
import '../screens/driver_shift_handover_waiting_screen.dart';
import '../widgets/driver_settings_flow_common.dart';

/// Confirms starting a shift when this taxi already has an active HeyCaby session.
class DriverStartShiftScreen extends ConsumerStatefulWidget {
  const DriverStartShiftScreen({
    super.key,
    required this.args,
  });

  final DriverStartShiftArgs args;

  @override
  ConsumerState<DriverStartShiftScreen> createState() =>
      _DriverStartShiftScreenState();
}

class _DriverStartShiftScreenState
    extends ConsumerState<DriverStartShiftScreen> {
  bool _starting = false;

  void _openFirstMissingRequirement(List<DriverReadinessItem> missing) {
    if (missing.isEmpty) return;
    final route = flutterRouteForReadinessItem(missing.first);
    if (route == null || route.isEmpty) return;
    HapticService.selectionClick();
    context.push(route);
  }

  Future<void> _startShift() async {
    if (_starting) return;
    setState(() => _starting = true);
    HapticService.mediumTap();

    final args = widget.args;
    final svc = ref.read(driverDataServiceProvider);

    final stepUpId = await showDriverShiftHandoverStepUpSheet(
      context: context,
      ref: ref,
    );
    if (!mounted) return;
    if (stepUpId == null || stepUpId.isEmpty) {
      setState(() => _starting = false);
      return;
    }

    final res = await svc.requestShiftHandover(
      vehiclePlate: args.vehiclePlate,
      vehiclePlateEntered: args.vehiclePlateEntered,
      rdwSnapshot: args.rdwSnapshot,
      vehicleVerificationStatus: args.vehicleVerificationStatus,
      stepUpId: stepUpId,
    );

    if (!mounted) return;

    if (res?['ok'] == true && res?['request_id'] != null) {
      final requestId = res!['request_id'].toString();
      final expiresRaw = res['expires_at']?.toString();
      final expiresAt = expiresRaw != null
          ? DateTime.tryParse(expiresRaw)?.toUtc() ??
              DateTime.now().toUtc().add(const Duration(minutes: 2))
          : DateTime.now().toUtc().add(const Duration(minutes: 2));
      setState(() => _starting = false);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DriverShiftHandoverWaitingScreen(
            args: args,
            requestId: requestId,
            expiresAt: expiresAt,
          ),
        ),
      );
      return;
    }

    if (res?['direct_claim'] == true ||
        res?['error']?.toString() == 'no_active_session') {
      final claim = await svc.claimVehiclePlateV2(
        vehiclePlate: args.vehiclePlate,
        vehiclePlateEntered: args.vehiclePlateEntered,
        rdwSnapshot: args.rdwSnapshot,
        vehicleVerificationStatus: args.vehicleVerificationStatus,
      );
      if (!mounted) return;
      if (claim?['success'] == true) {
        ref.invalidate(driverProfileProvider);
        ref.invalidate(driverComplianceProvider);
        await continueDriverGoOnlineOnboarding(
          context: context,
          ref: ref,
          resumeGoOnline: args.resumeGoOnline,
        );
        return;
      }
    }

    setState(() => _starting = false);
    if (!mounted) return;
    final message = _handoverErrorMessage(res);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _handoverErrorMessage(Map<String, dynamic>? res) {
    final err = res?['error']?.toString() ?? '';
    final missing = _missingItemsFromResponse(res);
    if (missing.isNotEmpty) {
      return _messageForRequirement(missing.first);
    }
    if (err == 'active_ride_in_progress') {
      return DriverStrings.shiftHandoverActiveRideMessage;
    }
    if (err == 'private_taxi_owner_only') {
      return res?['message']?.toString() ??
          DriverStrings.shiftHandoverPrivateBlockedMessage;
    }
    if (err == 'step_up_required') {
      return DriverStrings.shiftHandoverStepUpRequired;
    }
    if (err == 'handover_cooldown' || err == 'handover_blocked') {
      return res?['message']?.toString() ??
          DriverStrings.shiftHandoverRateLimitedMessage;
    }
    if (err == 'handover_not_eligible') {
      return res?['message']?.toString() ??
          DriverStrings.shiftHandoverNotEligibleMessage;
    }
    if (err == 'handover_not_allowlisted') {
      return res?['message']?.toString() ??
          DriverStrings.shiftHandoverNotAllowlistedMessage;
    }
    final msg = res?['message']?.toString();
    if (msg != null && msg.isNotEmpty) return msg;
    return DriverStrings.onboardingPlateSaveFailed;
  }

  List<DriverReadinessItem> _missingItemsFromResponse(
    Map<String, dynamic>? res,
  ) {
    final readinessRaw = res?['readiness'];
    final filtered = res?['missing_requirements'];
    final raw = filtered is List
        ? filtered
        : readinessRaw is Map
            ? readinessRaw['checklist']
            : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => DriverReadinessItem.fromJson(
              item.cast<String, dynamic>(),
            ))
        .where((item) => !item.complete)
        .toList(growable: false);
  }

  String _messageForRequirement(DriverReadinessItem item) {
    switch (item.key.trim()) {
      case 'profile_photo':
        return DriverStrings.runtimeMissingProfilePhoto;
      case 'vehicle_photos':
        return DriverStrings.runtimeMissingVehiclePhoto;
      case 'vehicle_plate':
        return DriverStrings.runtimeMissingTaxiVerification;
      case 'terms_of_service':
      case 'indemnification_quiz':
        return DriverStrings.runtimeMissingTerms;
      case 'rijbewijs_verified':
        return DriverStrings.runtimeMissingIdentity;
      case 'initial_tariff':
        return DriverStrings.runtimeMissingInitialTariff;
      default:
        return item.label.trim().isEmpty
            ? DriverStrings.shiftHandoverNotEligibleMessage
            : DriverStrings.runtimeMissingGeneric(item.label);
    }
  }

  void _cancel() {
    if (_starting) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final args = widget.args;
    final vehicleLine = [
      args.vehicleMake,
      args.vehicleModel,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
    final runtimeAsync = ref.watch(driverRuntimeSnapshotProvider);
    final runtime = runtimeAsync.valueOrNull;
    final checkingReadiness = runtimeAsync.isLoading && !runtimeAsync.hasValue;
    final missing =
        runtime?.readiness.missingItems ?? const <DriverReadinessItem>[];
    final blockedByReadiness = runtime?.ok == true && missing.isNotEmpty;

    return DriverSettingsFlowScaffold(
      title: DriverStrings.startShiftFlowTitle,
      colors: colors,
      typography: typography,
      centerTitle: true,
      onBack: _cancel,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DriverSpacing.screenEdge,
                  DriverSpacing.lg,
                  DriverSpacing.screenEdge,
                  DriverSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DriverCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.badgeCheck,
                                color: colors.success,
                                size: 22,
                              ),
                              const SizedBox(width: DriverSpacing.sm),
                              Expanded(
                                child: Text(
                                  DriverStrings.startShiftVerifiedTitle,
                                  style: typography.titleSmall.copyWith(
                                    color: colors.text,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              DriverStatusBadge(
                                label: DriverStrings.statusVerified,
                                colors: colors,
                                typography: typography,
                                tone: DriverStatusTone.success,
                              ),
                            ],
                          ),
                          if (vehicleLine.isNotEmpty) ...[
                            const SizedBox(height: DriverSpacing.md),
                            Text(
                              vehicleLine,
                              style: typography.titleMedium.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: DriverSpacing.sm),
                          Text(
                            DriverStrings.vehiclePlate,
                            style: typography.labelSmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: DriverSpacing.xs),
                          Text(
                            args.vehiclePlateEntered.trim().isNotEmpty
                                ? args.vehiclePlateEntered
                                : args.vehiclePlate,
                            style: typography.headlineSmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.xl),
                    Text(
                      DriverStrings.startShiftActiveTitle,
                      style: typography.headlineSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    Text(
                      DriverStrings.startShiftActiveBody,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    Text(
                      DriverStrings.startShiftActiveFootnote,
                      style: typography.bodyMedium.copyWith(
                        color: colors.text,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (blockedByReadiness) ...[
                      const SizedBox(height: DriverSpacing.xl),
                      _HandoverRequirementsCard(
                        missing: missing,
                        colors: colors,
                        typography: typography,
                        onOpen: _openFirstMissingRequirement,
                        messageForRequirement: _messageForRequirement,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DriverSpacing.screenEdge,
                DriverSpacing.sm,
                DriverSpacing.screenEdge,
                DriverSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DriverButton(
                    label: checkingReadiness
                        ? DriverStrings.shiftHandoverCheckingRequirements
                        : blockedByReadiness
                            ? DriverStrings.shiftHandoverCompleteRequirements
                            : DriverStrings.startShiftPrimary,
                    onPressed: _starting || checkingReadiness
                        ? null
                        : blockedByReadiness
                            ? () => _openFirstMissingRequirement(missing)
                            : _startShift,
                    loading: _starting || checkingReadiness,
                    colors: colors,
                    typography: typography,
                    size: DriverButtonSize.lg,
                    icon: blockedByReadiness
                        ? LucideIcons.listChecks
                        : LucideIcons.play,
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  DriverButton(
                    label: DriverStrings.cancel,
                    onPressed: _starting ? null : _cancel,
                    variant: DriverButtonVariant.outline,
                    colors: colors,
                    typography: typography,
                    size: DriverButtonSize.lg,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandoverRequirementsCard extends StatelessWidget {
  const _HandoverRequirementsCard({
    required this.missing,
    required this.colors,
    required this.typography,
    required this.onOpen,
    required this.messageForRequirement,
  });

  final List<DriverReadinessItem> missing;
  final DriverColors colors;
  final DriverTypography typography;
  final ValueChanged<List<DriverReadinessItem>> onOpen;
  final String Function(DriverReadinessItem item) messageForRequirement;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  LucideIcons.shieldAlert,
                  color: colors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverStrings.shiftHandoverRequirementsTitle,
                      style: typography.titleSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.xs),
                    Text(
                      DriverStrings.shiftHandoverRequirementsBody,
                      style: typography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.lg),
          ...missing.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: DriverSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.circleAlert,
                    color: colors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: DriverSpacing.sm),
                  Expanded(
                    child: Text(
                      messageForRequirement(item),
                      style: typography.bodyMedium.copyWith(
                        color: colors.text,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          DriverButton(
            label: DriverStrings.shiftHandoverResolveFirstRequirement,
            onPressed: () => onOpen(missing),
            colors: colors,
            typography: typography,
            size: DriverButtonSize.md,
            icon: LucideIcons.arrowRight,
          ),
        ],
      ),
    );
  }
}
