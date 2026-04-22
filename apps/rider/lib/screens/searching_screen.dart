import 'dart:async';
import 'dart:math' show sin, pi;

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
import '../providers/recent_destinations_provider.dart';
import '../providers/ride_request_provider.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/rider_notify_search_notifications.dart';
import '../widgets/driver_search_expired_dialog.dart';
import '../widgets/matching_alternatives_card.dart';
import '../widgets/matching_marketplace_banner.dart';
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
  // Radar rings — 3 staggered controllers
  late final List<AnimationController> _radarControllers;
  // Dot orbit controller
  late final AnimationController _orbitController;

  RealtimeChannel? _channel;
  RealtimeChannel? _bidsChannel;
  Timer? _factsTimer;
  Timer? _widgetTimer;
  Timer? _scheduledWidgetTimer;
  Timer? _noDriverTimer;
  Timer? _matchingExpandTimer;
  Timer? _searchWindowTimer;
  int _currentFactIndex = 0;
  bool _showNoDriverCard = false;

  List<String> _facts = [];
  int _marketplaceBidCount = 0;
  String _marketplaceBestPrice = '';
  String _marketplaceBestRating = '';

  @override
  void initState() {
    super.initState();
    _radarControllers = List.generate(3, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      );
      Future.delayed(Duration(milliseconds: i * 800), () {
        if (mounted) ctrl.repeat();
      });
      return ctrl;
    });

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
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
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text(l10n.rideBookingFailed)),
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
      case RideMatchingVariant.scheduled:
        return l10n.matchingTitleScheduled;
    }
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
    await showDriverSearchExpiredDialog(
      context,
      ref,
      markGrowthModalDismissedAfter: false,
    );
    if (mounted) context.go('/home');
  }

  void _startTimersAndFacts() {
    if (!mounted) return;
    if (widget.variant == RideMatchingVariant.scheduled) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    _facts = [
      l10n.searchFactDriversKeep100,
      l10n.searchFactNoSurgePricing,
      l10n.searchFactAllVerified,
      l10n.searchFactMarketplace,
      l10n.searchFactZZP,
      l10n.searchFactSaveAddresses,
      l10n.searchFactPayHowYouWant,
    ];

    _factsTimer?.cancel();
    _factsTimer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (mounted && _facts.isNotEmpty) {
        setState(() => _currentFactIndex = (_currentFactIndex + 1) % _facts.length);
      }
    });

    _noDriverTimer?.cancel();
    _noDriverTimer = Timer(kRiderNoDriverCardDelay, () {
      if (mounted) setState(() => _showNoDriverCard = true);
    });
  }

  @override
  void dispose() {
    for (final c in _radarControllers) {
      c.dispose();
    }
    _orbitController.dispose();
    _channel?.unsubscribe();
    _bidsChannel?.unsubscribe();
    _factsTimer?.cancel();
    _widgetTimer?.cancel();
    _scheduledWidgetTimer?.cancel();
    _noDriverTimer?.cancel();
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
            }
          },
        )
        .subscribe();

    _matchingExpandTimer?.cancel();
    _matchingExpandTimer = Timer.periodic(const Duration(seconds: 22), (_) async {
      if (!mounted) return;
      final currentId = ref.read(rideRequestProvider).rideRequestId;
      if (currentId != rideId) return;
      final st = ref.read(rideRequestProvider).status;
      if (st != null && st != 'pending') return;
      try {
        await HeyCabySupabase.client.rpc(
          'fn_seed_ride_matching_batch',
          params: {'p_ride_request_id': rideId, 'p_batch_size': 4, 'p_window_seconds': 30},
        );
      } catch (_) {}
    });
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
    _scheduledWidgetTimer =
        Timer.periodic(const Duration(seconds: 60), (_) {
      final id = ref.read(rideRequestProvider).rideRequestId;
      if (id != null) {
        unawaited(HeycabyWidgetSync.refreshScheduledRideFromRideId(id));
      }
    });
  }

  Future<void> _refreshMarketplaceBidsSnapshot() async {
    if (widget.variant != RideMatchingVariant.marketplace) return;
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
        _marketplaceBestPrice =
            bestAmount != null ? bestAmount.toString() : '';
        _marketplaceBestRating = ratingStr;
      });
    } catch (_) {}
  }

  void _subscribeMarketplaceBids() {
    if (widget.variant != RideMatchingVariant.marketplace) return;
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
      final elapsed = created == null
          ? 0
          : DateTime.now().difference(created).inSeconds;
      if (widget.variant == RideMatchingVariant.marketplace) {
        final expiry = created == null
            ? DateTime.now().millisecondsSinceEpoch ~/ 1000
            : created
                    .add(kRiderDriverSearchWindow)
                    .millisecondsSinceEpoch ~/
                1000;
        final status =
            _marketplaceBidCount > 0 ? 'bids_received' : 'waiting';
        await HeycabyWidgetSync.syncMarketplace(
          origin: pickup,
          destination: dest,
          bidCount: _marketplaceBidCount,
          bestPrice: _marketplaceBestPrice.isEmpty ? '—' : _marketplaceBestPrice,
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
    await RiderNotifySearchNotifications.ensureNotifyPermission();
    if (!context.mounted) return;
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    final booking = ref.read(bookingProvider);
    final mode = bookingModeStorageString(booking.effectiveRideMode);
    await ref.read(activeSearchProvider.notifier).start(
          rideRequestId: rideId,
          bookingMode: mode,
          pickupSummary: booking.pickup?.displayName,
          destinationSummary: booking.destination?.displayName,
        );
    ref.read(rideRequestProvider.notifier).reset();
    if (context.mounted) context.go('/home');
  }

  void _onScheduleRide(BuildContext context) {
    ref.read(rideRequestProvider.notifier).reset();
    // Keep booking state (pickup/destination already set) and go to schedule
    ref.read(bookingProvider.notifier).setScheduled();
    context.go('/search');
  }

  void _onTryMarketplace(BuildContext context) {
    ref.read(rideRequestProvider.notifier).reset();
    ref.read(bookingProvider.notifier).setMarketplace();
    if (context.mounted) {
      context.go(RideMatchingVariant.marketplace.routePath);
    }
  }

  void _openMatchingAlternativesSheet(
    BuildContext context,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
    AppLocalizations l10n,
  ) {
    unawaited(
      showMatchingAlternativesSheet(
        context: context,
        variant: widget.variant,
        colors: colors,
        typo: typo,
        l10n: l10n,
        onNotifyMe: () => _onNotifyMe(context),
        onScheduleRide: () => _onScheduleRide(context),
        onTryMarketplace: () => _onTryMarketplace(context),
      ),
    );
  }

  void _showCancelDialog(
    BuildContext context,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
    AppLocalizations l10n,
  ) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.cancel, style: typo.headingMedium.copyWith(color: colors.text)),
        content: Text(l10n.noShowWarning, style: typo.bodyMedium.copyWith(color: colors.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.back, style: typo.labelLarge.copyWith(color: colors.textMid)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
              ref.read(rideRequestProvider.notifier).reset();
              context.go('/home');
            },
            child: Text(l10n.cancel, style: typo.labelLarge.copyWith(color: colors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);

    void onEditRoute(bool isPickup) => context.go('/search');

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
      floatingActionButton: _showNoDriverCard
          ? FloatingActionButton(
              onPressed: () => _openMatchingAlternativesSheet(
                context,
                colors,
                typo,
                l10n,
              ),
              tooltip: l10n.matchingAlternativesFabTooltip,
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, top: 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: GestureDetector(
                  onTap: () =>
                      _showCancelDialog(context, colors, typo, l10n),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.bgAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(Icons.close, color: colors.text, size: 20),
                  ),
                ),
              ),
            ),
            if (widget.variant == RideMatchingVariant.marketplace)
              MarketplaceMatchingBanner(
                colors: colors,
                typo: typo,
                l10n: l10n,
              ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RadarAnimation(
                    controllers: _radarControllers,
                    orbitController: _orbitController,
                    colors: colors,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _matchingTitle(l10n),
                    style: typo.headingMedium.copyWith(color: colors.text),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ));
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: _DidYouKnowCard(
                      key: ValueKey<int>(_currentFactIndex),
                      fact: _facts.isNotEmpty
                          ? _facts[_currentFactIndex]
                          : '',
                      colors: colors,
                      typo: typo,
                    ),
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

// ── Did-you-know rotating card (readable type scale) ─────────────────────────
class _DidYouKnowCard extends StatelessWidget {
  final String fact;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _DidYouKnowCard({
    super.key,
    required this.fact,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    final dot = fact.indexOf('. ');
    final hasSplit = dot > 0 && dot < 100;
    final title = hasSplit ? fact.substring(0, dot + 1).trim() : fact.trim();
    final body = hasSplit ? fact.substring(dot + 2).trim() : '';

    return Container(
      margin: const EdgeInsetsDirectional.symmetric(horizontal: 24),
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: colors.accentL,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: typo.headingSmall.copyWith(
              color: colors.text,
              fontSize: 20,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              body,
              style: typo.bodyLarge.copyWith(
                color: colors.textMid,
                fontSize: 15,
                height: 1.65,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Radar animation ───────────────────────────────────────────────────────────
class _RadarAnimation extends StatelessWidget {
  final List<AnimationController> controllers;
  final AnimationController orbitController;
  final HeyCabyColorTokens colors;

  const _RadarAnimation({
    required this.controllers,
    required this.orbitController,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radar rings
          ...controllers.asMap().entries.map((entry) {
            return AnimatedBuilder(
              animation: entry.value,
              builder: (_, __) {
                final t = entry.value.value;
                final scale = 0.2 + (t * 0.8);
                final opacity = (1.0 - t).clamp(0.0, 1.0);
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Subtle filled background circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent.withValues(alpha: 0.08),
            ),
          ),

          // Orbiting amber dots
          AnimatedBuilder(
            animation: orbitController,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = 0; i < 4; i++)
                    _orbitDot(i, orbitController.value, colors),
                ],
              );
            },
          ),

          // Centre icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accent,
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.local_taxi, color: colors.bg, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _orbitDot(int index, double progress, HeyCabyColorTokens colors) {
    const orbitRadius = 72.0;
    const dotSize = 8.0;
    final angle = (progress + index / 4) * 2 * pi;
    // Offset into Stack — center is at (100,100) in the 200x200 box
    final dx = 100.0 + orbitRadius * sin(angle) - dotSize / 2;
    final dy = 100.0 - orbitRadius * sin(angle + pi / 2) - dotSize / 2;
    // Vary opacity by position to give depth
    final opacity = (0.4 + 0.5 * ((sin(angle) + 1) / 2)).clamp(0.0, 1.0);

    return Positioned(
      left: dx,
      top: dy,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.accent,
          ),
        ),
      ),
    );
  }
}

