import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

class DriverEmptyState extends StatelessWidget {
  const DriverEmptyState({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    this.message,
    this.icon,
    this.action,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final Widget? action;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DriverSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.border.withValues(alpha: 0.9)),
              boxShadow: [
                BoxShadow(
                  color: colors.text.withValues(alpha: 0.06),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                  spreadRadius: -16,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(icon, size: 34, color: colors.primary),
                    ),
                    const SizedBox(height: DriverSpacing.lg),
                  ],
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: typography.titleLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      height: 1.2,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: DriverSpacing.sm),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: DriverSpacing.xl),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
