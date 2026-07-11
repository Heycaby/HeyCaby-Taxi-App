import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_community_channel_body.dart';
import '../widgets/driver_community_create_post_sheet.dart';
import '../widgets/driver_community_hub_parts.dart';

/// Full scroll list for one community channel (no placeholder / “coming soon”).
class DriverCommunityChannelFeedScreen extends ConsumerStatefulWidget {
  const DriverCommunityChannelFeedScreen({
    super.key,
    required this.channel,
  });

  /// `general` (driver talk) or `announcements`.
  final String channel;

  @override
  ConsumerState<DriverCommunityChannelFeedScreen> createState() =>
      _DriverCommunityChannelFeedScreenState();
}

class _DriverCommunityChannelFeedScreenState
    extends ConsumerState<DriverCommunityChannelFeedScreen> {
  Map<String, CommunityReactionSummary> _reactions = const {};
  String _reactionRequestKey = '';

  String get _channel => widget.channel;

  String get _title => _channel == 'announcements'
      ? DriverStrings.announcements
      : DriverStrings.driverTalk;

  void _invalidateChannel() {
    ref.invalidate(communityChannelFeedProvider(_channel));
    ref.invalidate(communityPostsProvider(_channel));
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
        SnackBar(
          content: Text(
            DriverStrings.reactionFailedMigration,
          ),
        ),
      );
      _applyLocalReaction(postId, type);
    }
    _reactionRequestKey = '';
    _invalidateChannel();
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
          decoration: InputDecoration(
            hintText: DriverStrings.communityEditPostHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(DriverStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(DriverStrings.save),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(driverDataServiceProvider).updateCommunityPost(
          postId: post.id,
          content: controller.text,
        );
    _reactionRequestKey = '';
    _invalidateChannel();
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
            child: Text(DriverStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(DriverStrings.communityDeleteAction),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(driverDataServiceProvider).deleteCommunityPost(post.id);
    _reactionRequestKey = '';
    _invalidateChannel();
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
    _invalidateChannel();
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final themeColors = ref.watch(colorsProvider);
    final themeTypo = ref.watch(typographyProvider);
    final postsAsync = ref.watch(communityChannelFeedProvider(_channel));
    final myDriverId = ref.watch(driverIdProvider).valueOrNull;

    return DriverCommunityChannelBody(
      title: _title,
      colors: colors,
      typography: typography,
      onBack: () => Navigator.of(context).maybePop(),
      showNewPostFab: _channel == 'general',
      onNewPost: () =>
          showCreatePostSheet(context, ref, themeColors, themeTypo),
      onRefresh: () async {
        _invalidateChannel();
        await ref.read(communityChannelFeedProvider(_channel).future);
      },
      content: postsAsync.when(
        data: (posts) {
          _refreshReactions(posts, myDriverId);
          if (posts.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
                EmptyBlock(
                  icon: _channel == 'announcements'
                      ? Icons.campaign_outlined
                      : Icons.forum_outlined,
                  text: _channel == 'announcements'
                      ? DriverStrings.communityFeedEmptyAnnouncements
                      : DriverStrings.communityFeedEmptyTalk,
                  colors: themeColors,
                  typo: themeTypo,
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final post = posts[i];
              final item = CommunityTalkItem.fromPost(post);
              return TalkRow(
                item: item,
                colors: themeColors,
                typo: themeTypo,
                messageMaxLines: 80,
                likeCount: _reactions[post.id]?.likeCount ?? 0,
                thanksCount: _reactions[post.id]?.thanksCount ?? 0,
                likedByMe: _reactions[post.id]?.likedByMe ?? false,
                thankedByMe: _reactions[post.id]?.thankedByMe ?? false,
                onLike: () => _toggleReaction(post.id, 'like'),
                onThanks: () => _toggleReaction(post.id, 'thanks'),
                canManage:
                    myDriverId != null && myDriverId == post.authorDriverId,
                onEdit: () => _editPost(post),
                onDelete: () => _deletePost(post),
                poll: post.poll,
                onVotePoll: post.poll == null
                    ? null
                    : (pollId, optionId) => _voteOnPoll(pollId, optionId),
                allowEdit: post.poll == null,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            EmptyBlock(
              icon: Icons.error_outline_rounded,
              text: DriverStrings.communityFeedLoadFailed,
              colors: themeColors,
              typo: themeTypo,
            ),
          ],
        ),
      ),
    );
  }
}
