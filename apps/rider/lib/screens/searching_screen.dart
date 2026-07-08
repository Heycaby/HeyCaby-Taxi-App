import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/rider_matching_ui.dart';
import '../constants/rider_search_window.dart';
import '../models/ride_matching_variant.dart';
import '../providers/active_search_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/near_term_ride_request_provider.dart';
import '../providers/recent_destinations_provider.dart';
import '../providers/ride_request_provider.dart';
import '../services/booking_flow_navigation.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/nearby_supply_service.dart';
import '../services/rider_dispatch_status_service.dart';
import '../services/rider_matching_recovery_actions.dart';
import '../services/sound_service.dart';
import '../services/stale_ride_cleanup.dart';
import '../widgets/booking/matching_search_map_view.dart';
import '../widgets/booking/matching_search_sheet.dart';
import '../widgets/booking/trip_summary_map_view.dart';
import '../widgets/matching_alternatives_card.dart';
import '../widgets/scheduled_matching_fullscreen.dart';

class SearchingScreen extends ConsumerStatefulWidget {
  final RideMatchingVariant variant;

  const SearchingScreen({
    super.key,
    this.variant = RideMatchingVariant.instant,
  });

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends ConsumerState<SearchingScreen>
    with TickerProviderStateMixin {
  // Radar — staggered ripples + rotating sweep (60% slower than prior tuning)
  static const int _rippleCount = 5;
  static const Duration _rippleDuration = Duration(milliseconds: 14000);
  static const Duration _sweepDuration = Duration(milliseconds: 16000);

  late final List<AnimationController> _radarControllers;
  late final AnimationController _radarSweepController;

  RealtimeChannel? _channel;
  RealtimeChannel? _bidsChannel;
  Timer? _clockTimer;
  Timer? _widgetTimer;
  Timer? _scheduledWidgetTimer;
  Timer? _noDriverTimer;
  Timer? _supplyPollTimer;
  Timer? _matchingExpandTimer;
  Timer? _searchWindowTimer;
  Timer? _dispatchPollTimer;
  RiderDispatchStatus _dispatchStatus = RiderDispatchStatus.empty;
  bool _showNoDriverCard = false;
  bool _searchExpired = false;
  Duration _searchElapsed = Duration.zero;

  int _marketplaceBidCount = 0;
  String _marketplaceBestPrice = '';
  String _marketplaceBestRating = '';

  @override
  void initState() {
    super.initState();
    _radarControllers = List.generate(_rippleCount, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: _rippleDuration,
      );
      final staggerMs =
          (i * _rippleDuration.inMilliseconds / _rippleCount).round();
      Future.delayed(Duration(milliseconds: staggerMs), () {
        if (mounted) ctrl.repeat();
      });
      return ctrl;
    });
    _radarSweepController = AnimationController(
      vsync: this,
      duration: _sweepDuration,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapRideFlow());
  }

  Future<void> _bootstrapRideFlow() async {
    final rideNotifier = ref.read(rideRequestProvider.notifier);
    final restored = await rideNotifier.tryRestoreActiveRideRequest();
    if (!mounted) return;

    if (!restored) {
      final booking = ref.read(bookingProvider);
      if (booking.pickup != null && booking.destination != null) {
        final ok = await rideNotifier.createRide(booking);
        if (!mounted) return;
        if (!ok) {
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            final rideError = ref.read(rideRequestProvider).error;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(
                  rideError == 'location_required'
                      ? l10n.locationPermissionRequired
                      : l10n.rideBookingFailed,
                ),
              ),
            );
            context.go('/summary');
          }
          return;
        }
        if (booking.destination != null) {
          await ref.read(recentDestinationsProvider.notifier).recordDestination(
                fullAddress: booking.destination!.fullAddress,
                lat: booking.destination!.lat,
                lng: booking.destination!.lng,
              );
        }
      } else {
        if (mounted) context.go('/home');
        return;
      }
    }

    final st = ref.read(rideRequestProvider).status;
    if (st == 'assigned' ||
        st == 'accepted' ||
        st == 'driver_arrived' ||
        st == 'in_progress') {
      if (mounted) context.go('/active');
      return;
    }

    final rideReq = ref.read(rideRequestProvider);
    final modeStr = (rideReq.bookingMode != null &&
            rideReq.bookingMode!.trim().isNotEmpty)
        ? rideReq.bookingMode!.trim()
        : bookingModeStorageString(ref.read(bookingProvider).effectiveRideMode);
    final routeForMode = rideMatchingVariantForBookingModeString(modeStr);
    if (routeForMode != widget.variant && mounted) {
      context.go(routeForMode.routePath);
      return;
    }

    _startTimersAndFacts();
    _subscribeToRide();
    _subscribeMarketplaceBids();
    _scheduleSearchWindowExpiry();
    _pushScheduledWidgetIfNeeded();
    _startScheduledWidgetRefreshTimer();
    _startWidgetPushTimer();
  }

  String _matchingTitle(AppLocalizations l10n) {
    switch (widget.variant) {
      case RideMatchingVariant.instant:
        return l10n.searchingTitle;
      case RideMatchingVariant.marketplace:
        return l10n.matchingTitleMarketplace;
      case RideMatchingVariant.terug:
        return l10n.rideMatchingTypeLabelTerug;
      case RideMatchingVariant.scheduled:
        return l10n.matchingTitleScheduled;
    }
  }

  String _dispatchTitle(AppLocalizations l10n) {
    final status = _dispatchStatus;
    if (status.isNoDrivers) return l10n.dispatchNoDriversTitle;
    if (status.wave == 0 && status.favoriteDriverName != null) {
      return l10n.dispatchWave0Title(status.favoriteDriverName!);
    }
    return switch (status.wave) {
      1 => l10n.dispatchWave1Title,
      2 => l10n.dispatchWave2Title,
      3 => l10n.dispatchWave3Title,
      >= 4 => l10n.dispatchWave4Title,
      _ => l10n.dispatchWave1Title,
    };
  }

  String? _dispatchSubtitle(AppLocalizations l10n) {
    final status = _dispatchStatus;
    if (status.isNoDrivers) return l10n.dispatchNoDriversBody;
    if (status.driversNotified <= 0) return null;

    final closest = status.closestKm;
    final eta = status.fastestEtaMin;
    if (closest != null && eta != null) {
      return l10n.dispatchWaveClosestEta(
        closest.toStringAsFixed(1),
        eta.round().clamp(1, 999),
      );
    }
    if (status.wave >= 3 && closest != null && eta != null) {
      return l10n.dispatchWaveFarEta(
        closest.toStringAsFixed(0),
        eta.round().clamp(1, 999),
      );
    }
    if (status.wave >= 2) {
      return l10n.dispatchWaveExpandKm(status.waveOuterKm.round());
    }
    return l10n.dispatchWaveDriversNotified(status.driversNotified);
  }

  String? _waveCountdownLabel() {
    if (!_dispatchStatus.ok || !_dispatchStatus.isWaveActive) return null;
    final remaining = (_dispatchStatus.waveTimeoutSeconds -
            _dispatchStatus.waveElapsedSeconds)
        .clamp(0, 999);
    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final s = (remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _sheetTitle(AppLocalizations l10n) {
    if (_showNoDriverCard && !_searchExpired) {
      return l10n.searchNoSupplyInlineTitle;
    }
    if (_dispatchStatus.ok && widget.variant == RideMatchingVariant.instant) {
      return _dispatchTitle(l10n);
    }
    return _matchingTitle(l10n);
  }

  String _sheetSubtitle(AppLocalizations l10n) {
    if (_showNoDriverCard && !_searchExpired) {
      return l10n.searchNoSupplyInlineBody;
    }
    if (_dispatchStatus.ok && widget.variant == RideMatchingVariant.instant) {
      final dispatchLine = _dispatchSubtitle(l10n);
      if (dispatchLine != null && dispatchLine.trim().isNotEmpty) {
        return dispatchLine;
      }
    }
    return widget.variant == RideMatchingVariant.marketplace
        ? l10n.activeBookingMarketplaceBody
        : l10n.activeBookingInstantBody;
  }

  double _sheetProgress() {
    if (_dispatchStatus.ok && widget.variant == RideMatchingVariant.instant) {
      return _dispatchStatus.progress;
    }
    final total = kRiderDriverSearchWindow.inSeconds;
    if (total <= 0) return 0.1;
    return _searchElapsed.inSeconds / total;
  }

  void _scheduleSearchWindowExpiry() {
    _searchWindowTimer?.cancel();
    final created = ref.read(rideRequestProvider).rideCreatedAt;
    if (created == null) return;
    final endsAt = created.add(kRiderDriverSearchWindow);
    var left = endsAt.difference(DateTime.now());
    if (left <= Duration.zero) {
      unawaited(_onForegroundSearchExpired());
      return;
    }
    _searchWindowTimer = Timer(left, () {
      unawaited(_onForegroundSearchExpired());
    });
  }

  Future<void> _onForegroundSearchExpired() async {
    if (!mounted) return;
    _searchWindowTimer?.cancel();
    _channel?.unsubscribe();
    await ref.read(rideRequestProvider.notifier).cancelStaleOpenRequest();
    if (!mounted) return;
    setState(() => _searchExpired = true);
  }

  void _startTimersAndFacts() {
    if (!mounted) return;
    if (widget.variant == RideMatchingVariant.scheduled) {
      return;
    }

    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(_updateSearchClock);
      }
    });
    _updateSearchClock();

    _noDriverTimer?.cancel();
    _supplyPollTimer?.cancel();
    _noDriverTimer = Timer(kRiderNoSupplyMinSearchElapsed, () {
      unawaited(_evaluateNoSupplyState());
    });
    _supplyPollTimer = Timer.periodic(kRiderNoSupplyRecheckInterval, (_) {
      unawaited(_evaluateNoSupplyState());
    });
  }

  void _clearNoSupplyHintIfShown() {
    if (_showNoDriverCard && mounted) {
      setState(() => _showNoDriverCard = false);
    }
  }

  Future<void> _evaluateNoSupplyState() async {
    if (!mounted || widget.variant == RideMatchingVariant.scheduled) return;
    if (_searchExpired) return;

    final ride = ref.read(rideRequestProvider);
    final st = ride.status;
    if (st != 'pending' && st != 'bidding') return;

    if (_dispatchStatus.ok) {
      if (_dispatchStatus.driversPending > 0) {
        _clearNoSupplyHintIfShown();
        return;
      }
      if (_dispatchStatus.isWaveActive && !_dispatchStatus.isNoDrivers) {
        _clearNoSupplyHintIfShown();
        return;
      }
    }

    final dispatchExhausted = _dispatchStatus.isNoDrivers;
    if (!dispatchExhausted && _searchElapsed < kRiderNoSupplyMinSearchElapsed) {
      return;
    }

    final booking = ref.read(bookingProvider);
    final pickup = booking.pickup;
    if (pickup == null) return;

    NearbySupplyProbe probe;
    try {
      probe = await NearbySupplyService.probeDriverCount(pickup: pickup);
    } catch (_) {
      return;
    }

    if (!mounted) return;
    if (!probe.rpcSucceeded) return;

    if (probe.driverCount > 0) {
      _clearNoSupplyHintIfShown();
      return;
    }

    if (!_showNoDriverCard) {
      setState(() => _showNoDriverCard = true);
    }
  }

  void _updateSearchClock() {
    final created = ref.read(rideRequestProvider).rideCreatedAt;
    if (created == null) {
      _searchElapsed = Duration.zero;
      return;
    }
    final elapsed = DateTime.now().difference(created);
    _searchElapsed = elapsed.isNegative ? Duration.zero : elapsed;
  }

  @override
  void dispose() {
    for (final c in _radarControllers) {
      c.dispose();
    }
    _radarSweepController.dispose();
    _channel?.unsubscribe();
    _bidsChannel?.unsubscribe();
    _clockTimer?.cancel();
    _widgetTimer?.cancel();
    _scheduledWidgetTimer?.cancel();
    _noDriverTimer?.cancel();
    _supplyPollTimer?.cancel();
    _dispatchPollTimer?.cancel();
    _matchingExpandTimer?.cancel();
    _searchWindowTimer?.cancel();
    super.dispose();
  }

  void _subscribeToRide() {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;

    _channel = HeyCabySupabase.client
        .channel('ride_request:$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) async {
            final newStatus = payload.newRecord['status'] as String?;
            if (newStatus == null) return;
            ref.read(rideRequestProvider.notifier).updateStatus(newStatus);
            if (newStatus == 'assigned' || newStatus == 'accepted') {
              final id = ref.read(rideRequestProvider).rideRequestId;
              final pickup =
                  ref.read(bookingProvider).pickup?.displayName ?? '';
              if (id != null) {
                await HeycabyWidgetSync.refreshInstantDriverFromRide(
                  rideId: id,
                  pickup: pickup,
                );
              }
              if (mounted) context.go('/active');
              return;
            }
            const terminalNoMatch = {
              'cancelled',
              'canceled',
              'rejected',
              'declined',
              'missed',
              'expired',
            };
            if (terminalNoMatch.contains(newStatus) && mounted) {
              ref.read(rideRequestProvider.notifier).reset();
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                    content: Text(
                        AppLocalizations.of(context).noDriverFoundMessage)),
              );
              context.go('/home');
            }
          },
        )
        .subscribe();

    _matchingExpandTimer?.cancel();
    _matchingExpandTimer =
        Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!mounted) return;
      final currentId = ref.read(rideRequestProvider).rideRequestId;
      if (currentId != rideId) return;
      final st = ref.read(rideRequestProvider).status;
      if (st != null && st != 'pending') return;
      try {
        await HeyCabySupabase.client.rpc(
          'fn_seed_ride_matching_batch',
          params: {'p_ride_request_id': rideId},
        );
      } catch (_) {}
    });

    _dispatchPollTimer?.cancel();
    _dispatchPollTimer = Timer.periodic(
        const Duration(seconds: 2), (_) => _pollDispatchStatus(rideId));
    unawaited(_pollDispatchStatus(rideId));
  }

  Future<void> _pollDispatchStatus(String rideId) async {
    if (!mounted) return;
    final status = await RiderDispatchStatusService.fetch(rideId);
    if (!mounted) return;
    setState(() => _dispatchStatus = status);

    if (status.driversPending > 0 ||
        (status.isWaveActive && !status.isNoDrivers)) {
      _clearNoSupplyHintIfShown();
    } else if (status.isNoDrivers) {
      unawaited(_evaluateNoSupplyState());
    }

    final rideStatus = ref.read(rideRequestProvider).status;
    if (status.isMatched ||
        rideStatus == 'accepted' ||
        rideStatus == 'assigned') {
      if (mounted) context.go('/active');
    }
  }

  void _pushScheduledWidgetIfNeeded() {
    if (widget.variant != RideMatchingVariant.scheduled) return;
    final booking = ref.read(bookingProvider);
    final sched = booking.scheduledAt;
    if (sched == null) return;
    unawaited(
      HeycabyWidgetSync.syncScheduledRide(
        origin: booking.pickup?.displayName ?? '',
        destination: booking.destination?.displayName ?? '',
        departureEpochSec: sched.millisecondsSinceEpoch ~/ 1000,
      ),
    );
  }

  void _startScheduledWidgetRefreshTimer() {
    _scheduledWidgetTimer?.cancel();
    if (widget.variant != RideMatchingVariant.scheduled) return;
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;
    unawaited(HeycabyWidgetSync.refreshScheduledRideFromRideId(rideId));
    _scheduledWidgetTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final id = ref.read(rideRequestProvider).rideRequestId;
      if (id != null) {
        unawaited(HeycabyWidgetSync.refreshScheduledRideFromRideId(id));
      }
    });
  }

  Future<void> _refreshMarketplaceBidsSnapshot() async {
    if (widget.variant != RideMatchingVariant.marketplace &&
        widget.variant != RideMatchingVariant.terug) {
      return;
    }
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null || !mounted) return;
    try {
      final rows = await HeyCabySupabase.client
          .from('ride_bids')
          .select('bid_amount, driver_id')
          .eq('ride_request_id', rideId);
      if (!mounted) return;
      final list = rows as List<dynamic>? ?? [];
      num? bestAmount;
      String? bestDriverId;
      for (final r in list) {
        final m = r as Map<String, dynamic>;
        final a = m['bid_amount'] as num?;
        if (a == null) continue;
        if (bestAmount == null || a < bestAmount) {
          bestAmount = a;
          bestDriverId = m['driver_id'] as String?;
        }
      }
      String ratingStr = '';
      if (bestDriverId != null) {
        final ts = await HeyCabySupabase.client
            .from('driver_trust_scores')
            .select('score')
            .eq('driver_id', bestDriverId)
            .maybeSingle();
        final s = ts?['score'];
        if (s != null) ratingStr = '$s';
      }
      if (!mounted) return;
      setState(() {
        _marketplaceBidCount = list.length;
        _marketplaceBestPrice = bestAmount != null ? bestAmount.toString() : '';
        _marketplaceBestRating = ratingStr;
      });
    } catch (_) {}
  }

  void _subscribeMarketplaceBids() {
    if (widget.variant != RideMatchingVariant.marketplace &&
        widget.variant != RideMatchingVariant.terug) {
      return;
    }
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) return;
    unawaited(_refreshMarketplaceBidsSnapshot());
    _bidsChannel = HeyCabySupabase.client
        .channel('ride_bids_widget:$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ride_bids',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_request_id',
            value: rideId,
          ),
          callback: (_) => unawaited(_refreshMarketplaceBidsSnapshot()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ride_bids',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_request_id',
            value: rideId,
          ),
          callback: (_) => unawaited(_refreshMarketplaceBidsSnapshot()),
        )
        .subscribe();
  }

  void _startWidgetPushTimer() {
    _widgetTimer?.cancel();
    _widgetTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      final ride = ref.read(rideRequestProvider);
      final id = ride.rideRequestId;
      final st = ride.status;
      if (id == null || st == null) return;
      if (st != 'pending' && st != 'bidding') return;
      final booking = ref.read(bookingProvider);
      final pickup = booking.pickup?.displayName ?? '';
      final dest = booking.destination?.displayName ?? '';
      final created = ride.rideCreatedAt;
      final elapsed =
          created == null ? 0 : DateTime.now().difference(created).inSeconds;
      if (widget.variant == RideMatchingVariant.marketplace ||
          widget.variant == RideMatchingVariant.terug) {
        final expiry = created == null
            ? DateTime.now().millisecondsSinceEpoch ~/ 1000
            : created.add(kRiderDriverSearchWindow).millisecondsSinceEpoch ~/
                1000;
        final status = _marketplaceBidCount > 0 ? 'bids_received' : 'waiting';
        await HeycabyWidgetSync.syncMarketplace(
          origin: pickup,
          destination: dest,
          bidCount: _marketplaceBidCount,
          bestPrice:
              _marketplaceBestPrice.isEmpty ? '—' : _marketplaceBestPrice,
          bestRating:
              _marketplaceBestRating.isEmpty ? '—' : _marketplaceBestRating,
          expiryEpochSec: expiry,
          status: status,
        );
        return;
      }
      if (widget.variant == RideMatchingVariant.instant) {
        await HeycabyWidgetSync.syncInstantSearching(
          pickup: pickup,
          searchElapsedSeconds: elapsed,
        );
      }
    });
  }

  Future<void> _onNotifyMe(BuildContext context) async {
    await RiderMatchingRecoveryActions.notifyMe(ref, context);
  }

  void _onScheduleRide(BuildContext context) {
    RiderMatchingRecoveryActions.schedule(ref, context);
  }

  void _onTryMarketplace(BuildContext context) {
    RiderMatchingRecoveryActions.marketplace(ref, context);
  }

  void _onTryAgainFromExpired() {
    setState(() => _searchExpired = false);
    unawaited(RiderMatchingRecoveryActions.tryAgain(ref, context));
  }

  void _openMatchingAlternativesSheet(
    BuildContext context,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
    AppLocalizations l10n, {
    String? titleOverride,
  }) {
    unawaited(
      showMatchingAlternativesSheet(
        context: context,
        variant: widget.variant,
        colors: colors,
        typo: typo,
        l10n: l10n,
        titleOverride: titleOverride,
        bodyOverride: l10n.searchNoSupplyInlineBody,
        initiallyExpanded: false,
        onNotifyMe: () => _onNotifyMe(context),
        onScheduleRide: () => _onScheduleRide(context),
        onTryMarketplace: () => _onTryMarketplace(context),
      ),
    );
  }

  Future<void> _showCancelDialog(
    BuildContext context,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showHeyCabyConfirmSheet(
      context,
      colors: colors,
      typography: typo,
      title: l10n.cancelBookingTitle,
      message: l10n.noShowWarning,
      dismissLabel: l10n.back,
      confirmLabel: l10n.cancel,
      icon: Icons.close_rounded,
      confirmDestructive: true,
    );
    if (!confirmed || !mounted) return;
    if (!context.mounted) return;
    context.go('/home');
    unawaited(_cancelRideGloballyFromSearching());
  }

  Future<void> _cancelRideGloballyFromSearching() async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId != null) {
      try {
        final identity = await ref.read(riderIdentityProvider.future);
        final token = identity.riderToken;
        if (token != null && token.isNotEmpty) {
          await cancelExpiredRiderOpenRide(
            rideId: rideId,
            riderToken: token,
            cancellationReason: 'rider_cancelled_from_searching_screen',
          );
        }
      } catch (_) {
        // Still clear local state so UI is never stuck on an active search banner.
      }
    }

    await SoundService().playRideCancelled();
    ref.read(rideRequestProvider.notifier).reset();
    await ref.read(activeSearchProvider.notifier).clear();
    ref.invalidate(nearTermRideRequestProvider);
    try {
      await ref.read(nearTermRideRequestProvider.future);
    } catch (_) {}
    ref.invalidate(ridesTabUpcomingRequestsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);
    final screenH = MediaQuery.sizeOf(context).height;
    final sheetInitialSize = _searchExpired ? 0.34 : 0.30;
    final mapActionBottom = screenH * sheetInitialSize + 16;

    void onEditRoute(bool isPickup) => context.push(
          '/search',
          extra: BookingSearchRouteArgs(
            returnToSummaryAfterSave: true,
            initialEditTarget: isPickup
                ? BookingAddressEditTarget.pickup
                : BookingAddressEditTarget.destination,
          ),
        );

    if (widget.variant == RideMatchingVariant.scheduled) {
      return ScheduledMatchingFullscreen(
        booking: booking,
        colors: colors,
        typo: typo,
        l10n: l10n,
        onBackToHome: () => context.go('/home'),
        onTripOptions: () => _openMatchingAlternativesSheet(
          context,
          colors,
          typo,
          l10n,
        ),
        onCancelRide: () => _showCancelDialog(context, colors, typo, l10n),
        onEditRoute: onEditRoute,
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                TripSummaryMapView(
                  height: screenH,
                  cameraBottomPadding: screenH * 0.30 + 28,
                  pickupFocused: true,
                  onRouteMetricsChanged: (_, __) {},
                ),
                MatchingSearchPulseOverlay(
                  rippleControllers: _radarControllers,
                  sweepController: _radarSweepController,
                  color: colors.accent,
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: mapActionBottom,
            child: Row(
              children: [
                _LabeledMapAction(
                  colors: colors,
                  typo: typo,
                  icon: Icons.arrow_back_rounded,
                  label: l10n.back,
                  tone: _MapActionTone.primary,
                  onTap: () => context.go('/home'),
                ),
                const Spacer(),
                _LabeledMapAction(
                  colors: colors,
                  typo: typo,
                  icon: Icons.close_rounded,
                  label: l10n.cancelRide,
                  tone: _MapActionTone.outlined,
                  onTap: () => _showCancelDialog(context, colors, typo, l10n),
                ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: _searchExpired ? 0.34 : 0.30,
            minChildSize: _searchExpired ? 0.28 : 0.24,
            maxChildSize: _searchExpired ? 0.48 : 0.42,
            snap: true,
            snapSizes: _searchExpired ? const [0.34, 0.48] : const [0.30, 0.42],
            builder: (context, scrollController) => MatchingSearchSheet(
              scrollController: scrollController,
              colors: colors,
              typo: typo,
              l10n: l10n,
              title: _sheetTitle(l10n),
              subtitle: _sheetSubtitle(l10n),
              progress: _sheetProgress(),
              pickup: booking.pickup?.displayName ?? '',
              destination: booking.destination?.displayName ?? '',
              variant: widget.variant,
              marketplaceBidCount: _marketplaceBidCount,
              showOptionsHint: _showNoDriverCard && !_searchExpired,
              waveCountdown: _searchExpired ? null : _waveCountdownLabel(),
              expired: _searchExpired,
              onTryAgain: _searchExpired ? _onTryAgainFromExpired : null,
              onNotifyMe: _searchExpired ? () => _onNotifyMe(context) : null,
              onSchedule:
                  _searchExpired ? () => _onScheduleRide(context) : null,
              onMarketplace:
                  _searchExpired ? () => _onTryMarketplace(context) : null,
              onSeeOptions: _showNoDriverCard && !_searchExpired
                  ? () => _openMatchingAlternativesSheet(
                        context,
                        colors,
                        typo,
                        l10n,
                        titleOverride: l10n.searchNoSupplySheetTitle,
                      )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MapActionTone { primary, outlined }

class _LabeledMapAction extends StatelessWidget {
  const _LabeledMapAction({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = _MapActionTone.outlined,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _MapActionTone tone;

  @override
  Widget build(BuildContext context) {
    final isPrimary = tone == _MapActionTone.primary;
    final bg = isPrimary ? colors.accent : colors.card.withValues(alpha: 0.94);
    final border = isPrimary
        ? colors.accent.withValues(alpha: 0.85)
        : colors.accent.withValues(alpha: 0.45);
    final fg = isPrimary ? colors.onAccent : colors.accent;
    final shadow = isPrimary
        ? colors.accent.withValues(alpha: 0.28)
        : colors.text.withValues(alpha: 0.08);

    return Material(
      color: bg,
      elevation: isPrimary ? 6 : 8,
      shadowColor: shadow,
      shape: StadiumBorder(side: BorderSide(color: border, width: 1.5)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        splashColor: isPrimary
            ? colors.onAccent.withValues(alpha: 0.12)
            : colors.accent.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: typo.labelMedium.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
