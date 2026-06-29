import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_card.dart';
import '../ui/driver_empty_state.dart';
import 'driver_community_flow_common.dart';

/// Channel pill for legacy community feed (`me_screen`).
class DriverMeCommunityChannel {
  const DriverMeCommunityChannel({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

/// Post row for legacy community feed preview / body.
class DriverMeCommunityPostItem {
  const DriverMeCommunityPostItem({
    required this.initials,
    required this.timeLabel,
    required this.body,
    this.swapBadge,
    this.claimLabel,
    this.onClaim,
  });

  final String initials;
  final String timeLabel;
  final String body;
  final String? swapBadge;
  final String? claimLabel;
  final VoidCallback? onClaim;
}

/// **Account Hub / Community Feed** — channel selector + posts (presentation).
class DriverMeCommunityBody extends StatelessWidget {
  const DriverMeCommunityBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.activeChannel,
    required this.channels,
    required this.onChannelChanged,
    required this.onRefresh,
    required this.postsLoading,
    required this.postsError,
    required this.posts,
    required this.onNewPost,
    required this.floatingActionButton,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String activeChannel;
  final List<DriverMeCommunityChannel> channels;
  final ValueChanged<String> onChannelChanged;
  final Future<void> Function() onRefresh;
  final bool postsLoading;
  final String? postsError;
  final List<DriverMeCommunityPostItem> posts;
  final VoidCallback onNewPost;
  final bool floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: floatingActionButton
          ? DriverCommunityNewPostFab(
              colors: colors,
              typography: typography,
              onPressed: onNewPost,
            )
          : null,
      body: SafeArea(
        child: EasyRefresh(
          onRefresh: onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DriverSpacing.screenEdge,
                    DriverSpacing.lg,
                    DriverSpacing.screenEdge,
                    DriverSpacing.sm,
                  ),
                  child: Text(
                    DriverStrings.community,
                    style: typography.headlineMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ).driverFadeSlideIn(staggerIndex: 0),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: DriverSpacing.screenEdge,
                    ),
                    children: [
                      for (var i = 0; i < channels.length; i++) ...[
                        if (i > 0) const SizedBox(width: DriverSpacing.sm),
                        DriverMeCommunityChannelPill(
                          channel: channels[i],
                          isActive: activeChannel == channels[i].id,
                          colors: colors,
                          typography: typography,
                          onTap: () => onChannelChanged(channels[i].id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (postsLoading)
                const SliverFillRemaining(
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (postsError != null)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      postsError!,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                )
              else if (posts.isEmpty)
                SliverFillRemaining(
                  child: DriverEmptyState(
                    icon: Icons.forum_outlined,
                    title: DriverStrings.communityEmptyPosts,
                    colors: colors,
                    typography: typography,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(DriverSpacing.screenEdge),
                  sliver: SliverList.separated(
                    itemCount: posts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: DriverSpacing.sm),
                    itemBuilder: (_, index) => DriverMeCommunityPostCard(
                      item: posts[index],
                      colors: colors,
                      typography: typography,
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottomPad + 80),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverMeCommunityChannelPill extends StatelessWidget {
  const DriverMeCommunityChannelPill({
    super.key,
    required this.channel,
    required this.isActive,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final DriverMeCommunityChannel channel;
  final bool isActive;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: DriverSpacing.lg,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isActive ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive ? colors.primary : colors.border,
            width: 0.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              channel.icon,
              size: 16,
              color: isActive ? colors.onPrimary : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              channel.label,
              style: typography.bodySmall.copyWith(
                color: isActive ? colors.onPrimary : colors.text,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverMeCommunityPostCard extends StatelessWidget {
  const DriverMeCommunityPostCard({
    super.key,
    required this.item,
    required this.colors,
    required this.typography,
  });

  final DriverMeCommunityPostItem item;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                child: Text(
                  item.initials,
                  style: typography.labelSmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.swapBadge != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          item.swapBadge!,
                          style: typography.labelSmall.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Text(
                      item.timeLabel,
                      style: typography.labelSmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            item.body,
            style: typography.bodyMedium.copyWith(color: colors.text),
          ),
          if (item.claimLabel != null && item.onClaim != null) ...[
            const SizedBox(height: DriverSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: item.onClaim,
                child: Text(item.claimLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
