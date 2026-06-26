import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import 'driver_community_flow_common.dart';

/// **Community Hub** — feed selector + preview slivers.
class DriverCommunityHubBody extends StatelessWidget {
  const DriverCommunityHubBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.activeFeed,
    required this.hasUnreadNotifications,
    required this.onNotifications,
    required this.onSearch,
    required this.onAnnouncementsTap,
    required this.onDriverTalkTap,
    required this.onViewAll,
    required this.onRefresh,
    required this.feedSlivers,
    required this.onNewPost,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String activeFeed;
  final bool hasUnreadNotifications;
  final VoidCallback onNotifications;
  final VoidCallback onSearch;
  final VoidCallback onAnnouncementsTap;
  final VoidCallback onDriverTalkTap;
  final VoidCallback onViewAll;
  final Future<void> Function() onRefresh;
  final List<Widget> feedSlivers;
  final VoidCallback onNewPost;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final badgeLabel =
        activeFeed == 'announcements' ? '📌 Pinned' : '🔥 Trending';

    return DriverCommunityFlowScaffold(
      colors: colors,
      typography: typography,
      onBack: () {},
      floatingActionButton: DriverCommunityNewPostFab(
        colors: colors,
        typography: typography,
        onPressed: onNewPost,
      ),
      body: SafeArea(
        child: EasyRefresh(
          onRefresh: onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: DriverCommunityHubHeader(
                  colors: colors,
                  typography: typography,
                  hasUnreadNotifications: hasUnreadNotifications,
                  onNotifications: onNotifications,
                  onSearch: onSearch,
                ),
              ),
              SliverToBoxAdapter(
                child: DriverCommunityFeedSelector(
                  colors: colors,
                  typography: typography,
                  activeFeed: activeFeed,
                  onAnnouncementsTap: onAnnouncementsTap,
                  onDriverTalkTap: onDriverTalkTap,
                ),
              ),
              SliverToBoxAdapter(
                child: DriverCommunityFeedSectionHeader(
                  colors: colors,
                  typography: typography,
                  badgeLabel: badgeLabel,
                  onViewAll: onViewAll,
                ),
              ),
              ...feedSlivers,
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottomPad + 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
