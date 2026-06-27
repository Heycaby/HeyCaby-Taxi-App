import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../widgets/driver_community_overlay_bodies.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_community_create_post_sheet.dart';
import '../widgets/driver_community_hub_body.dart';
import '../widgets/driver_community_hub_parts.dart';

class DriverCommunityHubScreen extends ConsumerStatefulWidget {
  const DriverCommunityHubScreen({super.key});

  @override
  ConsumerState<DriverCommunityHubScreen> createState() =>
      _DriverCommunityHubScreenState();
}

class _DriverCommunityHubScreenState
    extends ConsumerState<DriverCommunityHubScreen> {
  String _activeFeed = 'general';
  Map<String, CommunityReactionSummary> _reactions = const {};
  bool _showingDisclaimer = false;
  String _reactionRequestKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCommunityDisclaimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final themeColors = ref.watch(colorsProvider);
    final themeTypo = ref.watch(typographyProvider);
    final announcementsAsync =
        ref.watch(communityPostsProvider('announcements'));
    final talkAsync = ref.watch(communityPostsProvider('general'));
    final unreadNotificationCount =
        ref.watch(communityUnreadNotificationsCountProvider).valueOrNull ?? 0;

    return DriverCommunityHubBody(
      colors: colors,
      typography: typography,
      activeFeed: _activeFeed,
      hasUnreadNotifications: unreadNotificationCount > 0,
      onNotifications: () => _showNotifications(context),
      onSearch: () => _showSearchModal(context),
      onAnnouncementsTap: () => setState(() => _activeFeed = 'announcements'),
      onDriverTalkTap: () => setState(() => _activeFeed = 'general'),
      onViewAll: () => _navigateToAllPosts(context),
      onNewPost: () =>
          showCreatePostSheet(context, ref, themeColors, themeTypo),
      onRefresh: () async {
        ref.invalidate(communityPostsProvider('announcements'));
        ref.invalidate(communityPostsProvider('general'));
        ref.invalidate(communityChannelFeedProvider('announcements'));
        ref.invalidate(communityChannelFeedProvider('general'));
        ref.invalidate(communityNotificationsProvider);
        await Future.wait([
          ref.read(communityPostsProvider('announcements').future),
          ref.read(communityPostsProvider('general').future),
          ref.read(communityNotificationsProvider.future),
        ]);
      },
      feedSlivers: [
        if (_activeFeed == 'announcements')
          _buildAnnouncements(announcementsAsync, themeColors, themeTypo)
        else
          _buildTrending(talkAsync, themeColors, themeTypo),
      ],
    );
  }

  Widget _buildAnnouncements(
    AsyncValue<List<CommunityPost>> async,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo,
  ) {
    return async.when(
      data: (posts) {
        final pinned = posts.isEmpty ? null : posts.first;
        if (pinned == null) {
          return SliverToBoxAdapter(
            child: EmptyBlock(
              icon: Icons.campaign_outlined,
              text: 'No announcements yet.',
              colors: colors,
              typo: typo,
            ),
          );
        }
        final up = 65 + pinned.id.hashCode.abs() % 25;
        final down = 100 - up;
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: PinnedPollCard(
              post: pinned,
              upPct: up,
              downPct: down,
              colors: colors,
              typo: typo,
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: EmptyBlock(
          icon: Icons.error_outline_rounded,
          text: DriverStrings.announcementsLoadFailed,
          colors: colors,
          typo: typo,
        ),
      ),
    );
  }

  Widget _buildTrending(
    AsyncValue<List<CommunityPost>> async,
    HeyCabyColorTokens colors,
    HeyCabyTypography typo, {
    bool isCategoryBlock = false,
  }) {
    final myDriverId = ref.watch(driverIdProvider).valueOrNull;
    return async.when(
      data: (posts) {
        final parsed = posts
            .map((p) => (post: p, item: CommunityTalkItem.fromPost(p)))
            .toList();
        _refreshReactions(posts, myDriverId);
        if (parsed.isEmpty) {
          if (!isCategoryBlock)
            return const SliverToBoxAdapter(child: SizedBox());
          return SliverToBoxAdapter(
            child: EmptyBlock(
              icon: Icons.forum_outlined,
              text: 'No posts for this category.',
              colors: colors,
              typo: typo,
            ),
          );
        }
        final list = isCategoryBlock ? parsed : parsed.take(3).toList();
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          sliver: SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => TalkRow(
              item: list[i].item,
              colors: colors,
              typo: typo,
              likeCount: _reactions[list[i].post.id]?.likeCount ?? 0,
              thanksCount: _reactions[list[i].post.id]?.thanksCount ?? 0,
              likedByMe: _reactions[list[i].post.id]?.likedByMe ?? false,
              thankedByMe: _reactions[list[i].post.id]?.thankedByMe ?? false,
              onLike: () => _toggleReaction(list[i].post.id, 'like'),
              onThanks: () => _toggleReaction(list[i].post.id, 'thanks'),
              canManage: myDriverId != null &&
                  myDriverId == list[i].post.authorDriverId,
              onEdit: () => _editPost(list[i].post),
              onDelete: () => _deletePost(list[i].post),
              poll: list[i].post.poll,
              onVotePoll: list[i].post.poll == null
                  ? null
                  : (pollId, optionId) => _voteOnPoll(pollId, optionId),
              allowEdit: list[i].post.poll == null,
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Future<void> _refreshReactions(
      List<CommunityPost> posts, String? driverId) async {
    if (driverId == null || posts.isEmpty || !mounted) return;
    final ids = posts.map((e) => e.id).toList();
    final key = '${driverId}_${ids.join(',')}';
    if (_reactionRequestKey == key) return;
    _reactionRequestKey = key;
    final map = await ref
        .read(driverDataServiceProvider)
        .getCommunityReactionSummary(ids, driverId: driverId);
    if (!mounted) return;
    setState(() => _reactions = map);
  }

  Future<void> _toggleReaction(String postId, String type) async {
    final driverId = await ref.read(driverIdProvider.future);
    if (driverId == null) return;
    _applyLocalReaction(postId, type);
    final ok =
        await ref.read(driverDataServiceProvider).toggleCommunityReaction(
              postId: postId,
              driverId: driverId,
              reactionType: type,
            );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            DriverStrings.reactionFailedMigration,
          ),
        ),
      );
      // revert optimistic toggle
      _applyLocalReaction(postId, type);
    }
    _reactionRequestKey = '';
    ref.invalidate(communityPostsProvider('general'));
    ref.invalidate(communityChannelFeedProvider('general'));
  }

  Future<void> _voteOnPoll(String pollId, String optionId) async {
    final driverId = await ref.read(driverIdProvider.future);
    if (driverId == null || !mounted) return;
    final ok =
        await ref.read(driverDataServiceProvider).upsertCommunityPollVote(
              pollId: pollId,
              optionId: optionId,
              driverId: driverId,
            );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.communityPollVoteFailed)),
      );
      return;
    }
    ref.invalidate(communityPostsProvider('general'));
    ref.invalidate(communityChannelFeedProvider('general'));
  }

  void _applyLocalReaction(String postId, String type) {
    final current = _reactions[postId] ?? const CommunityReactionSummary();
    final isLike = type == 'like';
    final toggledOn = isLike ? !current.likedByMe : !current.thankedByMe;
    final next = CommunityReactionSummary(
      likeCount:
          isLike ? current.likeCount + (toggledOn ? 1 : -1) : current.likeCount,
      thanksCount: isLike
          ? current.thanksCount
          : current.thanksCount + (toggledOn ? 1 : -1),
      likedByMe: isLike ? toggledOn : current.likedByMe,
      thankedByMe: isLike ? current.thankedByMe : toggledOn,
    );
    setState(() {
      _reactions = <String, CommunityReactionSummary>{
        ..._reactions,
        postId: next,
      };
    });
  }

  Future<void> _editPost(CommunityPost post) async {
    if (post.poll != null) return;
    final controller = TextEditingController(text: post.body ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(DriverStrings.communityEditPostTitle),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: DriverStrings.communityEditPostHint,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(DriverStrings.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(DriverStrings.save)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(driverDataServiceProvider).updateCommunityPost(
          postId: post.id,
          content: controller.text,
        );
    _reactionRequestKey = '';
    final ch = post.channel ?? 'general';
    ref.invalidate(communityPostsProvider(ch));
    ref.invalidate(communityChannelFeedProvider(ch));
  }

  Future<void> _deletePost(CommunityPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(DriverStrings.communityDeletePostTitle),
        content: Text(DriverStrings.communityDeletePostBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(DriverStrings.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(DriverStrings.communityDeleteAction)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(driverDataServiceProvider).deleteCommunityPost(post.id);
    _reactionRequestKey = '';
    final ch = post.channel ?? 'general';
    ref.invalidate(communityPostsProvider(ch));
    ref.invalidate(communityChannelFeedProvider(ch));
  }

  void _navigateToAllPosts(BuildContext context) {
    final channel =
        _activeFeed == 'announcements' ? 'announcements' : 'general';
    context.push('/driver/community/feed?channel=$channel');
  }

  void _showNotifications(BuildContext context) {
    showDriverCommunityNotificationsSheet(
      context,
      ref,
      onNotificationTap: (notification) {
        final colors = DriverColors.fromTheme(ref.read(colorsProvider));
        final typography =
            DriverTypography.fromTheme(ref.read(typographyProvider));
        showDriverCommunityNotificationDetailDialog(
          context,
          notification: notification,
          colors: colors,
          typography: typography,
        );
      },
    );
  }

  void _showSearchModal(BuildContext context) {
    showDriverCommunitySearchSheet(context, ref);
  }

  Future<void> _ensureCommunityDisclaimer() async {
    if (_showingDisclaimer || !mounted) return;
    final accepted = await ref
        .read(driverDataServiceProvider)
        .isCommunityDisclaimerAccepted();
    if (accepted || !mounted) return;
    _showingDisclaimer = true;
    await showDriverCommunityDisclaimerDialog(context, ref);
    _showingDisclaimer = false;
  }
}
