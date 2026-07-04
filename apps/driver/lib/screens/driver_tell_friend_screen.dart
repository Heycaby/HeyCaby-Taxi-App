import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/driver_grow_city_strings.dart';
import '../models/driver_community_growth_models.dart';
import '../providers/driver_community_growth_provider.dart';
import '../providers/driver_invite_url_provider.dart';
import '../providers/driver_locale_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import '../widgets/driver_grow_city_milestone_celebration.dart';
import '../widgets/driver_grow_city_parts.dart';

/// **Grow Your City** — driver community growth hub (invite drivers, transparency stats).
class DriverTellFriendScreen extends ConsumerWidget {
  const DriverTellFriendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);
    final strings = driverGrowCityStringsFor(locale);
    final shareUrl = ref.watch(driverInviteShareUrlProvider);
    final shareReady = ref.watch(driverInviteShareReadyProvider);
    final cityStatsAsync = ref.watch(communityGrowthStatsProvider);
    final impactAsync = ref.watch(driverInviteImpactProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom + DriverSpacing.xl;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: strings.screenTitle,
        colors: colors,
        typography: typography,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/driver');
            }
          },
        ),
      ),
      body: cityStatsAsync.when(
        data: (stats) => DriverGrowCityMilestoneCelebration(
          stats: stats,
          colors: colors,
          typography: typography,
          strings: strings,
          child: _buildScrollBody(
            context,
            colors,
            typography,
            strings,
            shareUrl,
            shareReady,
            cityStatsAsync,
            impactAsync,
            bottomPad,
          ),
        ),
        loading: () => _buildScrollBody(
          context,
          colors,
          typography,
          strings,
          shareUrl,
          shareReady,
          cityStatsAsync,
          impactAsync,
          bottomPad,
        ),
        error: (_, __) => _buildScrollBody(
          context,
          colors,
          typography,
          strings,
          shareUrl,
          shareReady,
          cityStatsAsync,
          impactAsync,
          bottomPad,
        ),
      ),
    );
  }

  Widget _buildScrollBody(
    BuildContext context,
    DriverColors colors,
    DriverTypography typography,
    DriverGrowCityStrings strings,
    String shareUrl,
    bool shareReady,
    AsyncValue<CommunityGrowthStats> cityStatsAsync,
    AsyncValue<DriverInviteImpact> impactAsync,
    double bottomPad,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.lg,
        DriverSpacing.screenEdge,
        bottomPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cityStatsAsync.when(
            data: (stats) => DriverGrowCityHero(
              regionName: stats.regionName,
              colors: colors,
              typography: typography,
              strings: strings,
            ),
            loading: () => DriverGrowCityHero(
              regionName: 'Netherlands',
              colors: colors,
              typography: typography,
              strings: strings,
            ),
            error: (_, __) => DriverGrowCityHero(
              regionName: 'Netherlands',
              colors: colors,
              typography: typography,
              strings: strings,
            ),
          ),
          const SizedBox(height: DriverSpacing.xl),
          FilledButton.icon(
            onPressed: shareReady
                ? () async {
                    final box = context.findRenderObject() as RenderBox?;
                    final origin = box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size;
                    await HapticService.mediumTap();
                    final text = '${strings.shareMessage}\n\n$shareUrl';
                    final result = await Share.shareWithResult(
                      text,
                      subject: strings.shareSubject,
                      sharePositionOrigin: origin,
                    );
                    if (!context.mounted) return;
                    if (result.status == ShareResultStatus.success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(strings.shareDoneSnackbar)),
                      );
                    }
                  }
                : null,
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(strings.shareLink),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: shareReady
                  ? () async {
                      await Clipboard.setData(
                        ClipboardData(text: shareUrl),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(strings.linkCopied)),
                      );
                    }
                  : null,
              icon: Icon(Icons.link_rounded, color: colors.primary),
              label: Text(strings.copyLink),
            ),
          ),
          if (!shareReady) ...[
            const SizedBox(height: DriverSpacing.lg),
            Text(
              strings.linkUnavailable,
              style: typography.bodyMedium.copyWith(
                color: colors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.linkUnavailableHint,
              style: typography.bodySmall.copyWith(
                color: colors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: DriverSpacing.xl),
          cityStatsAsync.when(
            data: (stats) => DriverCommunityProgressCard(
              stats: stats,
              colors: colors,
              typography: typography,
              strings: strings,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => DriverCommunityProgressCard(
              stats: CommunityGrowthStats.empty,
              colors: colors,
              typography: typography,
              strings: strings,
            ),
          ),
          const SizedBox(height: DriverSpacing.lg),
          impactAsync.when(
            data: (impact) {
              final hasImpact = impact.driversInvited > 0 ||
                  impact.joined > 0 ||
                  impact.completedRides > 0;
              if (!hasImpact) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DriverYourImpactCard(
                    impact: impact,
                    loading: false,
                    colors: colors,
                    typography: typography,
                    strings: strings,
                  ),
                  if (impact.joined > 0) ...[
                    const SizedBox(height: DriverSpacing.lg),
                    DriverCommunityBadgesRow(
                      joined: impact.joined,
                      colors: colors,
                      typography: typography,
                      strings: strings,
                    ),
                  ],
                  const SizedBox(height: DriverSpacing.lg),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          TextButton.icon(
            onPressed: () => _showWhyHelpSheet(
              context,
              colors,
              typography,
              strings,
            ),
            icon: Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: colors.primary,
            ),
            label: Text(strings.whyHelpTitle),
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            strings.socialProof,
            textAlign: TextAlign.center,
            style: typography.labelSmall.copyWith(
              color: colors.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  void _showWhyHelpSheet(
    BuildContext context,
    DriverColors colors,
    DriverTypography typography,
    DriverGrowCityStrings strings,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: DriverGrowCityWhyHelpCard(
            colors: colors,
            typography: typography,
            strings: strings,
          ),
        ),
      ),
    );
  }
}
