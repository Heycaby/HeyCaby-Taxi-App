import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/ride_request_provider.dart';

/// Shown on Home when a scheduled ride is accepted and the driver sent pre-ride confirmation.
class RiderPrerideHomeBanner extends ConsumerStatefulWidget {
  const RiderPrerideHomeBanner({super.key});

  @override
  ConsumerState<RiderPrerideHomeBanner> createState() =>
      _RiderPrerideHomeBannerState();
}

class _RiderPrerideHomeBannerState extends ConsumerState<RiderPrerideHomeBanner> {
  Map<String, dynamic>? _row;
  DateTime? _lastPoll;

  Future<void> _pollIfDue() async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    final mode = ref.read(rideRequestProvider).bookingMode;
    final status = ref.read(rideRequestProvider).status;
    if (rideId == null ||
        mode != 'scheduled' ||
        (status != 'accepted' &&
            status != 'driver_arrived' &&
            status != 'assigned')) {
      if (_row != null && mounted) setState(() => _row = null);
      return;
    }
    final now = DateTime.now();
    if (_lastPoll != null && now.difference(_lastPoll!) < const Duration(seconds: 20)) {
      return;
    }
    _lastPoll = now;
    final next =
        await ref.read(rideRequestProvider.notifier).fetchPrerideFields(rideId);
    if (!mounted) return;
    setState(() => _row = next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final rideId = ref.watch(rideRequestProvider).rideRequestId;
    final mode = ref.watch(rideRequestProvider).bookingMode;
    final status = ref.watch(rideRequestProvider).status;

    final shouldWatch = rideId != null &&
        mode == 'scheduled' &&
        (status == 'accepted' ||
            status == 'driver_arrived' ||
            status == 'assigned');

    if (shouldWatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pollIfDue());
    }

    if (!shouldWatch || _row == null) return const SizedBox.shrink();

    final sent = _row!['rider_preride_request_sent_at'];
    if (sent == null) return const SizedBox.shrink();

    final confirmed = _row!['rider_preride_confirmed'] == true;
    if (confirmed) return const SizedBox.shrink();

    final fee = (_row!['preride_commitment_fee_euros'] as num?)?.toDouble();
    final tikkie = _row!['commitment_fee_tikkie_url'] as String?;

    return Material(
      color: colors.card,
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.prerideBannerTitle,
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.prerideBannerSubtitle,
              style: typo.bodySmall.copyWith(color: colors.textMid),
            ),
            if (fee != null && tikkie != null && tikkie.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  final u = Uri.tryParse(tikkie);
                  if (u != null && await canLaunchUrl(u)) {
                    await launchUrl(u, mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(l10n.prerideOpenTikkie),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                      final ok = await ref
                          .read(rideRequestProvider.notifier)
                          .confirmPrerideServer(rideId!);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? l10n.prerideConfirmedThanks
                                : l10n.connectionProblem,
                          ),
                        ),
                      );
                      if (ok) {
                        _lastPoll = null;
                        await _pollIfDue();
                      }
                    },
              child: Text(l10n.prerideConfirmAttending),
            ),
          ],
        ),
      ),
    );
  }
}
