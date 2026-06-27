import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_start_shift_args.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_status_badge.dart';
import '../utils/driver_go_online_onboarding.dart';
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

class _DriverStartShiftScreenState extends ConsumerState<DriverStartShiftScreen> {
  bool _starting = false;

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
              DateTime.now().toUtc().add(const Duration(minutes: 5))
          : DateTime.now().toUtc().add(const Duration(minutes: 5));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _handoverErrorMessage(Map<String, dynamic>? res) {
    final err = res?['error']?.toString() ?? '';
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
                        letterSpacing: -0.35,
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
                    label: DriverStrings.startShiftPrimary,
                    onPressed: _starting ? null : _startShift,
                    loading: _starting,
                    colors: colors,
                    typography: typography,
                    size: DriverButtonSize.lg,
                    icon: LucideIcons.play,
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
