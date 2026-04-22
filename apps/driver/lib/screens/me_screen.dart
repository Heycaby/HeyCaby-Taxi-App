import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  String _activeChannel = 'general';

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: _activeChannel == 'general'
          ? FloatingActionButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showCreatePostModal(context, ref, colors, typo);
              },
              backgroundColor: colors.accent,
              child: Icon(AppIcons.editPost, color: colors.card),
            )
          : null,
      body: SafeArea(
        child: EasyRefresh(
          onRefresh: () async {
            ref.invalidate(communityPostsProvider(_activeChannel));
            await ref.read(communityPostsProvider(_activeChannel).future);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    DriverStrings.community,
                    style: typo.headingLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _ChannelSelector(
                  activeChannel: _activeChannel,
                  colors: colors,
                  typo: typo,
                  onChanged: (c) => setState(() => _activeChannel = c),
                ),
              ),
              _PostsList(
                channel: _activeChannel,
                colors: colors,
                typo: typo,
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 80,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelSelector extends StatelessWidget {
  final String activeChannel;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final void Function(String) onChanged;

  const _ChannelSelector({
    required this.activeChannel,
    required this.colors,
    required this.typo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _ChannelPill(
            icon: Icons.campaign_outlined,
            label: DriverStrings.announcements,
            isActive: activeChannel == 'announcements',
            colors: colors,
            typo: typo,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged('announcements');
            },
          ),
          const SizedBox(width: 8),
          _ChannelPill(
            icon: AppIcons.messages,
            label: DriverStrings.driverTalk,
            isActive: activeChannel == 'general',
            colors: colors,
            typo: typo,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged('general');
            },
          ),
        ],
      ),
    );
  }
}

class _ChannelPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ChannelPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? colors.accent : colors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive ? colors.accent : colors.border,
            width: 0.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? colors.card : colors.textSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: typo.bodySmall.copyWith(
                color: isActive ? colors.card : colors.text,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostsList extends ConsumerWidget {
  final String channel;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _PostsList({
    required this.channel,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(communityPostsProvider(channel));

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.messages, size: 48, color: colors.textSoft),
                  const SizedBox(height: 12),
                  Text(
                    'Nog geen berichten',
                    style: typo.bodyMedium.copyWith(color: colors.textSoft),
                  ),
                ],
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.separated(
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _PostCard(
              post: posts[i],
              channel: channel,
              colors: colors,
              typo: typo,
              onClaim: posts[i].isSwapOpen
                  ? () => _claimSwap(ref, posts[i])
                  : null,
            ),
          ),
        );
      },
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => SliverFillRemaining(
        child: Center(
          child: Text(
            'Kon berichten niet laden',
            style: typo.bodyMedium.copyWith(color: colors.textSoft),
          ),
        ),
      ),
    );
  }

  Future<void> _claimSwap(WidgetRef ref, CommunityPost post) async {
    HapticFeedback.mediumImpact();
    final id = await ref.read(driverIdProvider.future);
    if (id == null) return;
    final ok =
        await ref.read(driverDataServiceProvider).claimSwapRide(id, post.id);
    if (ok) ref.invalidate(communityPostsProvider(post.channel ?? 'swap'));
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  final String channel;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback? onClaim;

  const _PostCard({
    required this.post,
    required this.channel,
    required this.colors,
    required this.typo,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final initials = (post.authorDriverId ?? '??').length >= 2
        ? post.authorDriverId!.substring(0, 2).toUpperCase()
        : '??';
    final timeStr = post.createdAt != null
        ? DateFormat('d MMM, HH:mm').format(post.createdAt!)
        : '';
    final isSwap = channel == 'swap';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.accentL,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: typo.labelSmall.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isSwap)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          DriverStrings.rideSwap,
                          style: typo.labelSmall.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    Text(
                      timeStr,
                      style: typo.labelSmall.copyWith(color: colors.textSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.body ?? '',
            style: typo.bodyMedium.copyWith(color: colors.text),
          ),
          if (onClaim != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onClaim!();
                },
                style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                child: Text(DriverStrings.claimRide),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _showCreatePostModal(
  BuildContext context,
  WidgetRef ref,
  HeyCabyColorTokens colors,
  HeyCabyTypography typo,
) {
  final controller = TextEditingController();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Consumer(
        builder: (_, ref, __) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nieuw bericht',
                style: typo.headingMedium.copyWith(color: colors.text),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'Deel een tip, update of vraag...',
                  hintStyle: typo.bodyMedium.copyWith(color: colors.textSoft),
                  filled: true,
                  fillColor: colors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
                maxLines: 4,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    HapticFeedback.mediumImpact();
                    final id = await ref.read(driverIdProvider.future);
                    if (id == null) return;
                    final ok = await ref
                        .read(driverDataServiceProvider)
                        .createCommunityPost(id, 'general', text);
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      ref.invalidate(communityPostsProvider('general'));
                      if (!ok) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Kon niet plaatsen')),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  child: Text(
                    'Plaatsen',
                    style: typo.labelLarge.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
