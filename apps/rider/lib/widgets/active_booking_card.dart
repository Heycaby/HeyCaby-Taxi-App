import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../constants/rider_search_window.dart';
import '../models/ride_matching_variant.dart';
import '../providers/active_search_provider.dart';
import '../providers/marketplace_offers_provider.dart';
import '../providers/near_term_ride_request_provider.dart';
import '../providers/ride_request_provider.dart';
import '../services/sound_service.dart';
import '../services/stale_ride_cleanup.dart';
import '../utils/ride_matching_labels.dart';
import 'active_search_stop_dialog.dart';

final activeBookingInviteCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, rideId) async {
  try {
    final rows = await HeyCabySupabase.client
        .from('ride_request_invites')
        .select('id')
        .eq('ride_request_id', rideId);
    return (rows as List).length;
  } catch (_) {
    return 0;
  }
});

enum ActiveBookingCardPlacement {
  /// Compact chip inside the home bottom sheet; expand on tap.
  homeSheet,

  /// Full card on My rides → Upcoming.
  ridesTab,
}

/// Persistent rider booking state while a request is open.
class ActiveBookingCard extends ConsumerStatefulWidget {
  const ActiveBookingCard({
    super.key,
    this.placement = ActiveBookingCardPlacement.ridesTab,
  });

  final ActiveBookingCardPlacement placement;

  @override
  ConsumerState<ActiveBookingCard> createState() => _ActiveBookingCardState();
}

