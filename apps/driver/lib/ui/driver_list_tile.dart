import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_icons.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

class DriverListTile extends StatelessWidget {
  const DriverListTile({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final DriverColors colors;
  final DriverTypography typography;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DriverRadius.smAll,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: dense ? DriverSpacing.touchTarget : DriverSpacing.touchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.lg,
              vertical: DriverSpacing.sm,
            ),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primaryLight,
                      borderRadius: DriverRadius.smAll,
                    ),
                    child: DriverIcon(leadingIcon!, color: colors.primary, size: 20),
                  ),
                  const SizedBox(width: DriverSpacing.lg),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: typography.titleMedium.copyWith(color: colors.text),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: typography.bodySmall.copyWith(color: colors.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
