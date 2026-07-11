import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:intl/intl.dart';

import '../l10n/driver_strings.dart';
import '../services/driver_data_service.dart';

class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
    required this.colors,
    required this.typo,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? colors.surface : colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? colors.accent : colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.accent.withValues(alpha: 0.12),
                child: Icon(icon, color: colors.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typo.labelLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: typo.bodySmall.copyWith(color: colors.textSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyBlock extends StatelessWidget {
  const EmptyBlock({
    super.key,
    required this.icon,
    required this.text,
    required this.colors,
    required this.typo,
  });
  final IconData icon;
  final String text;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: colors.textSoft),
            const SizedBox(height: 8),
            Text(text, style: typo.bodySmall.copyWith(color: colors.textSoft)),
          ],
        ),
      ),
    );
  }
}

class PinnedPollCard extends StatelessWidget {
  const PinnedPollCard({
    super.key,
    required this.post,
    required this.upPct,
    required this.downPct,
    required this.colors,
    required this.typo,
  });
  final CommunityPost post;
  final int upPct;
  final int downPct;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.card,
            colors.card.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'POLL',
                style: typo.labelSmall.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              (post.body ?? 'New feature vote').split('|').first.trim(),
              style: typo.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.body ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: typo.bodyMedium.copyWith(color: colors.textSoft),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.thumb_up_alt_rounded,
                          color: colors.success, size: 16),
                      const SizedBox(width: 6),
                      Text('$upPct%',
                          style: typo.labelMedium.copyWith(
                              color: colors.text, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.thumb_down_alt_rounded,
                          color: colors.error, size: 16),
                      const SizedBox(width: 6),
                      Text('$downPct%',
                          style: typo.labelMedium.copyWith(
                              color: colors.text, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: upPct / 100,
                minHeight: 10,
                backgroundColor: colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommunityTalkItem {
  final String postId;
  final String? authorDriverId;
  final String title;
  final String message;
  final String category;
  final String meta;
  final DateTime? createdAt;
  const CommunityTalkItem(
    this.postId,
    this.authorDriverId,
    this.title,
    this.message,
    this.category,
    this.meta,
    this.createdAt,
  );

  static CommunityTalkItem fromPost(CommunityPost post) {
    final when = post.createdAt == null
        ? DriverStrings.timeJustNow
        : DateFormat('HH:mm').format(post.createdAt!);

    if (post.poll != null) {
      return CommunityTalkItem(
        post.id,
        post.authorDriverId,
        DriverStrings.communityPollLabel,
        post.poll!.question,
        'poll',
        when,
        post.createdAt,
      );
    }

    final body = (post.body ?? '').trim();
    final match = RegExp(r'^\[(\w+)\]\s*').firstMatch(body);
    final category = (match?.group(1) ?? 'general').toLowerCase();
    final clean = body.replaceFirst(RegExp(r'^\[\w+\]\s*'), '');

    // Compact format: [cat] message only (no title/location pipes).
    if (!clean.contains('|')) {
      return CommunityTalkItem(
        post.id,
        post.authorDriverId,
        DriverStrings.communityPostTypeHeading(category),
        clean.isEmpty ? '…' : clean,
        category,
        when,
        post.createdAt,
      );
    }

    final parts = clean.split('|').map((e) => e.trim()).toList();
    final title = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : DriverStrings.communityPostLegacyUntitled;
    final msg = parts.length > 1 ? parts[1] : clean;
    final location =
        parts.length > 2 ? parts[2] : DriverStrings.communityPostLegacyNearby;
    return CommunityTalkItem(
      post.id,
      post.authorDriverId,
      title,
      msg,
      category,
      '$when · $location',
      post.createdAt,
    );
  }
}

class TalkRow extends StatelessWidget {
  const TalkRow({
    super.key,
    required this.item,
    required this.colors,
    required this.typo,
    required this.likeCount,
    required this.thanksCount,
    required this.likedByMe,
    required this.thankedByMe,
    required this.onLike,
    required this.onThanks,
    required this.onEdit,
    required this.onDelete,
    required this.canManage,
    this.messageMaxLines = 3,
    this.poll,
    this.onVotePoll,
    this.allowEdit = true,
  });

  final CommunityTalkItem item;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final int likeCount;
  final int thanksCount;
  final bool likedByMe;
  final bool thankedByMe;
  final VoidCallback onLike;
  final VoidCallback onThanks;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canManage;

  /// Hub preview uses 3 lines; full feed uses a higher value so content is readable.
  final int messageMaxLines;
  final CommunityPollData? poll;
  final Future<void> Function(String pollId, String optionId)? onVotePoll;
  final bool allowEdit;

  String _fmtWeight(double w) =>
      w == w.roundToDouble() ? '${w.toInt()}' : w.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final pollTiles = <Widget>[];
    if (poll != null && onVotePoll != null) {
      final p = poll!;
      final vote = onVotePoll!;
      final total = p.totalWeighted;
      for (final o in p.options) {
        final frac =
            total <= 0 ? 0.0 : (o.weightedTotal / total).clamp(0.0, 1.0);
        final selected = p.myOptionId == o.id;
        pollTiles.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await vote(p.pollId, o.id);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? colors.accent : colors.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            o.label,
                            style: typo.bodyMedium.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _fmtWeight(o.weightedTotal),
                          style: typo.labelMedium.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 6,
                        backgroundColor: colors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.accent.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    if (o.voterCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        DriverStrings.communityPollVoteCount(o.voterCount),
                        style: typo.labelSmall.copyWith(color: colors.textSoft),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: typo.titleSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: colors.textMid),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry<String>>[];
                      if (allowEdit) {
                        items.add(
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(DriverStrings.communityMenuEdit),
                          ),
                        );
                      }
                      items.add(
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(DriverStrings.communityMenuDelete),
                        ),
                      );
                      return items;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (poll != null && onVotePoll != null) ...[
              Text(
                DriverStrings.communityPollWeightedHint,
                style: typo.labelSmall.copyWith(
                  color: colors.textSoft,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              ...pollTiles,
            ] else
              Text(
                item.message,
                maxLines: messageMaxLines,
                overflow: TextOverflow.ellipsis,
                style: typo.bodyMedium.copyWith(
                  color: colors.textMid,
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.meta,
                    style: typo.labelSmall.copyWith(color: colors.textSoft),
                  ),
                ),
                const Spacer(),
                _ReactionButton(
                  icon: Icons.thumb_up_rounded,
                  count: likeCount,
                  active: likedByMe,
                  onTap: onLike,
                  colors: colors,
                  typo: typo,
                ),
                const SizedBox(width: 8),
                _ReactionButton(
                  icon: Icons.volunteer_activism_rounded,
                  count: thanksCount,
                  active: thankedByMe,
                  onTap: onThanks,
                  colors: colors,
                  typo: typo,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _ReactionButton({
    required this.icon,
    required this.count,
    required this.active,
    required this.onTap,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? colors.accent.withValues(alpha: 0.15)
              : colors.border.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? colors.accent : colors.textMid,
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: typo.labelSmall.copyWith(
                color: active ? colors.accent : colors.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
