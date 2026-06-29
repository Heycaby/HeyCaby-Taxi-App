import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

/// Fleet owner / private taxi owner alert for denied or blocked handover attempts.
Future<void> showDriverShiftHandoverSecurityAlert({
  required BuildContext context,
  required WidgetRef ref,
  required String category,
  required String title,
  required String body,
}) async {
  if (!context.mounted) return;
  await HapticService.heavyTap();
  if (!context.mounted) return;

  final colors = DriverColors.fromTheme(ref.read(colorsProvider));
  final typography = DriverTypography.fromTheme(ref.read(typographyProvider));
  final isPrivate = category.contains('private');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(DriverSpacing.screenEdge),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DriverSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title.isNotEmpty
                      ? title
                      : (isPrivate
                          ? DriverStrings.shiftHandoverPrivateAlertTitle
                          : DriverStrings.shiftHandoverFleetAlertTitle),
                  style: typography.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: DriverSpacing.sm),
                Text(
                  body.isNotEmpty
                      ? body
                      : DriverStrings.shiftHandoverFleetAlertBody,
                  style: typography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: DriverSpacing.lg),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(DriverStrings.close),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
