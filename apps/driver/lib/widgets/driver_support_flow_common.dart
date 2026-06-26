import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_card.dart';
import '../ui/driver_status_badge.dart';
import 'driver_settings_flow_common.dart';

/// Re-export settings shell — support screens share the same app bar pattern.
typedef DriverSupportFlowScaffold = DriverSettingsFlowScaffold;

/// Accent row for AI Lee / priority support actions.
class DriverSupportFeaturedRow extends StatelessWidget {
  const DriverSupportFeaturedRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(DriverSpacing.lg),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primary.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colors.primary, size: 22),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: typography.titleSmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: DriverSpacing.sm),
                        DriverStatusBadge(
                          label: badgeLabel,
                          colors: colors,
                          typography: typography,
                          tone: DriverStatusTone.busy,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: typography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard support nav row inside a group card.
class DriverSupportNavRow extends StatelessWidget {
  const DriverSupportNavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DriverSpacing.lg,
                vertical: DriverSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(icon, color: colors.primary, size: 22),
                  const SizedBox(width: DriverSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style: typography.bodyLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 52,
            color: colors.border.withValues(alpha: 0.6),
          ),
      ],
    );
  }
}

/// Ticket preview row for Help Hub + Inbox.
class DriverSupportTicketRow extends StatelessWidget {
  const DriverSupportTicketRow({
    super.key,
    required this.category,
    required this.statusLabel,
    required this.statusTone,
    required this.colors,
    required this.typography,
    required this.onTap,
    this.preview,
    this.timeLabel,
  });

  final String category;
  final String statusLabel;
  final DriverStatusTone statusTone;
  final String? preview;
  final String? timeLabel;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DriverSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            category,
                            style: typography.bodyMedium.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: DriverSpacing.sm),
                        DriverStatusBadge(
                          label: statusLabel,
                          colors: colors,
                          typography: typography,
                          tone: statusTone,
                        ),
                      ],
                    ),
                    if (preview != null && preview!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview!,
                        style: typography.bodySmall.copyWith(
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (timeLabel != null) ...[
                const SizedBox(width: DriverSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeLabel!,
                      style: typography.labelSmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                  ],
                ),
              ] else
                Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    ).driverFadeSlideIn(staggerIndex: 0);
  }
}

/// Section card wrapper for support lists.
class DriverSupportSectionCard extends StatelessWidget {
  const DriverSupportSectionCard({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.child,
    this.trailingAction,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final Widget child;
  final Widget? trailingAction;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: typography.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailingAction != null)
                trailingAction!
              else if (trailingLabel != null && onTrailingTap != null)
                TextButton(
                  onPressed: onTrailingTap,
                  child: Text(trailingLabel!),
                ),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          child,
        ],
      ),
    );
  }
}
