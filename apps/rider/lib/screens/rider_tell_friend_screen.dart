import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_rider/models/rider_community_growth_models.dart';
import 'package:heycaby_rider/providers/rider_invite_impact_provider.dart';
import 'package:heycaby_rider/providers/rider_invite_url_provider.dart';
import 'package:heycaby_rider/widgets/community/rider_grow_city_share_block.dart';
import 'package:heycaby_rider/widgets/community/rider_grow_city_why_sheet.dart';
import 'package:heycaby_rider/widgets/community/tell_friend_screen_header.dart';
import 'package:heycaby_rider/widgets/rider_grow_city_milestone_celebration.dart';
import 'package:heycaby_rider/widgets/rider_grow_city_parts.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// **Grow Your City** — minimalist community growth hub (share-first).
class RiderTellFriendScreen extends ConsumerWidget {
  const RiderTellFriendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final identityAsync = ref.watch(riderIdentityProvider);
    final shareUrl = ref.watch(riderInviteShareUrlProvider);
    final shareReady = ref.watch(riderInviteShareReadyProvider);
    final cityStatsAsync = ref.watch(communityGrowthStatsProvider);
    final bottomPad =
        MediaQuery.paddingOf(context).bottom + HeyCabySpacing.sectionMedium;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: identityAsync.when(
          data: (identity) {
            final id = identity.identityId;
            final hasRef = id != null && id.isNotEmpty;
            final impactAsync = hasRef
                ? ref.watch(riderInviteImpactProvider)
                : const AsyncValue.data(RiderInviteImpact.empty);

            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TellFriendScreenHeader(colors: colors, typo: typo, l10n: l10n),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      HeyCabySpacing.screenEdge,
                      HeyCabySpacing.component,
                      HeyCabySpacing.screenEdge,
                      bottomPad,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RiderGrowCityPitch(
                          colors: colors,
                          typo: typo,
                          l10n: l10n,
                        ).animate().fadeIn(
                              duration: 220.ms,
                              curve: Curves.easeOut,
                            ),
                        const SizedBox(height: HeyCabySpacing.sectionMedium),
                        RiderGrowCityShareBlock(
                          colors: colors,
                          typo: typo,
                          l10n: l10n,
                          shareUrl: shareUrl,
                          shareReady: shareReady,
                        ).animate().fadeIn(
                              duration: 260.ms,
                              delay: 40.ms,
                              curve: Curves.easeOut,
                            ),
                        const SizedBox(height: HeyCabySpacing.sectionMedium),
                        cityStatsAsync.when(
                          data: (stats) => RiderGrowCityMilestoneStrip(
                            stats: stats,
                            colors: colors,
                            typo: typo,
                            l10n: l10n,
                          ),
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (_, __) => RiderGrowCityMilestoneStrip(
                            stats: CommunityGrowthStats.empty,
                            colors: colors,
                            typo: typo,
                            l10n: l10n,
                          ),
                        ).animate().fadeIn(
                              duration: 280.ms,
                              delay: 80.ms,
                              curve: Curves.easeOut,
                            ),
                        const SizedBox(height: HeyCabySpacing.component),
                        impactAsync.when(
                          data: (impact) {
                            final hasImpact = impact.peopleInvited > 0 ||
                                impact.joined > 0 ||
                                impact.completedRides > 0;
                            if (!hasImpact) return const SizedBox.shrink();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                RiderGrowCityImpactCompact(
                                  impact: impact,
                                  colors: colors,
                                  typo: typo,
                                  l10n: l10n,
                                ),
                                if (impact.joined > 0) ...[
                                  const SizedBox(height: HeyCabySpacing.component),
                                  RiderCommunityBadgesRow(
                                    joined: impact.joined,
                                    colors: colors,
                                    typo: typo,
                                    l10n: l10n,
                                  ),
                                ],
                              ],
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 4),
                        RiderGrowCityLearnMoreButton(
                          colors: colors,
                          typo: typo,
                          l10n: l10n,
                          onPressed: () => showRiderGrowCityWhySheet(
                            context,
                            colors: colors,
                            typo: typo,
                            l10n: l10n,
                          ),
                        ),
                        const SizedBox(height: HeyCabySpacing.component),
                        Text(
                          l10n.tellAFriendSocialProof,
                          textAlign: TextAlign.center,
                          style: typo.labelSmall.copyWith(
                            color: colors.textSoft,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );

            return cityStatsAsync.when(
              data: (stats) => RiderGrowCityMilestoneCelebration(
                stats: stats,
                colors: colors,
                typo: typo,
                l10n: l10n,
                child: content,
              ),
              loading: () => content,
              error: (_, __) => content,
            );
          },
          loading: () => Column(
            children: [
              TellFriendScreenHeader(colors: colors, typo: typo, l10n: l10n),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          error: (_, __) => Column(
            children: [
              TellFriendScreenHeader(colors: colors, typo: typo, l10n: l10n),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.tellAFriendLinkUnavailableHint,
                      textAlign: TextAlign.center,
                      style: typo.bodyMedium.copyWith(color: colors.textMid),
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
