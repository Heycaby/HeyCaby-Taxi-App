import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_ride_premium_style.dart';
import 'driver_ride_lifecycle_error_message.dart';

/// Confirms, calls cancel API, clears active ride, returns home.
Future<bool> confirmAndCancelDriverRide({
  required BuildContext context,
  required WidgetRef ref,
  required String rideId,
  Future<void> Function()? afterCancel,
  bool rideInProgress = false,
}) async {
  if (rideInProgress) {
    final intent = await _showRideExitIntentSheet(context, ref);
    if (intent != _RideExitIntent.cancel || !context.mounted) return false;
  }

  final reason = await showModalBottomSheet<_CancelReason>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CancelRideReasonSheet(
      colors: DriverColors.fromTheme(ref.read(colorsProvider)),
      typography: DriverTypography.fromTheme(ref.read(typographyProvider)),
    ),
  );
  if (reason == null || !context.mounted) {
    return false;
  }

  final settlement = await _showCancellationSettlementSheet(context, ref);
  if (settlement == null || !context.mounted) return false;

  final confirmed = await showHeyCabyConfirmSheet(
    context,
    colors: ref.read(colorsProvider),
    typography: ref.read(typographyProvider),
    title: DriverStrings.cancelRideFinalTitle,
    message: DriverStrings.cancelRideFinalBody,
    dismissLabel: DriverStrings.back,
    confirmLabel: DriverStrings.cancelRide,
    icon: Icons.warning_amber_rounded,
    confirmDestructive: true,
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    await ref.read(driverApiProvider).cancelRideV2(
          rideRequestId: rideId,
          reasonCode: reason.code,
          details: reason.details,
          riderPaidCents: settlement.paidCents,
          waiveRemaining: settlement.waiveRemaining,
          pauseNewRequests: settlement.pauseNewRequests,
        );
    if (afterCancel != null) await afterCancel();
    if (settlement.pauseNewRequests) {
      ref.read(driverStateProvider.notifier).setPendingBreak(true);
    }
    if (!context.mounted) return true;
    context.go('/driver/ride/rate/$rideId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(DriverStrings.rideCancelled)),
    );
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(driverRideLifecycleErrorMessage(e))),
    );
    return false;
  } finally {}
}

enum _RideExitIntent { continueRide, pauseAfterRide, cancel }

Future<_RideExitIntent?> _showRideExitIntentSheet(
  BuildContext context,
  WidgetRef ref,
) {
  final colors = DriverColors.fromTheme(ref.read(colorsProvider));
  final typography = DriverTypography.fromTheme(ref.read(typographyProvider));
  return showModalBottomSheet<_RideExitIntent>(
    context: context,
    backgroundColor: colors.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(DriverStrings.leaveRideTitle, style: typography.titleLarge),
          const SizedBox(height: 8),
          Text(DriverStrings.leaveRideBody,
              style:
                  typography.bodyMedium.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.route_rounded),
            title: Text(DriverStrings.continueCurrentRide),
            subtitle: Text(DriverStrings.continueCurrentRideBody),
            onTap: () => Navigator.pop(context, _RideExitIntent.continueRide),
          ),
          ListTile(
            leading: const Icon(Icons.pause_circle_outline_rounded),
            title: Text(DriverStrings.stopAfterThisRide),
            subtitle: Text(DriverStrings.stopAfterThisRideBody),
            onTap: () => Navigator.pop(context, _RideExitIntent.pauseAfterRide),
          ),
          ListTile(
            leading: Icon(Icons.cancel_outlined, color: colors.error),
            title: Text(DriverStrings.stillCancelRide,
                style: TextStyle(color: colors.error)),
            onTap: () => Navigator.pop(context, _RideExitIntent.cancel),
          ),
        ]),
      ),
    ),
  ).then((value) {
    if (value == _RideExitIntent.pauseAfterRide) {
      ref.read(driverStateProvider.notifier).setPendingBreak(true);
      if (!context.mounted) return value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.stopAfterRideConfirmed)),
      );
    }
    return value;
  });
}

class _CancellationSettlement {
  const _CancellationSettlement({
    required this.paidCents,
    required this.waiveRemaining,
    required this.pauseNewRequests,
  });
  final int paidCents;
  final bool waiveRemaining;
  final bool pauseNewRequests;
}

