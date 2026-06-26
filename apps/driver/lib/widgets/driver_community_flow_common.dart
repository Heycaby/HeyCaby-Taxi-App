import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';

/// Shared scaffold for community surfaces.
class DriverCommunityFlowScaffold extends StatelessWidget {
  const DriverCommunityFlowScaffold({
    super.key,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.body,
    this.title,
    this.floatingActionButton,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final Widget body;
  final String? title;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: title == null
          ? null
          : DriverAppBar(
              title: title!,
              colors: colors,
              typography: typography,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: colors.text),
                onPressed: onBack,
              ),
            ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

/// Hero header on the community hub — title, subtitle, actions.
class DriverCommunityHubHeader extends StatelessWidget {
  const DriverCommunityHubHeader({
    super.key,
    required this.colors,
    required this.typography,
    required this.hasUnreadNotifications,
    required this.onNotifications,
    required this.onSearch,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool hasUnreadNotifications;
  final VoidCallback onNotifications;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.xl,
        DriverSpacing.screenEdge,
        DriverSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.primary.withValues(alpha: 0.08),
            colors.background,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DriverStrings.community,
                  style: typography.titleLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              DriverCommunityIconAction(
                icon: Icons.notifications_outlined,
                colors: colors,
                showDot: hasUnreadNotifications,
                onTap: onNotifications,
              ),
              const SizedBox(width: DriverSpacing.sm),
              DriverCommunityIconAction(
                icon: Icons.search_rounded,
                colors: colors,
                onTap: onSearch,
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            'Connect, share, and grow together.',
            style: typography.bodyMedium.copyWith(
              color: colors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class DriverCommunityIconAction extends StatelessWidget {
  const DriverCommunityIconAction({
    super.key,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final DriverColors colors;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: colors.text, size: 22),
              if (showDot)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.card, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Announcements vs driver talk selector cards.
class DriverCommunityFeedSelector extends StatelessWidget {
  const DriverCommunityFeedSelector({
    super.key,
    required this.colors,
    required this.typography,
    required this.activeFeed,
    required this.onAnnouncementsTap,
    required this.onDriverTalkTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String activeFeed;
  final VoidCallback onAnnouncementsTap;
  final VoidCallback onDriverTalkTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.sm,
        DriverSpacing.screenEdge,
        DriverSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: DriverCommunityFeedEntryCard(
              icon: Icons.campaign_rounded,
              title: DriverStrings.announcements,
              subtitle: 'News, updates and polls',
              active: activeFeed == 'announcements',
              colors: colors,
              typography: typography,
              onTap: onAnnouncementsTap,
            ),
          ),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: DriverCommunityFeedEntryCard(
              icon: Icons.forum_rounded,
              title: DriverStrings.driverTalk,
              subtitle: 'Share, ask and help',
              active: activeFeed == 'general',
              colors: colors,
              typography: typography,
              onTap: onDriverTalkTap,
            ),
          ),
        ],
      ),
    );
  }
}

class DriverCommunityFeedEntryCard extends StatelessWidget {
  const DriverCommunityFeedEntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DriverRadius.md),
        child: Container(
          padding: const EdgeInsets.all(DriverSpacing.md),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: DriverRadius.mdAll,
            border: Border.all(
              color: active ? colors.primary : colors.border,
            ),
            boxShadow: DriverShadows.card(colors),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(DriverRadius.sm),
                ),
                child: Icon(icon, color: colors.primary, size: 18),
              ),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.labelLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: typography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
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
class DriverCommunityFeedSectionHeader extends StatelessWidget {
  const DriverCommunityFeedSectionHeader({
    super.key,
    required this.colors,
    required this.typography,
    required this.badgeLabel,
    required this.onViewAll,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String badgeLabel;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.sm,
        DriverSpacing.screenEdge,
        DriverSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.md,
              vertical: DriverSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(DriverRadius.pill),
            ),
            child: Text(
              badgeLabel,
              style: typography.labelSmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onViewAll,
            child: Text(
              DriverStrings.communityViewAll,
              style: typography.labelMedium.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Styled extended FAB for new community posts.
class DriverCommunityNewPostFab extends StatelessWidget {
  const DriverCommunityNewPostFab({
    super.key,
    required this.colors,
    required this.typography,
    required this.onPressed,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: DriverSpacing.xl,
        right: DriverSpacing.lg,
      ),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: colors.primary,
        elevation: 6,
        icon: Icon(Icons.add_rounded, color: colors.onPrimary),
        label: Text(
          DriverStrings.communityNewPost,
          style: typography.labelMedium.copyWith(
            color: colors.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
