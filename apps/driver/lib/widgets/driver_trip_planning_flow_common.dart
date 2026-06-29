import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import '../ui/driver_button.dart';
import '../ui/driver_chip.dart';

/// Shared scaffold for trip planning surfaces.
class DriverTripPlanningFlowScaffold extends StatelessWidget {
  const DriverTripPlanningFlowScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.body,
    this.subtitle,
    this.leadingClose = false,
    this.centerTitle = true,
  });

  final String title;
  final String? subtitle;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final Widget body;
  final bool leadingClose;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: subtitle == null
          ? DriverAppBar(
              title: title,
              colors: colors,
              typography: typography,
              centerTitle: centerTitle,
              leading: IconButton(
                icon: Icon(
                  leadingClose ? Icons.close_rounded : Icons.arrow_back_rounded,
                  color: colors.text,
                ),
                onPressed: onBack,
              ),
            )
          : DriverAppBar(
              title: title,
              subtitle: subtitle,
              colors: colors,
              typography: typography,
              centerTitle: false,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: colors.text),
                onPressed: onBack,
              ),
            ),
      body: body,
    );
  }
}

/// Grouped form section used on manual ride entry.
class DriverTripPlanningSectionCard extends StatelessWidget {
  const DriverTripPlanningSectionCard({
    super.key,
    required this.colors,
    required this.child,
  });

  final DriverColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DriverSpacing.lg),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DriverRadius.mdAll,
        border: Border.all(color: colors.border),
        boxShadow: DriverShadows.card(colors),
      ),
      child: child,
    );
  }
}