Future<_CancellationSettlement?> _showCancellationSettlementSheet(
  BuildContext context,
  WidgetRef ref,
) {
  final amount = TextEditingController();
  var waived = false;
  var pause = false;
  final colors = DriverColors.fromTheme(ref.read(colorsProvider));
  return showModalBottomSheet<_CancellationSettlement>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(builder: (context, setModalState) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(DriverStrings.cancelSettlementTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(DriverStrings.cancelSettlementBody),
            const SizedBox(height: 16),
            TextField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: DriverStrings.amountAlreadyPaid,
                prefixText: '€ ',
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: waived,
              title: Text(DriverStrings.waiveRemainingFee),
              subtitle: Text(DriverStrings.waiveRemainingFeeBody),
              onChanged: (v) => setModalState(() => waived = v),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: pause,
              title: Text(DriverStrings.pauseNewRequestsAfterCancel),
              onChanged: (v) => setModalState(() => pause = v),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(DriverStrings.noCommissionReminder),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final normalized = amount.text.trim().replaceAll(',', '.');
                final euros = double.tryParse(normalized) ?? 0;
                Navigator.pop(
                    context,
                    _CancellationSettlement(
                      paidCents: (euros * 100).round().clamp(0, 10000000),
                      waiveRemaining: waived,
                      pauseNewRequests: pause,
                    ));
              },
              child: Text(DriverStrings.continueLabel),
            ),
          ]),
        ),
      );
    }),
  ).whenComplete(amount.dispose);
}

class _CancelReason {
  const _CancelReason(this.code, this.details);
  final String code;
  final String? details;
}

class _CancelRideReasonSheet extends StatefulWidget {
  const _CancelRideReasonSheet({
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<_CancelRideReasonSheet> createState() => _CancelRideReasonSheetState();
}

class _CancelRideReasonSheetState extends State<_CancelRideReasonSheet> {
  final TextEditingController _detailsCtrl = TextEditingController();
  String? _selectedReason;

  List<(String, String)> get _reasons => [
        ('changed_mind', DriverStrings.cancelRideReasonChangedMind),
        ('vehicle_problem', DriverStrings.cancelRideReasonVehicleProblem),
        ('safety_concern', DriverStrings.cancelRideReasonSafetyConcern),
        ('rider_requested', DriverStrings.cancelRideReasonRiderRequested),
        (
          'route_or_destination_issue',
          DriverStrings.cancelRideReasonRouteIssue
        ),
        ('other', DriverStrings.cancelRideReasonOther),
      ];

  bool get _canCancel =>
      _selectedReason != null || _detailsCtrl.text.trim().isNotEmpty;

  _CancelReason get _reasonPayload {
    final details = _detailsCtrl.text.trim();
    final selected = _selectedReason;
    return _CancelReason(selected ?? 'other', details.isEmpty ? null : details);
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typography = widget.typography;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Padding(
          padding: const EdgeInsets.all(DriverSpacing.sm),
          child: DriverRidePremiumStyle.glassSurface(
            colors: colors,
            borderRadius: BorderRadius.circular(30),
            blurSigma: 24,
            tintOpacity: 0.82,
            padding: const EdgeInsets.fromLTRB(
              DriverSpacing.lg,
              DriverSpacing.sm,
              DriverSpacing.lg,
              DriverSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.lg),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: colors.error,
                        ),
                      ),
                      const SizedBox(width: DriverSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DriverStrings.cancelRideSheetTitle,
                              style: typography.titleLarge.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: DriverSpacing.xs),
                            Text(
                              DriverStrings.cancelRideSheetBody,
                              style: typography.bodySmall.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DriverSpacing.lg),
                  Wrap(
                    spacing: DriverSpacing.sm,
                    runSpacing: DriverSpacing.sm,
                    children: [
                      for (final reason in _reasons)
                        _ReasonPill(
                          label: reason.$2,
                          selected: _selectedReason == reason.$1,
                          colors: colors,
                          typography: typography,
                          onTap: () {
                            setState(() {
                              _selectedReason = _selectedReason == reason.$1
                                  ? null
                                  : reason.$1;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: DriverSpacing.md),
                  TextField(
                    controller: _detailsCtrl,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: DriverStrings.cancelRideReasonDetailsHint,
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: colors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.lg),
                  FilledButton.icon(
                    onPressed: _canCancel
                        ? () => Navigator.of(context).pop(_reasonPayload)
                        : null,
                    icon: const Icon(Icons.close_rounded),
                    label: Text(DriverStrings.cancelRide),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onPrimary,
                      disabledBackgroundColor:
                          colors.border.withValues(alpha: 0.45),
                      disabledForegroundColor: colors.textSecondary,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(DriverStrings.back),
                  ),
                  if (!_canCancel) ...[
                    const SizedBox(height: DriverSpacing.xs),
                    Text(
                      DriverStrings.cancelRideReasonRequired,
                      textAlign: TextAlign.center,
                      style: typography.labelSmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonPill extends StatelessWidget {
  const _ReasonPill({
    required this.label,
    required this.selected,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.primary : colors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.md,
            vertical: DriverSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
            ),
          ),
          child: Text(
            label,
            style: typography.labelMedium.copyWith(
              color: selected ? colors.onPrimary : colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
