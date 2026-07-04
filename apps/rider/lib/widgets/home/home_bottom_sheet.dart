import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../booking_draft_resume_card.dart';
import '../../providers/rider_home_banners_provider.dart';
import 'home_announcement_banner.dart';
import 'home_booking_options_grid.dart';
import 'home_recent_places_section.dart';
import 'home_ride_again_section.dart';
import 'home_search_hero_card.dart';

/// Draggable home sheet — V2 information hierarchy (search first).
class HomeBottomSheet extends ConsumerWidget {
  const HomeBottomSheet({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.sheetController,
    required this.nearbyTaxiCount,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final DraggableScrollableController sheetController;
  final int nearbyTaxiCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(riderHomeBannersProvider);
    final banners = bannersAsync.valueOrNull ?? const [];
    final announcement = pickRiderHomeBanner(
      banners: banners,
      nearbyTaxiCount: nearbyTaxiCount,
    );
    final showFallbackNoSupply = announcement == null && nearbyTaxiCount == 0;

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
            HomeSearchHeroCard(colors: colors, typo: typo, l10n: l10n),
            if (announcement != null)
              HomeAnnouncementBanner(
                banner: announcement,
                colors: colors,
                typo: typo,
              ),
            if (showFallbackNoSupply)
              HomeAvailabilityCard(colors: colors, typo: typo, l10n: l10n),
            HomeRideAgainSection(colors: colors, typo: typo, l10n: l10n),
            HomeBookingOptionsGrid(colors: colors, typo: typo, l10n: l10n),
            HomeRecentPlacesSection(colors: colors, typo: typo, l10n: l10n),
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
