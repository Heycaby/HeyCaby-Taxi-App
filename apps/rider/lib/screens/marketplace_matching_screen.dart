import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../constants/rider_search_window.dart';
import '../models/marketplace_driver_offer.dart';
import '../models/ride_matching_variant.dart';
import '../providers/active_search_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/marketplace_offers_provider.dart';
import '../providers/marketplace_pricing_provider.dart';
import '../providers/near_term_ride_request_provider.dart';
import '../providers/recent_destinations_provider.dart';
import '../providers/ride_request_provider.dart';
import '../services/heycaby_widget_sync.dart';
import '../services/rider_ride_lifecycle_engine.dart';
import '../services/sound_service.dart';
import '../services/stale_ride_cleanup.dart';
import '../widgets/driver_search_expired_dialog.dart';
import '../widgets/marketplace/matching/marketplace_offer_card.dart';

/// Marketplace matching — rider chooses among independent driver offers.
class MarketplaceMatchingScreen extends ConsumerStatefulWidget {
  const MarketplaceMatchingScreen({super.key});

  @override
  ConsumerState<MarketplaceMatchingScreen> createState() =>
      _MarketplaceMatchingScreenState();
}

class _MarketplaceMatchingScreenState
    extends ConsumerState<MarketplaceMatchingScreen> {
  Timer? _searchWindowTimer;
  Timer? _countdownTimer;
  String? _acceptingBidId;
  bool _bootstrapped = false;
  bool _isCancelling = false;
  Duration _expiresIn = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _searchWindowTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final ok = await bootstrapMarketplaceRide(ref);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).rideBookingFailed)),
      );
      context.go('/marketplace');
      return;
    }

    final booking = ref.read(bookingProvider);
    if (booking.destination != null) {
      await ref.read(recentDestinationsProvider.notifier).recordDestination(
            fullAddress: booking.destination!.fullAddress,
            lat: booking.destination!.lat,
            lng: booking.destination!.lng,
          );
    }

    final st = ref.read(rideRequestProvider).status;
    if (st == 'assigned' ||
        st == 'accepted' ||
        st == 'driver_found' ||
        st == 'driver_en_route' ||
        st == 'driver_arrived' ||
        st == 'in_progress') {
      if (mounted) context.go('/active');
      return;
    }

    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null) {
      if (mounted) context.go('/marketplace');
      return;
    }

    await ref.read(marketplaceOffersProvider.notifier).start(rideId);
    _startExpiryCountdown();
    _scheduleSearchWindowExpiry();
  }

  void _startExpiryCountdown() {
    _countdownTimer?.cancel();
    void tick() {
      final created = ref.read(rideRequestProvider).rideCreatedAt;
      if (created == null) return;
      final left =
          created.add(kRiderDriverSearchWindow).difference(DateTime.now());
      if (mounted) {
        setState(() => _expiresIn = left.isNegative ? Duration.zero : left);
      }
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _scheduleSearchWindowExpiry() {
    _searchWindowTimer?.cancel();
    final created = ref.read(rideRequestProvider).rideCreatedAt;
    if (created == null) return;
    final left =
        created.add(kRiderDriverSearchWindow).difference(DateTime.now());
    if (left <= Duration.zero) {
      unawaited(_onSearchExpired());
      return;
    }
    _searchWindowTimer = Timer(left, _onSearchExpired);
  }

  Future<void> _onSearchExpired() async {
    if (!mounted) return;
    await ref.read(rideRequestProvider.notifier).cancelStaleOpenRequest();
    if (!mounted) return;
    await showDriverSearchExpiredDialog(
      context,
      ref,
      markGrowthModalDismissedAfter: false,
      variant: RideMatchingVariant.marketplace,
    );
    if (mounted) context.go('/home');
  }

  Future<void> _handleLifecycleRecord(
    RiderRideBackendRecord projection,
  ) async {
    if (!mounted) return;
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId == null || projection.rideRequestId != rideId) return;
    final newStatus =
        (projection.record['provider_status'] ?? projection.record['status'])
            ?.toString()
            .toLowerCase();
    if (newStatus != 'assigned' &&
        newStatus != 'accepted' &&
        newStatus != 'driver_found' &&
        newStatus != 'driver_en_route') {
      return;
    }
    await HeycabyWidgetSync.refreshInstantDriverFromRide(
      rideId: rideId,
      pickup: ref.read(bookingProvider).pickup?.displayName ?? '',
    );
    if (mounted) context.go('/active');
  }

  MarketplaceDriverOffer? _offerById(String bidId) {
    for (final o in ref.read(marketplaceOffersProvider).offers) {
      if (o.id == bidId) return o;
    }
    return null;
  }

  Future<void> _acceptOffer(String bidId) async {
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    final offer = _offerById(bidId);
    if (rideId == null || offer == null) return;

    setState(() => _acceptingBidId = bidId);
    HapticService.mediumTap();
    final ok = await acceptMarketplaceOffer(
      ref: ref,
      offer: offer,
      rideRequestId: rideId,
    );
    if (!mounted) return;
    setState(() => _acceptingBidId = null);
    if (ok) {
      HapticService.success();
      context.go('/active');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).connectionProblem)),
    );
  }

  Future<void> _declineOffer(String bidId) async {
    final offer = _offerById(bidId);
    if (offer == null) return;
    ref.read(marketplaceOffersProvider.notifier).dismissLocally(bidId);
    unawaited(declineMarketplaceOffer(offer: offer));
  }

  Future<void> _confirmCancelRequest() async {
    if (_isCancelling) return;
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final l10n = AppLocalizations.of(context);

    final confirmed = await showHeyCabyConfirmSheet(
      context,
      colors: colors,
      typography: typo,
      title: l10n.marketplaceCancelRequest,
      message: l10n.marketplaceCancelRequestConfirm,
      dismissLabel: l10n.back,
      confirmLabel: l10n.marketplaceCancelRequest,
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

    _searchWindowTimer?.cancel();
    _countdownTimer?.cancel();
    final rideId = ref.read(rideRequestProvider).rideRequestId;
    if (rideId != null) {
      try {
        final identity = await ref.read(riderIdentityProvider.future);
        final ride = ref.read(rideRequestProvider);
        await cancelExpiredRiderOpenRide(
          rideId: rideId,
          riderToken: ride.riderToken ?? identity.riderToken,
          cancellationReason: 'rider_cancelled_marketplace_matching',
        );
      } catch (_) {}
    }

    await SoundService().playRideCancelled();
    ref.read(rideRequestProvider.notifier).reset();
    await ref.read(activeSearchProvider.notifier).clear();
    ref.invalidate(nearTermRideRequestProvider);
    ref.invalidate(ridesTabUpcomingRequestsProvider);

    if (!mounted) return;
    setState(() => _isCancelling = false);
    context.go('/home');
  }

  Future<void> _showBoostSheet() async {
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
                  l10n.marketplaceBoostOffer,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(l10n.marketplaceBoostOfferSubtitle),
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
    final messenger = ScaffoldMessenger.of(context);
    final ok = await boostMarketplaceOffer(ref: ref, newEuro: picked);
    if (!mounted) return;
    if (ok) {
      await ref.read(marketplaceOffersProvider.notifier).refresh();
      messenger.showSnackBar(
        SnackBar(content: Text(formatMarketplaceEuro(picked.toDouble()))),
      );
    }
  }

  String _formatCountdown(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);
    final offersState = ref.watch(marketplaceOffersProvider);
    final riderOffer = (booking.marketplaceBidEuro ?? 0).toDouble();
    final visible = offersState.visibleOffers(riderOffer);
    final notified = offersState.driversNotifiedCount > 0
        ? offersState.driversNotifiedCount
        : offersState.nearbyDriverCount;
    ref.listen<RiderRideBackendRecord?>(
      riderRideBackendRecordProvider,
      (previous, next) {
        if (next != null) unawaited(_handleLifecycleRecord(next));
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isCancelling) return;
        unawaited(_confirmCancelRequest());
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 0),
                child: Row(
                  children: [
                    Material(
                      color: colors.card,
                      elevation: 2,
                      shadowColor: colors.text.withValues(alpha: 0.12),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _isCancelling ? null : _confirmCancelRequest,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.close_rounded,
                              color: colors.text, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.accentL,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.storefront_rounded,
                          color: colors.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.marketplaceMatchingHeadline,
                            style: typo.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.text,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            l10n.marketplaceMatchingNotifySubtitle,
                            style: typo.bodySmall.copyWith(
                              color: colors.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
                  children: [
                    _StatusCard(
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                      notifiedCount: notified,
                    ),
                    const SizedBox(height: 20),
                    if (offersState.isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colors.accent,
                          ),
                        ),
                      )
                    else if (visible.isEmpty) ...[
                      _WaitingPanel(colors: colors, typo: typo, l10n: l10n),
                    ] else ...[
                      Text(
                        l10n.marketplaceOffersFromDrivers,
                        style: typo.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...visible.asMap().entries.map(
                            (entry) => MarketplaceOfferCard(
                              offer: entry.value,
                              riderOfferEuro: riderOffer,
                              colors: colors,
                              typo: typo,
                              l10n: l10n,
                              recommended: entry.key == 0,
                              isBusy: _acceptingBidId == entry.value.id,
                              onAccept: () => _acceptOffer(entry.value.id),
                              onDecline: () => _declineOffer(entry.value.id),
                            ),
                          ),
                    ],
                    const SizedBox(height: 16),
                    _ExpiryCard(
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                      countdown: _formatCountdown(_expiresIn),
                    ),
                    const SizedBox(height: 12),
                    _BoostCard(
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                      onTap: _showBoostSheet,
                    ),
                    const SizedBox(height: 24),
                    _InstructionFooter(colors: colors, typo: typo, l10n: l10n),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  HeyCabySpacing.screenEdge,
                  8,
                  HeyCabySpacing.screenEdge,
                  MediaQuery.paddingOf(context).bottom + 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isCancelling ? null : _confirmCancelRequest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(
                          color: colors.error.withValues(alpha: 0.7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _isCancelling
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.error,
                            ),
                          )
                        : Text(
                            l10n.marketplaceCancelRequest,
                            style: typo.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.notifiedCount,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final int notifiedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.accentL,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.bar_chart_rounded, color: colors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.marketplaceDriversReceivedRequest(notifiedCount),
                  style: typo.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                Text(
                  l10n.marketplaceExpectedWait,
                  style: typo.bodySmall.copyWith(color: colors.textMid),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiryCard extends StatelessWidget {
  const _ExpiryCard({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.countdown,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String countdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: colors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.marketplaceOffersExpireIn,
              style: typo.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textMid,
              ),
            ),
          ),
          Text(
            countdown,
            style: typo.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoostCard extends StatelessWidget {
  const _BoostCard({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.trending_up, color: colors.textMid),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.marketplaceBoostOffer,
                      style: typo.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.marketplaceBoostOfferSubtitle,
                      style: typo.bodySmall.copyWith(color: colors.textMid),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionFooter extends StatelessWidget {
  const _InstructionFooter({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.accent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '3',
            style: typo.labelLarge.copyWith(
              color: colors.onAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.marketplaceReceiveChooseTitle,
                style: typo.titleSmall.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              for (final bullet in [
                l10n.marketplaceReceiveChooseBullet1,
                l10n.marketplaceReceiveChooseBullet2,
                l10n.marketplaceReceiveChooseBullet3,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: typo.bodySmall),
                      Expanded(
                        child: Text(
                          bullet,
                          style: typo.bodySmall.copyWith(color: colors.textMid),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.marketplaceMatchingWaiting,
            style: typo.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.marketplaceMatchingWaitingBody,
            style: typo.bodySmall.copyWith(
              color: colors.textMid,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
