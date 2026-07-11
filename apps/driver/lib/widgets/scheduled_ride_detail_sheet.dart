import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:intl/intl.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../utils/accept_ride_error_message.dart';
import '../services/driver_data_service.dart';
import '../services/location_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import 'driver_ride_premium_style.dart';

/// Calm review modal for planned scheduled work — no ringtone, no countdown alarm.
Future<void> showScheduledRideDetailSheet(
  BuildContext context,
  WidgetRef ref, {
  required ScheduledRide ride,
  VoidCallback? onAccepted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ScheduledRideDetailSheet(
      ride: ride,
      onAccepted: onAccepted,
    ),
  );
}

class _ScheduledRideDetailSheet extends ConsumerStatefulWidget {
  const _ScheduledRideDetailSheet({
    required this.ride,
    this.onAccepted,
  });

  final ScheduledRide ride;
  final VoidCallback? onAccepted;

  @override
  ConsumerState<_ScheduledRideDetailSheet> createState() =>
      _ScheduledRideDetailSheetState();
}

class _ScheduledRideDetailSheetState
    extends ConsumerState<_ScheduledRideDetailSheet> {
  bool _accepting = false;
  String? _riderName;

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    try {
      final row = await HeyCabySupabase.client
          .from('ride_requests')
          .select('pickup_contact_name')
          .eq('id', widget.ride.id)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() {
        _riderName = row['pickup_contact_name'] as String?;
      });
    } catch (_) {}
  }

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await DriverLocationService().uploadNowForAccept();
      await ref.read(driverApiProvider).acceptScheduledRide(
            rideRequestId: widget.ride.id,
          );
      HapticService.success();
      ref.invalidate(scheduledRidesProvider);
      ref.invalidate(scheduledRidesByTabProvider('requests'));
      ref.invalidate(scheduledRidesByTabProvider('confirmed'));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.scheduledRideAcceptedMessage)),
      );
      widget.onAccepted?.call();
    } on DriverAcceptRideException catch (e) {
      if (!mounted) return;
      setState(() => _accepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(acceptRideErrorMessageFor(e))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _accepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.scheduledRideAcceptFailedMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typo = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final ride = widget.ride;
    final when = ride.scheduledPickupAt != null
        ? DateFormat('EEE d MMM · HH:mm')
            .format(ride.scheduledPickupAt!.toLocal())
        : '—';
    final duration = ride.estimatedDurationMin != null
        ? HeyCabyFormatters.formatDuration(ride.estimatedDurationMin!)
        : null;
    final distance = ride.distanceKm != null
        ? HeyCabyFormatters.formatDistance(ride.distanceKm!)
        : null;
    final fare = ride.estimatedFare != null
        ? '€${ride.estimatedFare!.toStringAsFixed(2)}'
        : DriverStrings.incomingRideOpenFare;
    final payment = _paymentLabel(ride.paymentMethods);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DriverRidePremiumStyle.glassSurface(
        colors: colors,
        borderRadius: DriverRadius.sheetTop,
        blurSigma: 26,
        tintOpacity: 0.82,
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DriverSpacing.screenEdge,
              DriverSpacing.md,
              DriverSpacing.screenEdge,
              DriverSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: DriverSpacing.md),
                Text(
                  DriverStrings.scheduledRideDetailTitle,
                  style: typo.titleLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: DriverSpacing.xs),
                Text(
                  when,
                  style: typo.titleMedium.copyWith(color: colors.primary),
                ),
                const SizedBox(height: DriverSpacing.lg),
                _DetailRow(
                  colors: colors,
                  typo: typo,
                  label: DriverStrings.incomingRidePickup,
                  value: ride.pickupAddress ?? '—',
                ),
                const SizedBox(height: DriverSpacing.sm),
                _DetailRow(
                  colors: colors,
                  typo: typo,
                  label: DriverStrings.incomingRideDropoff,
                  value: ride.destinationAddress ?? '—',
                ),
                if (distance != null || duration != null) ...[
                  const SizedBox(height: DriverSpacing.sm),
                  Text(
                    [
                      if (duration != null) duration,
                      if (distance != null) distance
                    ].join(' · '),
                    style:
                        typo.bodyMedium.copyWith(color: colors.textSecondary),
                  ),
                ],
                const SizedBox(height: DriverSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(colors: colors, typo: typo, label: fare),
                    if (payment != null)
                      _Chip(colors: colors, typo: typo, label: payment),
                    if (ride.vehicleCategory != null)
                      _Chip(
                        colors: colors,
                        typo: typo,
                        label: ride.vehicleCategory!,
                      ),
                    if (_riderName != null && _riderName!.trim().isNotEmpty)
                      _Chip(colors: colors, typo: typo, label: _riderName!),
                  ],
                ),
                const SizedBox(height: DriverSpacing.lg),
                DriverButton(
                  label: DriverStrings.acceptScheduledRide,
                  colors: colors,
                  typography: typo,
                  loading: _accepting,
                  onPressed: _accepting ? null : _accept,
                ),
                const SizedBox(height: DriverSpacing.sm),
                OutlinedButton(
                  onPressed: _accepting
                      ? null
                      : () {
                          HapticService.selectionClick();
                          Navigator.of(context).pop();
                        },
                  child: Text(DriverStrings.notInterestedScheduledRide),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _paymentLabel(List<String>? methods) {
    if (methods == null || methods.isEmpty) return null;
    if (methods.length > 1) return DriverStrings.incomingRidePaymentFlexible;
    return methods.first;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.colors,
    required this.typo,
    required this.label,
    required this.value,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: typo.labelSmall.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: typo.bodyLarge.copyWith(color: colors.text),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.colors,
    required this.typo,
    required this.label,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: typo.labelMedium.copyWith(color: colors.text),
      ),
    );
  }
}
