import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';

/// Reliability pill + pre-ride confirmation actions for a scheduled, assigned ride.
class ScheduledPrerideActions extends ConsumerWidget {
  const ScheduledPrerideActions({
    super.key,
    required this.ride,
    required this.colors,
    required this.typo,
    required this.onInvalidate,
  });

  final ScheduledRide ride;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onInvalidate;

  String _tierLabel(String? tier) {
    switch (tier) {
      case 'reliable':
        return DriverStrings.prerideReliabilityReliable;
      case 'risk':
        return DriverStrings.prerideReliabilityRisk;
      case 'amber':
        return DriverStrings.prerideReliabilityAmber;
      case 'new':
      default:
        return DriverStrings.prerideReliabilityNew;
    }
  }

  Color _tierColor(String? tier) {
    switch (tier) {
      case 'reliable':
        return colors.success;
      case 'risk':
        return colors.error;
      case 'amber':
        return colors.warning;
      default:
        return colors.textSoft;
    }
  }

  Future<void> _showFeeModal(BuildContext context, WidgetRef ref) async {
    var euros = 5.0;
    final tikkieCtrl = TextEditingController();
    final rootContext = context;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    DriverStrings.prerideModalTitle,
                    style: typo.titleMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DriverStrings.prerideModalTikkieHint,
                    style: typo.bodySmall.copyWith(color: colors.textMid),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    DriverStrings.prerideFeeLabel,
                    style: typo.labelMedium.copyWith(color: colors.text),
                  ),
                  Slider(
                    value: euros,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '€${euros.toStringAsFixed(0)}',
                    onChanged: (v) => setModalState(() => euros = v),
                  ),
                  TextField(
                    controller: tikkieCtrl,
                    style: typo.bodyMedium.copyWith(color: colors.text),
                    decoration: InputDecoration(
                      labelText: DriverStrings.prerideTikkieUrlLabel,
                      labelStyle: TextStyle(color: colors.textMid),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.accent, width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final url = tikkieCtrl.text.trim();
                      if (url.length < 12) return;
                      final svc = ref.read(driverDataServiceProvider);
                      final res = await svc.driverSendPrerideWithFee(
                        ride.id,
                        feeEuros: euros,
                        tikkieUrl: url,
                      );
                      if (!rootContext.mounted) return;
                      Navigator.pop(ctx);
                      final ok = res['ok'] == true;
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? DriverStrings.prerideAwaitingRider
                                : (res['error']?.toString() ??
                                    DriverStrings.prerideErrorGeneric),
                          ),
                        ),
                      );
                      if (ok) onInvalidate();
                    },
                    child: Text(DriverStrings.prerideSendRequest),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    tikkieCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ride.isScheduledBooking) return const SizedBox.shrink();

    final assigned = ride.status == 'accepted' ||
        ride.status == 'driver_arrived' ||
        ride.status == 'assigned';
    if (!assigned && ride.riderPrerideRequestSentAt == null) {
      return const SizedBox.shrink();
    }

    final tier = ride.riderReliabilityTier;
    final showPreride = ride.canSendPrerideConfirmation ||
        ride.prerideAwaitingRider ||
        ride.canReleaseAfterPrerideDeadline ||
        ride.canMarkCommitmentReceived;

    if (!showPreride &&
        tier == null &&
        ride.riderPrerideRequestSentAt == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tier != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _tierColor(tier).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border:
                    Border.all(color: _tierColor(tier).withValues(alpha: 0.35)),
              ),
              child: Text(
                _tierLabel(tier),
                style: typo.labelSmall.copyWith(
                  color: _tierColor(tier),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (ride.canSendPrerideConfirmation) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showFeeModal(context, ref),
                  child: Text(
                    DriverStrings.prerideAskWithFee,
                    textAlign: TextAlign.center,
                    style: typo.labelSmall,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final svc = ref.read(driverDataServiceProvider);
                    final res = await svc.driverSendPrerideNoFee(ride.id);
                    if (!context.mounted) return;
                    final ok = res['ok'] == true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? DriverStrings.prerideAwaitingRider
                              : (res['error']?.toString() == 'outside_window'
                                  ? DriverStrings.prerideErrorOutsideWindow
                                  : DriverStrings.prerideErrorGeneric),
                        ),
                      ),
                    );
                    if (ok) onInvalidate();
                  },
                  child: Text(
                    DriverStrings.prerideAskNoFee,
                    textAlign: TextAlign.center,
                    style: typo.labelSmall,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (ride.prerideAwaitingRider) ...[
          const SizedBox(height: 8),
          Text(
            DriverStrings.prerideAwaitingRider,
            style: typo.bodySmall.copyWith(color: colors.textMid),
          ),
          if (ride.commitmentFeeTikkieUrl != null &&
              ride.commitmentFeeTikkieUrl!.isNotEmpty) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: ride.commitmentFeeTikkieUrl!),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(DriverStrings.prerideTikkieLinkCopied),
                  ),
                );
              },
              icon: Icon(Icons.copy, size: 18, color: colors.accent),
              label: Text(
                'Kopieer Tikkie-link',
                style: typo.labelMedium.copyWith(color: colors.accent),
              ),
            ),
          ],
        ],
        if (ride.riderPrerideConfirmed) ...[
          const SizedBox(height: 6),
          Text(
            DriverStrings.prerideRiderConfirmed,
            style: typo.bodySmall.copyWith(color: colors.success),
          ),
        ],
        if (ride.canMarkCommitmentReceived) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final svc = ref.read(driverDataServiceProvider);
              final res = await svc.driverMarkCommitmentFeeReceived(ride.id);
              if (!context.mounted) return;
              final ok = res['ok'] == true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? 'Opgeslagen' : DriverStrings.prerideErrorGeneric,
                  ),
                ),
              );
              if (ok) onInvalidate();
            },
            child: Text(DriverStrings.prerideMarkTikkieReceived),
          ),
        ],
        if (ride.canReleaseAfterPrerideDeadline) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              final svc = ref.read(driverDataServiceProvider);
              final res = await svc.driverReleasePrerideRide(ride.id);
              if (!context.mounted) return;
              final ok = res['ok'] == true;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Rit vrijgegeven'
                        : (res['error']?.toString() == 'deadline_not_passed'
                            ? DriverStrings.prerideErrorDeadlineNotPassed
                            : DriverStrings.prerideErrorGeneric),
                  ),
                ),
              );
              if (ok) onInvalidate();
            },
            child: Text(
              DriverStrings.prerideReleaseRide,
              style: typo.bodyMedium.copyWith(color: colors.error),
            ),
          ),
        ],
      ],
    );
  }
}
