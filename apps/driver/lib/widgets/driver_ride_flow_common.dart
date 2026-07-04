import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import '../ui/driver_button.dart';
import '../ui/driver_ride_action_chip.dart';
import '../ui/driver_ride_card.dart';
import '../ui/driver_status_badge.dart';
import 'driver_ride_premium_style.dart';

/// Shared scaffold for core ride-flow screens.
class DriverRideFlowScaffold extends StatelessWidget {
  const DriverRideFlowScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.content,
    this.bottomBar,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final Widget content;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: title,
        colors: colors,
        typography: typography,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: onBack,
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: DriverRidePremiumStyle.screenBackground(colors),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DriverSpacing.screenEdge,
                  DriverSpacing.lg,
                  DriverSpacing.screenEdge,
                  DriverSpacing.xl,
                ),
                child: content,
              ),
            ),
            if (bottomBar != null) bottomBar!,
          ],
        ),
      ),
    );
  }
}

/// Pinned bottom actions — primary CTA + optional secondary rows.
class DriverRideFlowBottomBar extends StatelessWidget {
  const DriverRideFlowBottomBar({
    super.key,
    required this.colors,
    required this.typography,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryLoading = false,
    this.secondaryVariant = DriverButtonVariant.outline,
    this.tertiaryLabel,
    this.onTertiary,
    this.tertiaryDestructive = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final IconData? primaryIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool secondaryLoading;
  final DriverButtonVariant secondaryVariant;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;
  final bool tertiaryDestructive;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DriverRadius.sheetTop,
        boxShadow: DriverShadows.floating(colors),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.lg,
          DriverSpacing.screenEdge,
          DriverSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DriverButton(
              label: primaryLabel,
              icon: primaryIcon,
              onPressed: onPrimary,
              loading: primaryLoading,
              size: DriverButtonSize.lg,
              colors: colors,
              typography: typography,
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: DriverSpacing.sm),
              DriverButton(
                label: secondaryLabel!,
                onPressed: onSecondary,
                loading: secondaryLoading,
                variant: secondaryVariant,
                colors: colors,
                typography: typography,
              ),
            ],
            if (tertiaryLabel != null) ...[
              const SizedBox(height: DriverSpacing.sm),
              DriverButton(
                label: tertiaryLabel!,
                onPressed: onTertiary,
                variant: tertiaryDestructive
                    ? DriverButtonVariant.destructive
                    : DriverButtonVariant.ghost,
                colors: colors,
                typography: typography,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Trip summary card used across ride-flow screens.
class DriverRideTripSummary extends StatelessWidget {
  const DriverRideTripSummary({
    super.key,
    required this.colors,
    required this.typography,
    required this.pickupLabel,
    required this.dropoffLabel,
    this.riderName,
    this.fareLabel,
    this.statusLabel,
    this.statusTone = DriverStatusTone.success,
    this.staggerIndex = 0,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupLabel;
  final String dropoffLabel;
  final String? riderName;
  final String? fareLabel;
  final String? statusLabel;
  final DriverStatusTone statusTone;
  final int staggerIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (riderName != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.md,
              vertical: DriverSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_rounded, size: 18, color: colors.primary),
                const SizedBox(width: DriverSpacing.xs),
                Flexible(
                  child: Text(
                    riderName!,
                    style: typography.titleSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ).driverFadeSlideIn(staggerIndex: staggerIndex),
          const SizedBox(height: DriverSpacing.md),
        ],
        DriverRideCard(
          colors: colors,
          typography: typography,
          pickupLabel: pickupLabel,
          dropoffLabel: dropoffLabel,
          fareLabel: fareLabel,
          statusLabel: statusLabel,
          statusTone: statusTone,
        ).driverFadeSlideIn(staggerIndex: staggerIndex + 1),
      ],
    );
  }
}

class DriverRideFlowAction {
  const DriverRideFlowAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
}

/// Grid of ride quick actions.
class DriverRideActionGrid extends StatelessWidget {
  const DriverRideActionGrid({
    super.key,
    required this.colors,
    required this.typography,
    required this.actions,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final List<DriverRideFlowAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = actions.length > 1 && constraints.maxWidth >= 320;
        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: DriverSpacing.sm),
                DriverRideActionChip(
                  label: actions[i].label,
                  icon: actions[i].icon,
                  colors: colors,
                  typography: typography,
                  onTap: actions[i].enabled ? actions[i].onTap : null,
                ),
              ],
            ],
          );
        }

        return Wrap(
          spacing: DriverSpacing.sm,
          runSpacing: DriverSpacing.sm,
          children: [
            for (final action in actions)
              SizedBox(
                width: (constraints.maxWidth - DriverSpacing.sm) / 2,
                child: DriverRideActionChip(
                  label: action.label,
                  icon: action.icon,
                  colors: colors,
                  typography: typography,
                  onTap: action.enabled ? action.onTap : null,
                ),
              ),
          ],
        );
      },
    ).driverFadeSlideIn(staggerIndex: 2);
  }
}
