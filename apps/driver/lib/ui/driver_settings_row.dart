import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_card.dart';

/// Uppercase section label for grouped settings.
class DriverSettingsSectionLabel extends StatelessWidget {
  const DriverSettingsSectionLabel({
    super.key,
    required this.label,
    required this.colors,
    required this.typography,
  });

  final String label;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DriverSpacing.sm,
        bottom: DriverSpacing.md,
      ),
      child: Text(
        label.toUpperCase(),
        style: typography.labelSmall.copyWith(
          color: colors.textMuted,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Grouped settings rows inside one card.
class DriverSettingsGroupCard extends StatelessWidget {
  const DriverSettingsGroupCard({
    super.key,
    required this.colors,
    required this.children,
  });

  final DriverColors colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Tappable settings row with icon pill + chevron.
class DriverSettingsNavRow extends StatelessWidget {
  const DriverSettingsNavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.colors,
    required this.typography,
    this.subtitle,
    this.onTap,
    this.showDivider = true,
    this.boldTitle = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool boldTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(DriverSpacing.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DriverSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: DriverRadius.smAll,
                    ),
                    child: Icon(icon, size: 20, color: colors.primary),
                  ),
                  const SizedBox(width: DriverSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: typography.bodyMedium.copyWith(
                            color: colors.text,
                            fontWeight:
                                boldTitle ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: DriverSpacing.xs),
                          Text(
                            subtitle!,
                            style: typography.bodySmall.copyWith(
                              color: colors.textMuted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
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
            indent: DriverSpacing.lg,
            endIndent: DriverSpacing.lg,
            color: colors.border.withValues(alpha: 0.6),
          ),
      ],
    );
  }
}

/// Toggle row for preferences.
class DriverSettingsToggleRow extends StatelessWidget {
  const DriverSettingsToggleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.colors,
    required this.typography,
    required this.onChanged,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final bool value;
  final DriverColors colors;
  final DriverTypography typography;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.lg,
            vertical: DriverSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DriverSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.5),
                  borderRadius: DriverRadius.smAll,
                ),
                child: Icon(icon, size: 20, color: colors.textSecondary),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: typography.bodyMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: colors.primary,
                activeTrackColor: colors.primary.withValues(alpha: 0.24),
                inactiveThumbColor: colors.card,
                inactiveTrackColor: colors.border,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: DriverSpacing.lg,
            endIndent: DriverSpacing.lg,
            color: colors.border.withValues(alpha: 0.6),
          ),
      ],
    );
  }
}
