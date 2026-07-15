import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../utils/driver_hub_goal_progress.dart';

/// Large icon-first Hub launcher tile (one word label, 56pt+ target).
class DriverHubSignTile extends StatelessWidget {
  const DriverHubSignTile({
    super.key,
    required this.colors,
    required this.typography,
    required this.label,
    required this.onTap,
    this.icon,
    this.assetIconPath,
    this.tint,
    this.badge,
    this.badgeIsWarning = false,
    this.subtitle,
    this.onInfoTap,
    this.goalPreview,
  }) : assert(icon != null || assetIconPath != null);

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final IconData? icon;
  final String? assetIconPath;
  final String label;
  final VoidCallback onTap;
  final Color? tint;
  final String? badge;
  final bool badgeIsWarning;
  final String? subtitle;
  final VoidCallback? onInfoTap;
  final DriverHubTileGoalPreview? goalPreview;

  @override
  Widget build(BuildContext context) {
    final driverTypo = DriverTypography.fromTheme(typography);
    final accent = tint ?? colors.accent;

    return Material(
      color: colors.card.withValues(alpha: 0.55),
      borderRadius: DriverRadius.lgAll,
      child: InkWell(
        onTap: () {
          HapticService.mediumTap();
          onTap();
        },
        borderRadius: DriverRadius.lgAll,
        child: Container(
          constraints:
              const BoxConstraints(minHeight: DriverSpacing.touchTargetLarge),
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.md,
            vertical: DriverSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: DriverRadius.lgAll,
            border: Border.all(
              color: colors.border.withValues(alpha: 0.72),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: assetIconPath != null
                          ? const EdgeInsets.all(6)
                          : EdgeInsets.zero,
                      child: assetIconPath != null
                          ? Image.asset(
                              assetIconPath!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) => Icon(
                                icon ?? Icons.image_not_supported_outlined,
                                color: accent,
                                size: 26,
                              ),
                            )
                          : Icon(icon, color: accent, size: 26),
                    ),
                  ),
                  const Spacer(),
                  if (goalPreview != null)
                    _HubTileGoalRing(
                      colors: colors,
                      typography: driverTypo,
                      preview: goalPreview!,
                    ),
                  if (onInfoTap != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        HapticService.selectionClick();
                        onInfoTap!();
                      },
                      icon: Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: colors.textSoft,
                      ),
                    ),
                  if (badge != null && badge!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (badgeIsWarning ? colors.warning : colors.textMid)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: driverTypo.labelSmall.copyWith(
                          color: badgeIsWarning
                              ? colors.warning
                              : colors.textMid,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DriverSpacing.sm),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: driverTypo.titleSmall.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: driverTypo.labelSmall.copyWith(
                    color: colors.textMid,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (goalPreview != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: goalPreview!.progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: colors.border.withValues(alpha: 0.45),
                    color: goalPreview!.achieved
                        ? colors.success
                        : colors.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HubTileGoalRing extends StatelessWidget {
  const _HubTileGoalRing({
    required this.colors,
    required this.typography,
    required this.preview,
  });

  final HeyCabyColorTokens colors;
  final DriverTypography typography;
  final DriverHubTileGoalPreview preview;

  @override
  Widget build(BuildContext context) {
    final ringColor = preview.achieved ? colors.success : colors.accent;

    return Semantics(
      label: preview.subtitle,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: preview.progress.clamp(0.0, 1.0),
              strokeWidth: 3.5,
              backgroundColor: colors.border.withValues(alpha: 0.35),
              color: ringColor,
            ),
            Text(
              preview.percentLabel,
              style: typography.labelSmall.copyWith(
                color: ringColor,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
