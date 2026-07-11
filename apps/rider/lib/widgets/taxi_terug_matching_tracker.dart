import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/active_search_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/marketplace_offers_provider.dart';
import '../providers/near_term_ride_request_provider.dart';
import '../providers/ride_request_provider.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/rider_notify_live_activity.dart';
import '../services/rider_notify_search_notifications.dart';
import '../services/sound_service.dart';
import '../services/stale_ride_cleanup.dart';

const _kTaxiTerugMatchWindow = Duration(hours: 1);

/// Shown on Home when a Taxi Terug request is pending (waiting for a driver match).
///
/// Tracks the ride in real time, shows a countdown, auto-cancels after 1 hour
/// with "no match found", and lets the rider cancel manually.
class TaxiTerugMatchingTracker extends ConsumerStatefulWidget {
  const TaxiTerugMatchingTracker({super.key});

  @override
  ConsumerState<TaxiTerugMatchingTracker> createState() =>
      _TaxiTerugMatchingTrackerState();
}

class _TaxiTerugMatchingTrackerState
    extends ConsumerState<TaxiTerugMatchingTracker> {
  RealtimeChannel? _rideChannel;
  Timer? _countdownTimer;
  Timer? _expiryTimer;
  Timer? _pollTimer;
  Timer? _widgetSyncTimer;
  bool _isCancelling = false;
  bool _isBoosting = false;
  Duration _remaining = _kTaxiTerugMatchWindow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _rideChannel?.unsubscribe();
    _countdownTimer?.cancel();
    _expiryTimer?.cancel();
    _pollTimer?.cancel();
    _widgetSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final rideState = ref.read(rideRequestProvider);
    final rideId = rideState.rideRequestId;
    final mode = rideState.bookingMode;
    final status = rideState.status;

    if (rideId == null || mode != 'terug') return;
    if (status != 'pending' && status != 'bidding') {
      if (status == 'assigned' ||
          status == 'accepted' ||
          status == 'driver_found' ||
          status == 'driver_en_route' ||
          status == 'driver_arrived' ||
          status == 'in_progress') {
        if (mounted) context.go('/active');
      }
      return;
    }

    _subscribeRide(rideId);
    _startCountdown(rideState.rideCreatedAt);
    _startPolling(rideId);
    _startWidgetSync();
    _startLiveActivity(rideState.rideCreatedAt);
  }

  void _subscribeRide(String rideId) {
    _rideChannel?.unsubscribe();
    _rideChannel = HeyCabySupabase.client
        .channel('taxi-terug-tracker:$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) {
            final newStatus = payload.newRecord['status'] as String?;
            final newFare = payload.newRecord['marketplace_offered_fare'] as num?;
            if (newStatus == null) return;
            ref.read(rideRequestProvider.notifier).updateStatus(newStatus);
            if (newFare != null) {
              ref.read(bookingProvider.notifier).setMarketplaceBidEuro(newFare.toInt());
            }
            if (newStatus == 'assigned' ||
                newStatus == 'accepted' ||
                newStatus == 'driver_found' ||
                newStatus == 'driver_en_route' ||
                newStatus == 'driver_arrived' ||
                newStatus == 'in_progress') {
              _cleanupBackground();
              unawaited(SoundService().playDriverFound());
              if (mounted) context.go('/active');
            }
          },
        )
        .subscribe();
  }

  void _startCountdown(DateTime? createdAt) {
    if (createdAt == null) return;
    _countdownTimer?.cancel();
    void tick() {
      final left = createdAt
          .add(_kTaxiTerugMatchWindow)
          .difference(DateTime.now());
      if (mounted) {
        setState(() {
          _remaining = left.isNegative ? Duration.zero : left;
        });
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());

    final untilExpiry =
        createdAt.add(_kTaxiTerugMatchWindow).difference(DateTime.now());
    if (untilExpiry <= Duration.zero) {
      unawaited(_onNoMatchFound());
      return;
    }
    _expiryTimer?.cancel();
    _expiryTimer = Timer(untilExpiry, _onNoMatchFound);
  }

  void _startPolling(String rideId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final row = await HeyCabySupabase.client
            .from('ride_requests')
            .select('status')
            .eq('id', rideId)
            .maybeSingle();
        if (row == null) {
          if (mounted) _onNoMatchFound();
          return;
        }
        final status = row['status'] as String?;
        if (status != null) {
          ref.read(rideRequestProvider.notifier).updateStatus(status);
          if (status == 'cancelled' || status == 'expired') {
            if (mounted) _onNoMatchFound();
          } else if (status == 'assigned' ||
              status == 'accepted' ||
              status == 'driver_found' ||
              status == 'driver_en_route' ||
              status == 'driver_arrived' ||
              status == 'in_progress') {
            if (mounted) context.go('/active');
          }
        }
      } catch (_) {}
    });
  }

  void _startWidgetSync() {
    _widgetSyncTimer?.cancel();
    void push() {
      if (!mounted) return;
      final rideState = ref.read(rideRequestProvider);
      final rideId = rideState.rideRequestId;
      if (rideId == null) return;
      final booking = ref.read(bookingProvider);
      final pickup = booking.pickup?.displayName ?? '';
      final dest = booking.destination?.displayName ?? '';
      final created = rideState.rideCreatedAt;
      final expiryEpoch = created == null
          ? DateTime.now().millisecondsSinceEpoch ~/ 1000
          : created
              .add(_kTaxiTerugMatchWindow)
              .millisecondsSinceEpoch ~/ 1000;
      final bidEuro = booking.marketplaceBidEuro ?? 0;

      unawaited(HeycabyWidgetSync.syncMarketplace(
        origin: pickup,
        destination: dest,
        bidCount: 0,
        bestPrice: bidEuro > 0 ? '€$bidEuro' : '—',
        bestRating: '—',
        expiryEpochSec: expiryEpoch,
        status: 'waiting',
      ));
      unawaited(RiderNotifySearchNotifications.showOrUpdate(
        pickupSummary: pickup,
        destinationSummary: dest,
        startedAt: created ?? DateTime.now(),
      ));
    }

    push();
    _widgetSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) => push());
  }

  void _startLiveActivity(DateTime? createdAt) {
    if (createdAt == null) return;
    final booking = ref.read(bookingProvider);
    final pickup = booking.pickup?.displayName ?? '';
    final dest = booking.destination?.displayName ?? '';
    unawaited(RiderNotifyLiveActivity.syncNotifySearch(
      pickupSummary: pickup,
      destinationSummary: dest,
      startedAt: createdAt,
    ));
  }

  void _cleanupBackground() {
    _expiryTimer?.cancel();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _widgetSyncTimer?.cancel();
    _rideChannel?.unsubscribe();
    unawaited(HeycabyWidgetSync.clearAll());
    unawaited(RiderNotifyLiveActivity.end());
    unawaited(RiderNotifySearchNotifications.dismiss());
  }

  Future<void> _showBoostSheet() async {
    if (_isBoosting) return;
    final l10n = AppLocalizations.of(context);
    final current = ref.read(bookingProvider).marketplaceBidEuro ?? 50;

    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.taxiTerugTrackerBoostTitle,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(l10n.taxiTerugTrackerBoostSubtitle),
                const SizedBox(height: 16),
                for (final bump in [5, 10, 15])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, current + bump),
                      child: Text('+€$bump → €${current + bump}'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;

    setState(() => _isBoosting = true);
    final ok = await boostMarketplaceOffer(ref: ref, newEuro: picked);
    if (!mounted) return;
    setState(() => _isBoosting = false);

    if (ok) {
      HapticService.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.taxiTerugTrackerBoostSuccess(picked))),
      );
      _pushWidgetSyncNow();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.taxiTerugTrackerBoostFailed)),
      );
    }
  }

  void _pushWidgetSyncNow() {
    final rideState = ref.read(rideRequestProvider);
    final rideId = rideState.rideRequestId;
    if (rideId == null) return;
    final booking = ref.read(bookingProvider);
    final pickup = booking.pickup?.displayName ?? '';
    final dest = booking.destination?.displayName ?? '';
    final created = rideState.rideCreatedAt;
    final expiryEpoch = created == null
        ? DateTime.now().millisecondsSinceEpoch ~/ 1000
        : created
            .add(_kTaxiTerugMatchWindow)
            .millisecondsSinceEpoch ~/ 1000;
    final bidEuro = booking.marketplaceBidEuro ?? 0;

    unawaited(HeycabyWidgetSync.syncMarketplace(
      origin: pickup,
      destination: dest,
      bidCount: 0,
      bestPrice: bidEuro > 0 ? '€$bidEuro' : '—',
      bestRating: '—',
      expiryEpochSec: expiryEpoch,
      status: 'waiting',
    ));
  }

  Future<void> _onNoMatchFound() async {
    if (!mounted) return;
    _cleanupBackground();

    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId != null) {
      final rideState = ref.read(rideRequestProvider);
      try {
        await cancelExpiredRiderOpenRide(
          rideId: rideId,
          riderToken: rideState.riderToken,
          cancellationReason: 'taxi_terug_no_match_timeout',
        );
      } catch (_) {}
    }

    await SoundService().playRideCancelled();
    ref.read(rideRequestProvider.notifier).reset();
    await ref.read(activeSearchProvider.notifier).clear();
    ref.invalidate(nearTermRideRequestProvider);
  }

  Future<void> _confirmCancel() async {
    if (_isCancelling) return;
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final l10n = AppLocalizations.of(context);

    final confirmed = await showHeyCabyConfirmSheet(
      context,
      colors: colors,
      typography: typo,
      title: l10n.taxiTerugTrackerCancelTitle,
      message: l10n.taxiTerugTrackerCancelConfirm,
      dismissLabel: l10n.back,
      confirmLabel: l10n.taxiTerugTrackerCancelTitle,
      icon: Icons.close_rounded,
      confirmDestructive: true,
    );

    if (confirmed == true && mounted) {
      await _cancelRequest();
    }
  }

  Future<void> _cancelRequest() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);

    _cleanupBackground();

    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId != null) {
      final rideState = ref.read(rideRequestProvider);
      try {
        await cancelExpiredRiderOpenRide(
          rideId: rideId,
          riderToken: rideState.riderToken,
          cancellationReason: 'rider_cancelled_taxi_terug',
        );
      } catch (_) {}
    }

    await SoundService().playRideCancelled();
    ref.read(rideRequestProvider.notifier).reset();
    await ref.read(activeSearchProvider.notifier).clear();
    ref.invalidate(nearTermRideRequestProvider);

    if (!mounted) return;
    setState(() => _isCancelling = false);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final rideState = ref.watch(rideRequestProvider);

    final rideId = rideState.rideRequestId;
    final mode = rideState.bookingMode;
    final status = rideState.status;

    final shouldShow = rideId != null &&
        mode == 'terug' &&
        (status == 'pending' || status == 'bidding');

    if (!shouldShow) return const SizedBox.shrink();

    final isExpired = _remaining == Duration.zero;

    return Material(
      color: colors.card,
      elevation: 3,
      shadowColor: colors.text.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isExpired
                        ? Icons.search_off_rounded
                        : Icons.keyboard_return_rounded,
                    color: colors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isExpired
                            ? l10n.taxiTerugTrackerNoMatch
                            : l10n.taxiTerugTrackerSearching,
                        style: typo.titleSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isExpired
                            ? l10n.taxiTerugTrackerNoMatchBody
                            : l10n.taxiTerugTrackerSearchingBody,
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isExpired)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatDuration(_remaining),
                      style: typo.labelMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isExpired)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      size: 16,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.taxiTerugTrackerCurrentOffer(
                        ref.watch(bookingProvider).marketplaceBidEuro ?? 0),
                      style: typo.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                if (!isExpired)
                  Expanded(
                    child: FilledButton(
                      onPressed: _isBoosting ? null : _showBoostSheet,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: _isBoosting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onAccent,
                              ),
                            )
                          : Text(
                              l10n.taxiTerugTrackerBoost,
                              style: typo.labelMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                if (!isExpired) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isCancelling ? null : _confirmCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(
                          color: colors.error.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _isCancelling
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.error,
                            ),
                          )
                        : Text(
                            l10n.taxiTerugTrackerCancelTitle,
                            style: typo.labelMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
