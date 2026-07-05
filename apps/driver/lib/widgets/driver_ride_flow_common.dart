import 'package:flutter/material.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
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
  final VoidCallback? onBack;
  final Widget content;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _DriverRideMapBackdrop(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.background.withValues(alpha: 0.04),
                  colors.background.withValues(alpha: 0.18),
                  colors.background.withValues(alpha: 0.88),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final topGap = (constraints.maxHeight * 0.24)
                          .clamp(96.0, 220.0)
                          .toDouble();
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          DriverSpacing.screenEdge,
                          topGap,
                          DriverSpacing.screenEdge,
                          bottomBar == null
                              ? DriverSpacing.xl +
                                  MediaQuery.paddingOf(context).bottom
                              : DriverSpacing.md,
                        ),
                        child: DecoratedBox(
                          decoration:
                              DriverRidePremiumStyle.modalSurface(colors),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              DriverSpacing.md,
                              DriverSpacing.md,
                              DriverSpacing.md,
                              DriverSpacing.lg,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DriverRidePremiumStyle.sheetHandle(colors),
                                const SizedBox(height: DriverSpacing.md),
                                DriverRidePremiumStyle.modalTopBar(
                                  colors: colors,
                                  title: title,
                                  titleStyle: typography.titleLarge.copyWith(
                                    color: colors.text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  onBack: onBack,
                                ),
                                const SizedBox(height: DriverSpacing.xl),
                                content,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (bottomBar != null) bottomBar!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverRideMapBackdrop extends StatelessWidget {
  const _DriverRideMapBackdrop();

  @override
  Widget build(BuildContext context) {
    final themeId = HeyCabyAppChrome.themeIdOf(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          MapWidget(
            key: ValueKey('driver-ride-map-$themeId'),
            styleUri: mapboxStyleUriForTheme(themeId),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(4.9041, 52.3676)),
              zoom: 14.2,
              pitch: 18,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.02),
                  Colors.black.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.70),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
        ],
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
          DriverSpacing.md,
          DriverSpacing.screenEdge,
          DriverSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DriverRidePremiumStyle.sheetHandle(colors),
            const SizedBox(height: DriverSpacing.md),
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

/// Premium state header for the current ride phase.
class DriverRidePhaseHero extends StatelessWidget {
  const DriverRidePhaseHero({
    super.key,
    required this.colors,
    required this.typography,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    this.tone = DriverStatusTone.success,
    this.metric,
    this.staggerIndex = 0,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final DriverStatusTone tone;
  final String? metric;
  final int staggerIndex;

  Color get _toneColor {
    return switch (tone) {
      DriverStatusTone.online || DriverStatusTone.success => colors.primary,
      DriverStatusTone.busy || DriverStatusTone.warning => colors.warning,
      DriverStatusTone.error => colors.error,
      DriverStatusTone.offline ||
      DriverStatusTone.neutral =>
        colors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final toneColor = _toneColor;

    return Container(
      padding: const EdgeInsets.all(DriverSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            toneColor.withValues(alpha: 0.16),
            colors.card,
            colors.surface.withValues(alpha: 0.82),
          ],
        ),
        border: Border.all(color: toneColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.92),
              borderRadius: DriverRadius.mdAll,
              boxShadow: [
                BoxShadow(
                  color: toneColor.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(icon, color: toneColor, size: 29),
          ),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: typography.labelMedium.copyWith(
                    color: toneColor,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: typography.titleLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (metric != null) ...[
            const SizedBox(width: DriverSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DriverSpacing.md,
                vertical: DriverSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                metric!,
                style: typography.labelMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    ).driverFadeSlideIn(staggerIndex: staggerIndex);
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
