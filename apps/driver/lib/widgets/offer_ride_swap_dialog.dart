import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';

/// Reason codes for `offer_ride_swap` RPC (migration 042).
const kSwapReasonCodes = <String, String>{
  'personal_emergency': 'Persoonlijke noodstoestand',
  'vehicle_breakdown': 'Voertuigstoring',
  'schedule_conflict': 'Roosterconflict',
  'medical': 'Medisch',
  'other': 'Anders',
};

Future<void> showOfferRideSwapDialog(
  BuildContext context,
  WidgetRef ref, {
  required ScheduledRide ride,
  VoidCallback? onSuccess,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _OfferRideSwapDialogBody(
      ride: ride,
      onOffered: () {
        Navigator.of(ctx).pop();
        ref.invalidate(scheduledRidesByTabProvider('confirmed'));
        onSuccess?.call();
      },
    ),
  );
}

class _OfferRideSwapDialogBody extends ConsumerStatefulWidget {
  const _OfferRideSwapDialogBody({
    required this.ride,
    required this.onOffered,
  });

  final ScheduledRide ride;
  final VoidCallback onOffered;

  @override
  ConsumerState<_OfferRideSwapDialogBody> createState() =>
      _OfferRideSwapDialogBodyState();
}

class _OfferRideSwapDialogBodyState extends ConsumerState<_OfferRideSwapDialogBody> {
  String _reason = 'vehicle_breakdown';
  final _detailCtrl = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final driverId = await ref.read(driverIdProvider.future);
    if (driverId == null) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final res = await ref.read(rideSwapServiceProvider).offerRideSwap(
          driverId: driverId,
          rideId: widget.ride.id,
          reason: _reason,
          detail: _detailCtrl.text.trim().isEmpty ? null : _detailCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res?['success'] == true) {
      widget.onOffered();
      return;
    }
    final err = res?['error']?.toString() ?? '';
    setState(() {
      if (err.toLowerCase().contains('too_late') || err.contains('te laat')) {
        _errorText = DriverStrings.swapTooLate;
      } else {
        _errorText = err.isNotEmpty ? err : 'Mislukt';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final pickup = widget.ride.scheduledPickupAt;
    final minsLeft = pickup != null
        ? pickup.difference(DateTime.now()).inMinutes
        : 9999;
    final isEmergency = minsLeft <= 45;
    final routeLine = [
      if ((widget.ride.pickupAddress ?? '').isNotEmpty) widget.ride.pickupAddress!,
      if (pickup != null) DateFormat('EEE d MMM HH:mm').format(pickup),
    ].join(' · ');

    return AlertDialog(
      backgroundColor: colors.card,
      title: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              DriverStrings.swapOfferTitle,
              style: typo.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              routeLine,
              style: typo.bodyMedium.copyWith(
                color: colors.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text('• ${DriverStrings.swapOfferBullet1}', style: typo.bodySmall.copyWith(height: 1.35)),
            Text('• ${DriverStrings.swapOfferBullet2}', style: typo.bodySmall.copyWith(height: 1.35)),
            Text('• ${DriverStrings.swapOfferBullet3}', style: typo.bodySmall.copyWith(height: 1.35)),
            Text('• ${DriverStrings.swapOfferBullet4}', style: typo.bodySmall.copyWith(height: 1.35)),
            if (isEmergency) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '⚠️ ${DriverStrings.swapEmergencyWarn}',
                  style: typo.bodySmall.copyWith(color: colors.text, height: 1.3),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              DriverStrings.swapOfferWhy,
              style: typo.labelLarge.copyWith(color: colors.text, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...kSwapReasonCodes.entries.map(
              (e) => RadioListTile<String>(
                dense: true,
                value: e.key,
                groupValue: _reason,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _reason = v ?? _reason),
                title: Text(e.value, style: typo.bodySmall),
              ),
            ),
            TextField(
              controller: _detailCtrl,
              maxLines: 2,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: 'Toelichting (optioneel)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!, style: typo.bodySmall.copyWith(color: colors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(DriverStrings.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onAccent,
                  ),
                )
              : Text(DriverStrings.swapOfferConfirm),
        ),
      ],
    );
  }
}
