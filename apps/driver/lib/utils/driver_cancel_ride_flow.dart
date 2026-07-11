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

/// Confirms, calls cancel API, clears active ride, returns home.
Future<bool> confirmAndCancelDriverRide({
  required BuildContext context,
  required WidgetRef ref,
  required String rideId,
  Future<void> Function()? afterCancel,
}) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CancelRideReasonSheet(
      colors: DriverColors.fromTheme(ref.read(colorsProvider)),
      typography: DriverTypography.fromTheme(ref.read(typographyProvider)),
    ),
  );
  if (reason == null || reason.trim().isEmpty || !context.mounted) {
    return false;
  }

  try {
    await ref.read(driverApiProvider).cancelRide(
          rideRequestId: rideId,
          reason: reason.trim(),
        );
    if (afterCancel != null) await afterCancel();
    ref.read(driverStateProvider.notifier).clearActiveRide();
    if (!context.mounted) return true;
    context.go('/driver');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(DriverStrings.rideCancelled)),
    );
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${DriverStrings.rideCancelFailed} $e')),
    );
    return false;
  } finally {}
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

  List<String> get _reasons => [
        DriverStrings.cancelRideReasonRiderUnavailable,
        DriverStrings.cancelRideReasonPickupIssue,
        DriverStrings.cancelRideReasonWrongDetails,
        DriverStrings.cancelRideReasonSafetyConcern,
        DriverStrings.cancelRideReasonOther,
      ];

  bool get _canCancel =>
      _selectedReason != null || _detailsCtrl.text.trim().isNotEmpty;

  String get _reasonPayload {
    final details = _detailsCtrl.text.trim();
    final selected = _selectedReason;
    if (selected == null || selected == DriverStrings.cancelRideReasonOther) {
      return details.isEmpty ? selected ?? '' : details;
    }
    if (details.isEmpty) return selected;
    return '$selected - $details';
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
                          label: reason,
                          selected: _selectedReason == reason,
                          colors: colors,
                          typography: typography,
                          onTap: () {
                            setState(() {
                              _selectedReason =
                                  _selectedReason == reason ? null : reason;
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