/// Return-trip discount slider card.
class DriverReturnDiscountCard extends StatelessWidget {
  const DriverReturnDiscountCard({
    super.key,
    required this.colors,
    required this.typography,
    required this.valuePct,
    required this.computedFareText,
    required this.chanceLabel,
    required this.chanceColor,
    required this.onChanged,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final double valuePct;
  final String computedFareText;
  final String chanceLabel;
  final Color chanceColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return DriverTripPlanningSectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.yourReturnDiscount,
            style: typography.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 0,
                  max: 40,
                  divisions: 8,
                  value: valuePct.clamp(0, 40),
                  activeColor: colors.primary,
                  inactiveColor: colors.border,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: DriverSpacing.md),
              Text(
                '${valuePct.toStringAsFixed(0)}%',
                style: typography.titleMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DriverStrings.returnDiscountSharedCosts}: $computedFareText',
                  style: typography.bodySmall.copyWith(color: colors.textMuted),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DriverSpacing.md,
                  vertical: DriverSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: chanceColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(DriverRadius.pill),
                  border: Border.all(
                    color: chanceColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  '${DriverStrings.matchChance}: $chanceLabel',
                  style: typography.bodySmall.copyWith(
                    color: chanceColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Display model for a return-trip offer row.
class DriverReturnTripOfferItem {
  const DriverReturnTripOfferItem({
    required this.fromLabel,
    required this.toLabel,
    this.offeredFareLabel,
    this.discountedFareLabel,
    this.distanceLabel,
    this.durationLabel,
    this.canAccept = true,
  });

  final String fromLabel;
  final String toLabel;
  final String? offeredFareLabel;
  final String? discountedFareLabel;
  final String? distanceLabel;
  final String? durationLabel;
  final bool canAccept;
}

class DriverReturnTripOfferCard extends StatelessWidget {
  const DriverReturnTripOfferCard({
    super.key,
    required this.item,
    required this.colors,
    required this.typography,
    required this.onAccept,
  });

  final DriverReturnTripOfferItem item;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return DriverTripPlanningSectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(width: 2, height: 28, color: colors.border),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fromLabel,
                      style: typography.bodyMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.xs),
                    Text(
                      item.toLabel,
                      style: typography.bodyMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.offeredFareLabel != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.offeredFareLabel!,
                      style: typography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                    if (item.discountedFareLabel != null)
                      Text(
                        item.discountedFareLabel!,
                        style: typography.titleMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (item.distanceLabel != null || item.durationLabel != null) ...[
            const SizedBox(height: DriverSpacing.md),
            Row(
              children: [
                if (item.distanceLabel != null)
                  Text(
                    item.distanceLabel!,
                    style: typography.bodySmall.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                if (item.distanceLabel != null && item.durationLabel != null)
                  const SizedBox(width: DriverSpacing.md),
                if (item.durationLabel != null)
                  Text(
                    item.durationLabel!,
                    style: typography.bodySmall.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: DriverSpacing.md),
          DriverButton(
            label: DriverStrings.accept,
            colors: colors,
            typography: typography,
            onPressed: item.canAccept ? onAccept : null,
            size: DriverButtonSize.lg,
          ),
        ],
      ),
    );
  }
}

/// Requests / confirmed tab switcher for scheduled rides.
class DriverScheduledTabBar extends StatelessWidget {
  const DriverScheduledTabBar({
    super.key,
    required this.colors,
    required this.typography,
    required this.requestsSelected,
    required this.onRequestsTap,
    required this.onConfirmedTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool requestsSelected;
  final VoidCallback onRequestsTap;
  final VoidCallback onConfirmedTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.screenEdge,
        vertical: DriverSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: DriverChip(
              label: DriverStrings.requests,
              colors: colors,
              typography: typography,
              selected: requestsSelected,
              onTap: onRequestsTap,
            ),
          ),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: DriverChip(
              label: DriverStrings.confirmed,
              colors: colors,
              typography: typography,
              selected: !requestsSelected,
              onTap: onConfirmedTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Display model for scheduled ride list cards.
class DriverScheduledRideListItem {
  const DriverScheduledRideListItem({
    required this.headline,
    this.distanceLabel,
    this.pickupAddress,
    this.destinationAddress,
    this.mapPreview,
    this.footer,
  });

  final String headline;
  final String? distanceLabel;
  final String? pickupAddress;
  final String? destinationAddress;
  final Widget? mapPreview;
  final Widget? footer;
}

class DriverScheduledRideCard extends StatelessWidget {
  const DriverScheduledRideCard({
    super.key,
    required this.item,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final DriverScheduledRideListItem item;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DriverTripPlanningSectionCard(
        colors: colors,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.headline,
              style: typography.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.distanceLabel != null) ...[
              const SizedBox(height: DriverSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.directions_car_rounded,
                    size: 16,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: DriverSpacing.xs),
                  Text(
                    item.distanceLabel!,
                    style: typography.bodySmall.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
            if (item.mapPreview != null) ...[
              const SizedBox(height: DriverSpacing.md),
              ClipRRect(
                borderRadius: DriverRadius.smAll,
                child: item.mapPreview!,
              ),
            ],
            if (item.pickupAddress != null) ...[
              const SizedBox(height: DriverSpacing.md),
              _AddressDotRow(
                colors: colors,
                typography: typography,
                dotColor: colors.primary,
                label: item.pickupAddress!,
              ),
            ],
            if (item.destinationAddress != null) ...[
              const SizedBox(height: DriverSpacing.xs),
              _AddressDotRow(
                colors: colors,
                typography: typography,
                dotColor: colors.text,
                label: item.destinationAddress!,
              ),
            ],
            if (item.footer != null) ...[
              const SizedBox(height: DriverSpacing.md),
              item.footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class _AddressDotRow extends StatelessWidget {
  const _AddressDotRow({
    required this.colors,
    required this.typography,
    required this.dotColor,
    required this.label,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final Color dotColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: DriverSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: typography.bodySmall.copyWith(color: colors.text),
          ),
        ),
      ],
    );
  }
}

/// Drop-off suggestion row for manual ride geocoding.
class DriverManualRideSuggestionTile extends StatelessWidget {
  const DriverManualRideSuggestionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: typography.bodyMedium.copyWith(color: colors.text),
      ),
      subtitle: subtitle == null || subtitle!.isEmpty
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
      onTap: onTap,
    );
  }
}
