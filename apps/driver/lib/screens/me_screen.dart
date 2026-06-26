import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_me_community_body.dart';

class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  String _activeChannel = 'general';

  static final _channels = [
    const DriverMeCommunityChannel(
      id: 'announcements',
      label: DriverStrings.announcements,
      icon: Icons.campaign_outlined,
    ),
    DriverMeCommunityChannel(
      id: 'general',
      label: DriverStrings.driverTalk,
      icon: AppIcons.messages,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final postsAsync = ref.watch(communityPostsProvider(_activeChannel));

    final posts = postsAsync.maybeWhen(
      data: (items) => items
          .map(
            (post) => DriverMeCommunityPostItem(
              initials: (post.authorDriverId ?? '??').length >= 2
                  ? post.authorDriverId!.substring(0, 2).toUpperCase()
                  : '??',
              timeLabel: post.createdAt != null
                  ? DateFormat('d MMM, HH:mm').format(post.createdAt!)
                  : '',
              body: post.body ?? '',
              swapBadge: _activeChannel == 'swap' ? DriverStrings.rideSwap : null,
              claimLabel: post.isSwapOpen ? DriverStrings.claimRide : null,
              onClaim: post.isSwapOpen ? () => _claimSwap(post) : null,
            ),
          )
          .toList(),
      orElse: () => const <DriverMeCommunityPostItem>[],
    );

    return DriverMeCommunityBody(
      colors: colors,
      typography: typography,
      activeChannel: _activeChannel,
      channels: _channels,
      onChannelChanged: (channel) => setState(() => _activeChannel = channel),
      onRefresh: () async {
        ref.invalidate(communityPostsProvider(_activeChannel));
        await ref.read(communityPostsProvider(_activeChannel).future);
      },
      postsLoading: postsAsync.isLoading,
      postsError: postsAsync.hasError ? 'Kon berichten niet laden' : null,
      posts: posts,
      onNewPost: () => _showCreatePostModal(context, ref, colors, typography),
      floatingActionButton: _activeChannel == 'general',
    );
  }

  Future<void> _claimSwap(CommunityPost post) async {
    HapticService.mediumTap();
    final id = await ref.read(driverIdProvider.future);
    if (id == null) return;
    final ok =
        await ref.read(driverDataServiceProvider).claimSwapRide(id, post.id);
    if (ok) ref.invalidate(communityPostsProvider(post.channel ?? 'swap'));
  }
}

void _showCreatePostModal(
  BuildContext context,
  WidgetRef ref,
  DriverColors colors,
  DriverTypography typography,
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
                style: typography.titleMedium.copyWith(color: colors.text),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'Deel een tip, update of vraag...',
                  hintStyle: typography.bodyMedium.copyWith(color: colors.textMuted),
                  filled: true,
                  fillColor: colors.surface,
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
                    borderSide: BorderSide(color: colors.primary),
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
                    HapticService.mediumTap();
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
                          const SnackBar(
                            content: Text(DriverStrings.communityPostCreateFailed),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    'Plaatsen',
                    style: typography.labelLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
