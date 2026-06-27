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
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/driver');
            }
          },
        ),
        title: Text(
          strings.screenTitle,
          style: typography.titleMedium.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
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
            const SizedBox(height: DriverSpacing.xl),
            impactAsync.when(
              data: (impact) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DriverYourImpactCard(
                    impact: impact,
                    loading: false,
                    colors: colors,
                    typography: typography,
                    strings: strings,
                  ),
                  const SizedBox(height: DriverSpacing.lg),
                  DriverCommunityBadgesRow(
                    joined: impact.joined,
                    colors: colors,
                    typography: typography,
                    strings: strings,
                  ),
                ],
              ),
              loading: () => DriverYourImpactCard(
                impact: DriverInviteImpact.empty,
                loading: true,
                colors: colors,
                typography: typography,
                strings: strings,
              ),
              error: (_, __) => DriverYourImpactCard(
                impact: DriverInviteImpact.empty,
                loading: false,
                colors: colors,
                typography: typography,
                strings: strings,
              ),
            ),
            const SizedBox(height: DriverSpacing.xl),
            Text(
              strings.sharePrompt,
              textAlign: TextAlign.center,
              style: typography.bodyMedium.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: DriverSpacing.xl),
            FilledButton.icon(
              onPressed: shareReady
                  ? () async {
                      await HapticService.mediumTap();
                      final box = context.findRenderObject() as RenderBox?;
                      final origin = box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size;
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
            Center(
              child: SizedBox(
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
            ),
            const SizedBox(height: DriverSpacing.xl),
            Text(
              strings.inviteLinkLabel,
              style: typography.labelLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border.withValues(alpha: 0.85)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(
                  shareUrl,
                  style: typography.bodySmall.copyWith(
                    color: colors.text,
                    height: 1.4,
                  ),
                ),
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
            const SizedBox(height: DriverSpacing.xxl),
            DriverGrowCityWhyHelpCard(
              colors: colors,
              typography: typography,
              strings: strings,
            ),
            const SizedBox(height: DriverSpacing.lg),
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
}
