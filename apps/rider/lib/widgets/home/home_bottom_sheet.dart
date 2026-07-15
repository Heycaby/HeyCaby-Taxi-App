import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../booking_draft_resume_card.dart';
import '../active_booking_card.dart';
import '../../providers/near_term_ride_request_provider.dart';
import '../../providers/rider_home_banners_provider.dart';
import '../../services/nearby_supply_service.dart';
import 'home_announcement_banner.dart';
import 'home_favorite_supply_insight.dart';
import 'home_supply_insight.dart';
import 'home_booking_options_grid.dart';
import 'home_quick_places_section.dart';
import 'home_ride_again_section.dart';
import 'home_search_hero_card.dart';

/// Draggable home sheet — search first, then supply, quick destinations, modes.
///
/// Hierarchy (do not reorder state-critical cards at the top):
/// 1. Draft resume + active booking (live ride recovery)
/// 2. Search hero + contextual supply / announcement
/// 3. Booking modes (Taxi Terug, airport, schedule, favourites)
/// 4. Quick places (saved addresses + recent + saved trips — one row)
/// 5. Ride again (trusted driver — only when favourites exist)
class HomeBottomSheet extends ConsumerWidget {
  const HomeBottomSheet({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.sheetController,
    required this.nearbyTaxiCount,
    required this.nearbySupplyKnown,
    required this.supplySnapshot,
    required this.favoriteSupplySnapshot,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final DraggableScrollableController sheetController;
  final int nearbyTaxiCount;
  final bool nearbySupplyKnown;
  final RiderSupplySnapshot supplySnapshot;
  final RiderFavoriteSupplySnapshot favoriteSupplySnapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(riderHomeBannersProvider);
    final banners = bannersAsync.valueOrNull ?? const [];
    final hasActiveBooking =
        ref.watch(nearTermRideRequestProvider).valueOrNull != null;
    final bookingExpanded = ref.watch(activeBookingHomeExpandedProvider);
    final hideHomeChrome = hasActiveBooking && bookingExpanded;

    ref.listen<AsyncValue<NearTermRideSnapshot?>>(nearTermRideRequestProvider,
        (previous, next) {
      if (next.valueOrNull == null &&
          ref.read(activeBookingHomeExpandedProvider)) {
        ref.read(activeBookingHomeExpandedProvider.notifier).state = false;
      }
    });
    final announcement = pickRiderHomeBanner(
      banners: banners,
      nearbyTaxiCount: nearbyTaxiCount,
    );
    final showFavoriteSupplyInsight = !hasActiveBooking &&
        announcement == null &&
        favoriteSupplySnapshot.rpcSucceeded &&
        favoriteSupplySnapshot.onlineCount > 0;
    final showSupplyInsight = !hasActiveBooking &&
        nearbySupplyKnown &&
        announcement == null &&
        !showFavoriteSupplyInsight &&
        resolveHomeSupplyInsight(snapshot: supplySnapshot, l10n: l10n) != null;

    return DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: 0.52,
      minChildSize: 0.28,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.28, 0.52, 0.88],
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.zero,
          children: [
            _DragHandle(colors: colors),
            const BookingDraftResumeCard(),
            const ActiveBookingCard(
              placement: ActiveBookingCardPlacement.homeSheet,
            ),
            if (!hideHomeChrome) ...[
              HomeSearchHeroCard(colors: colors, typo: typo, l10n: l10n),
              if (announcement != null)
                HomeAnnouncementBanner(
                  banner: announcement,
                  colors: colors,
                  typo: typo,
                ),
              if (showFavoriteSupplyInsight)
                HomeFavoriteSupplyInsightCard(
                  snapshot: favoriteSupplySnapshot,
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                ),
              if (showSupplyInsight)
                HomeSupplyInsightCard(
                  snapshot: supplySnapshot,
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                ),
              HomeBookingOptionsGrid(colors: colors, typo: typo, l10n: l10n),
              HomeQuickPlacesSection(colors: colors, typo: typo, l10n: l10n),
            ] else ...[
              if (announcement != null)
                HomeAnnouncementBanner(
                  banner: announcement,
                  colors: colors,
                  typo: typo,
                ),
              if (showFavoriteSupplyInsight)
                HomeFavoriteSupplyInsightCard(
                  snapshot: favoriteSupplySnapshot,
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                ),
              if (showSupplyInsight)
                HomeSupplyInsightCard(
                  snapshot: supplySnapshot,
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                ),
            ],
            HomeRideAgainSection(colors: colors, typo: typo, l10n: l10n),
            SizedBox(
              height: kBottomNavigationBarHeight +
                  MediaQuery.paddingOf(context).bottom +
                  20,
            ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.colors});

  final HeyCabyColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
