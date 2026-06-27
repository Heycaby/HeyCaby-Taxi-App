import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_rider/models/rider_community_growth_models.dart';
import 'package:heycaby_rider/providers/rider_invite_impact_provider.dart';
import 'package:heycaby_rider/providers/rider_invite_url_provider.dart';
import 'package:heycaby_rider/widgets/rider_grow_city_milestone_celebration.dart';
import 'package:heycaby_rider/widgets/rider_grow_city_parts.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:share_plus/share_plus.dart';

/// **Grow Your City** — community growth hub (not a cash referral program).
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
    final sharingAppStore = ref.watch(riderSharingAppStoreProvider);
    final cityStatsAsync = ref.watch(communityGrowthStatsProvider);
    final bottomPad =
        MediaQuery.paddingOf(context).bottom + HeyCabySpacing.sectionMedium;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: colors.border),
        ),
        title: Text(
          l10n.tellAFriendScreenTitle,
          style: typo.headingSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.15,
          ),
        ),
      ),
      body: identityAsync.when(
        data: (identity) {
          final id = identity.identityId;
          final hasRef = id != null && id.isNotEmpty;
          final impactAsync = hasRef
              ? ref.watch(riderInviteImpactProvider)
              : const AsyncValue.data(RiderInviteImpact.empty);

          final content = SingleChildScrollView(
            padding: EdgeInsetsDirectional.fromSTEB(
              HeyCabySpacing.screenEdge,
              HeyCabySpacing.component,
              HeyCabySpacing.screenEdge,
              bottomPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cityStatsAsync.when(
                  data: (stats) => RiderGrowCityHero(
                    regionName: stats.regionName,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                  ),
                  loading: () => RiderGrowCityHero(
                    regionName: 'Netherlands',
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                  ),
                  error: (_, __) => RiderGrowCityHero(
                    regionName: 'Netherlands',
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                  ),
                ).animate().fadeIn(duration: 260.ms, curve: Curves.easeOut),
                const SizedBox(height: HeyCabySpacing.sectionMedium),
                cityStatsAsync.when(
                  data: (stats) => RiderCommunityProgressCard(
                    stats: stats,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => RiderCommunityProgressCard(
                    stats: CommunityGrowthStats.empty,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                  ),
                ).animate().fadeIn(
                      duration: 300.ms,
                      delay: 60.ms,
                      curve: Curves.easeOut,
                    ),
                const SizedBox(height: HeyCabySpacing.sectionMedium),
                impactAsync.when(
                  data: (impact) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RiderYourImpactCard(
                        impact: impact,
                        loading: false,
                        colors: colors,
                        typo: typo,
                        l10n: l10n,
                      ),
                      const SizedBox(height: HeyCabySpacing.component),
                      RiderCommunityBadgesRow(
                        joined: impact.joined,
                        colors: colors,
                        typo: typo,
                        l10n: l10n,
                      ),
                    ],
                  ),
                  loading: () => RiderYourImpactCard(
                    impact: RiderInviteImpact.empty,
                    loading: true,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                  ),
                  error: (_, __) => RiderYourImpactCard(
                    impact: RiderInviteImpact.empty,
                    loading: false,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                  ),
                ),
                const SizedBox(height: HeyCabySpacing.sectionMedium),
                Text(
                  l10n.tellAFriendSharePrompt,
                  textAlign: TextAlign.center,
                  style: typo.bodyMedium.copyWith(
                    color: colors.textMid,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: HeyCabySpacing.sectionMedium),
                Builder(
                  builder: (ctx) {
                    return FilledButton.icon(
                      onPressed: shareReady
                          ? () async {
                              final box = ctx.findRenderObject() as RenderBox?;
                              final origin = box == null
                                  ? null
                                  : box.localToGlobal(Offset.zero) & box.size;
                              await HapticService.mediumTap();
                              final text =
                                  '${l10n.tellAFriendShareMessage}\n\n$shareUrl';
                              final result = await Share.shareWithResult(
                                text,
                                subject: l10n.tellAFriendShareSubject,
                                sharePositionOrigin: origin,
                              );
                              if (!ctx.mounted) return;
                              if (result.status == ShareResultStatus.success) {
                                await HapticService.success();
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(l10n.tellAFriendShareDoneSnackbar),
                                  ),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(l10n.tellAFriendShareLink),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: shareReady
                        ? () async {
                            await HapticService.selectionClick();
                            await Clipboard.setData(
                              ClipboardData(text: shareUrl),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.tellAFriendLinkCopied),
                              ),
                            );
                          }
                        : null,
                    icon: Icon(Icons.link_rounded, color: colors.accent),
                    label: Text(l10n.tellAFriendCopyLink),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: HeyCabySpacing.sectionMedium),
                Text(
                  sharingAppStore
                      ? l10n.tellAFriendInviteLinkLabel
                      : l10n.tellAFriendWebsiteLinkLabel,
                  style: typo.labelLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.85),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(14),
                    child: SelectableText(
                      shareUrl,
                      style: typo.bodySmall.copyWith(
                        color: colors.text,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                if (!shareReady) ...[
                  const SizedBox(height: HeyCabySpacing.component),
                  Text(
                    l10n.tellAFriendLinkUnavailable,
                    style: typo.bodyMedium.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.tellAFriendLinkUnavailableHint,
                    style: typo.bodySmall.copyWith(color: colors.textSoft),
                  ),
                ],
                const SizedBox(height: HeyCabySpacing.section),
                RiderGrowCityWhyHelpCard(
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
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
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.accent),
        ),
        error: (_, __) => Center(
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
    );
  }
}