class _ActiveBookingCardState extends ConsumerState<ActiveBookingCard> {
  Timer? _ticker;
  String? _marketplaceRideId;
  bool _expandedOnHome = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (timer.tick % 8 == 0) {
        final snap = ref.read(nearTermRideRequestProvider).valueOrNull;
        if (snap != null) {
          ref.invalidate(activeBookingInviteCountProvider(snap.id));
          ref.invalidate(nearTermRideRequestProvider);
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _cancelOpenRide({
    required NearTermRideSnapshot snap,
    required HeyCabyColorTokens colors,
    required HeyCabyTypography typo,
    required AppLocalizations l10n,
  }) async {
    final stop = await showActiveSearchStopDialog(
      context: context,
      colors: colors,
      typo: typo,
      l10n: l10n,
    );
    if (!mounted || !stop) return;

    try {
      final identity = await ref.read(riderIdentityProvider.future);
      final token = identity.riderToken;
      if (token != null && token.isNotEmpty) {
        await cancelExpiredRiderOpenRide(
          rideId: snap.id,
          riderToken: token,
          cancellationReason: 'rider_cancelled_from_active_booking_card',
        );
      }
    } catch (_) {
      // Keep the rider unstuck if network cancellation cannot complete.
    }

    ref.invalidate(nearTermRideRequestProvider);
    ref.invalidate(ridesTabUpcomingRequestsProvider);
    final active = ref.read(activeSearchProvider).valueOrNull;
    if (active?.rideRequestId == snap.id) {
      await ref.read(activeSearchProvider.notifier).clear();
    }
    unawaited(SoundService().playRideCancelled());
  }

  Future<void> _openRideFlow(NearTermRideSnapshot snap) async {
    final attached = await ref
        .read(rideRequestProvider.notifier)
        .attachRideRequestForMatchingFlow(snap.id);
    if (!mounted) return;
    final mode =
        attached ? ref.read(rideRequestProvider).bookingMode : snap.bookingMode;
    context.go(rideMatchingVariantForBookingModeString(mode).routePath);
  }

  void _syncMarketplace(NearTermRideSnapshot snap) {
    if (snap.bookingMode != 'marketplace' || _marketplaceRideId == snap.id) {
      return;
    }
    _marketplaceRideId = snap.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(marketplaceOffersProvider.notifier).start(snap.id));
    });
  }

  static String _formatClock(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String _formatShortDateTime(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final material = MaterialLocalizations.of(context);
    final time = TimeOfDay.fromDateTime(local);
    return '${material.formatMediumDate(local)} · ${material.formatTimeOfDay(time)}';
  }

  static String _titleForMode(AppLocalizations l10n, String? mode) {
    switch (mode) {
      case 'marketplace':
        return l10n.activeBookingMarketplaceTitle;
      case 'scheduled':
        return l10n.activeBookingScheduledTitle;
      default:
        return l10n.activeBookingSearchingTitle;
    }
  }

  String _bodyForSnap({
    required BuildContext context,
    required AppLocalizations l10n,
    required NearTermRideSnapshot snap,
    required int notified,
    required int offers,
  }) {
    if (snap.bookingMode == 'scheduled' && snap.scheduledPickupAt != null) {
      final searchStarts =
          snap.scheduledPickupAt!.subtract(const Duration(minutes: 30));
      if (DateTime.now().isBefore(searchStarts)) {
        return l10n.activeBookingScheduledBody(
          _formatShortDateTime(context, snap.scheduledPickupAt!),
          _formatShortDateTime(context, searchStarts),
        );
      }
      return l10n.activeBookingScheduledSearchingBody;
    }

    if (snap.bookingMode == 'marketplace') {
      if (offers > 0) {
        return l10n.activeBookingOffersBody(offers);
      }
      return l10n.activeBookingMarketplaceBody;
    }

    return l10n.activeBookingInstantBody;
  }

  @override
  Widget build(BuildContext context) {
    final asyncSnap = ref.watch(nearTermRideRequestProvider);
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final onHomeSheet =
        widget.placement == ActiveBookingCardPlacement.homeSheet;

    return asyncSnap.when(
      data: (snap) {
        if (snap == null) return const SizedBox.shrink();
        _syncMarketplace(snap);

        final mode = rideMatchingVariantForBookingModeString(snap.bookingMode);
        final inviteCount =
            ref.watch(activeBookingInviteCountProvider(snap.id)).valueOrNull ??
                0;
        final marketplaceState = ref.watch(marketplaceOffersProvider);
        final visibleOffers = snap.bookingMode == 'marketplace'
            ? marketplaceState.visibleOffers(0)
            : const [];
        final offerCount = visibleOffers.length;
        final notified = snap.bookingMode == 'marketplace'
            ? marketplaceState.driversNotifiedCount
            : inviteCount;
        final modeLabel =
            rideMatchingTypeShortLabel(l10n, snap.bookingMode ?? 'instant');
        final scheduledSearchStarts =
            snap.scheduledPickupAt?.subtract(const Duration(minutes: 30));
        final scheduledBeforeSearch = snap.bookingMode == 'scheduled' &&
            scheduledSearchStarts != null &&
            DateTime.now().isBefore(scheduledSearchStarts);
        final trailingStatus = scheduledBeforeSearch
            ? (snap.scheduledPickupAt != null
                ? l10n.scheduledFor(
                    _formatShortDateTime(context, snap.scheduledPickupAt!))
                : l10n.scheduledRideLabel)
            : _formatClock(
                snap.createdAt.add(kRiderDriverSearchWindow).difference(
                      DateTime.now(),
                    ),
              );
        final bestOffer = offerCount > 0
            ? visibleOffers
                .reduce((a, b) => a.sortScore(0) >= b.sortScore(0) ? a : b)
            : null;
        final namedPriceMode =
            snap.bookingMode == 'marketplace' || snap.bookingMode == 'terug';
        final statusLine = scheduledBeforeSearch
            ? l10n.activeBookingScheduledSearchStarts(
                _formatShortDateTime(context, scheduledSearchStarts))
            : namedPriceMode
                ? l10n.activeBookingOffersReceived(offerCount)
                : l10n.activeBookingDriversNotified(notified);
        final icon = mode == RideMatchingVariant.marketplace
            ? Icons.storefront_rounded
            : mode == RideMatchingVariant.terug
                ? Icons.keyboard_return_rounded
                : mode == RideMatchingVariant.scheduled
                    ? Icons.event_available_rounded
                    : Icons.local_taxi_rounded;

        if (onHomeSheet && !_expandedOnHome) {
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
            child: _HomeCompactBookingChip(
              colors: colors,
              typo: typo,
              l10n: l10n,
              icon: icon,
              title: _titleForMode(l10n, snap.bookingMode),
              trailingStatus: trailingStatus,
              statusLine: statusLine,
              destination: snap.destinationAddress,
              onExpand: () => setState(() => _expandedOnHome = true),
              onOpenFlow: () => unawaited(_openRideFlow(snap)),
            ),
          );
        }

        final card = Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(onHomeSheet ? 20 : 28),
              border: Border.all(color: colors.border.withValues(alpha: 0.7)),
              boxShadow: onHomeSheet
                  ? null
                  : [
                      BoxShadow(
                        color: colors.text.withValues(alpha: 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                14,
                onHomeSheet ? 12 : 10,
                14,
                14,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!onHomeSheet) ...[
                    _SheetHandle(colors: colors),
                    const SizedBox(height: 10),
                  ],
                  if (onHomeSheet)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.homeNearTermTripDetails,
                            style: typo.labelLarge.copyWith(
                              color: colors.textSoft,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.activeBookingCollapseHome,
                          onPressed: () =>
                              setState(() => _expandedOnHome = false),
                          icon: Icon(
                            Icons.close_rounded,
                            color: colors.textSoft,
                            size: 22,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      _IconTile(colors: colors, icon: icon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _titleForMode(l10n, snap.bookingMode),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typo.titleMedium.copyWith(
                                      color: colors.text,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    trailingStatus,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typo.labelLarge.copyWith(
                                      color: colors.accent,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!onHomeSheet) ...[
                              const SizedBox(height: 3),
                              Text(
                                l10n.activeBookingTapForDetails,
                                style: typo.bodySmall.copyWith(
                                  color: colors.textMid,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!onHomeSheet) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.textSoft,
                          size: 26,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: colors.border.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 12),
                  _MiniRouteRow(
                    colors: colors,
                    typo: typo,
                    pickup: snap.pickupAddress,
                    destination: snap.destinationAddress,
                  ),
                  const SizedBox(height: 12),
                  _ProgressRow(
                    colors: colors,
                    typo: typo,
                    leading: modeLabel,
                    title: statusLine,
                    subtitle: bestOffer == null
                        ? _bodyForSnap(
                            context: context,
                            l10n: l10n,
                            snap: snap,
                            notified: notified,
                            offers: offerCount,
                          )
                        : l10n.activeBookingBestOffer(
                            bestOffer.bidAmountEuro.toStringAsFixed(0),
                            bestOffer.etaMinutes,
                          ),
                  ),
                  const SizedBox(height: 12),
                  if (scheduledBeforeSearch)
                    _KeepAliveNotice(
                      colors: colors,
                      typo: typo,
                      title: l10n.activeBookingScheduledQueuedTitle,
                      body: l10n.activeBookingScheduledQueuedBody,
                    )
                  else
                    _KeepAliveNotice(
                      colors: colors,
                      typo: typo,
                      title: l10n.activeBookingKeepAliveTitle,
                      body: l10n.activeBookingKeepAliveBody,
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (namedPriceMode) ...[
                        Expanded(
                          child: _PillAction(
                            colors: colors,
                            typo: typo,
                            icon: Icons.trending_up_rounded,
                            label: l10n.marketplaceBoostOffer,
                            onTap: () => context.go(
                              RideMatchingVariant.marketplace.routePath,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: _PillAction(
                          colors: colors,
                          typo: typo,
                          icon: Icons.close_rounded,
                          label: l10n.marketplaceCancelRequest,
                          danger: true,
                          onTap: () => unawaited(
                            _cancelOpenRide(
                              snap: snap,
                              colors: colors,
                              typo: typo,
                              l10n: l10n,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (onHomeSheet) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => unawaited(_openRideFlow(snap)),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(l10n.openAction),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        if (onHomeSheet) {
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
            child: card,
          );
        }

        return InkWell(
          onTap: () => unawaited(_openRideFlow(snap)),
          borderRadius: BorderRadius.circular(22),
          child: card,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _HomeCompactBookingChip extends StatelessWidget {
  const _HomeCompactBookingChip({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.icon,
    required this.title,
    required this.trailingStatus,
    required this.statusLine,
    required this.destination,
    required this.onExpand,
    required this.onOpenFlow,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final IconData icon;
  final String title;
  final String trailingStatus;
  final String statusLine;
  final String destination;
  final VoidCallback onExpand;
  final VoidCallback onOpenFlow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onExpand,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                colors.accent.withValues(alpha: 0.18),
                colors.accent.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colors.accent, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typo.labelLarge.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            trailingStatus,
                            style: typo.labelSmall.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (destination.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          destination,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typo.labelSmall.copyWith(
                            color: colors.textSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.openAction,
                  onPressed: onOpenFlow,
                  icon: Icon(
                    Icons.arrow_forward_rounded,
                    color: colors.accent,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.colors});

  final HeyCabyColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 54,
        height: 5,
        decoration: BoxDecoration(
          color: colors.border.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _KeepAliveNotice extends StatelessWidget {
  const _KeepAliveNotice({
    required this.colors,
    required this.typo,
    required this.title,
    required this.body,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.autorenew_rounded,
              color: colors.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typo.labelLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: typo.bodySmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w600,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.colors, required this.icon});

  final HeyCabyColorTokens colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: colors.accent, size: 22),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.colors,
    required this.typo,
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 9,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            leading,
            style: typo.labelSmall.copyWith(
              color: colors.text,
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
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: typo.bodySmall.copyWith(
                  color: colors.textMid,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsetsDirectional.only(top: 7),
          decoration: BoxDecoration(
            color: colors.accent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _MiniRouteRow extends StatelessWidget {
  const _MiniRouteRow({
    required this.colors,
    required this.typo,
    required this.pickup,
    required this.destination,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String pickup;
  final String destination;

  @override
  Widget build(BuildContext context) {
    if (pickup.isEmpty && destination.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.bg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.64)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pickup.isNotEmpty)
            Row(
              children: [
                _MiniRouteDot(colors: colors, filled: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pickup,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.labelMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          if (pickup.isNotEmpty && destination.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4.5),
              child: Container(
                width: 2,
                height: 12,
                color: colors.border,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (destination.isNotEmpty)
            Row(
              children: [
                _MiniRouteDot(colors: colors, filled: false),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.labelMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MiniRouteDot extends StatelessWidget {
  const _MiniRouteDot({required this.colors, required this.filled});

  final HeyCabyColorTokens colors;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: filled ? colors.accent : colors.card,
        shape: BoxShape.circle,
        border: Border.all(color: colors.accent, width: 2.5),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  const _PillAction({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? colors.error : colors.accent;
    return Material(
      color: danger
          ? colors.error.withValues(alpha: 0.08)
          : colors.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typo.labelLarge.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w900,
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
