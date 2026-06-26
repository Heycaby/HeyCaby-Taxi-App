import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_card.dart';
import '../ui/driver_settings_row.dart';
import '../ui/driver_status_badge.dart';

/// Display model for [DriverIdentityBody] — built by screen, logic stays in screen.
class DriverIdentityViewModel {
  const DriverIdentityViewModel({
    required this.headline,
    required this.initials,
    required this.rating,
    required this.vehiclePlate,
    required this.vehicleDisplay,
    this.email,
    this.emphasizePlaceholder = false,
    this.foundingNumber,
    this.showFoundingShield = false,
    this.isVerifiedBadge = false,
    this.showVehicleVerified = false,
    this.apkExpiryLabel,
  });

  final String headline;
  final String initials;
  final String? email;
  final bool emphasizePlaceholder;
  final double rating;
  final int? foundingNumber;
  final bool showFoundingShield;
  final bool isVerifiedBadge;
  final String vehiclePlate;
  final String vehicleDisplay;
  final bool showVehicleVerified;
  final String? apkExpiryLabel;
}

/// **Driver Identity** — Account Hub at `/driver/me`.
class DriverIdentityBody extends StatelessWidget {
  const DriverIdentityBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.model,
    required this.onEditProfile,
    required this.onOpenVehicle,
    required this.onOpenPreferences,
    required this.onOpenFinance,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverIdentityViewModel model;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenVehicle;
  final VoidCallback onOpenPreferences;
  final VoidCallback onOpenFinance;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DriverSpacing.screenEdge,
              DriverSpacing.md,
              DriverSpacing.screenEdge,
              DriverSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DriverStrings.profile,
                  style: typography.headlineSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ).driverFadeSlideIn(staggerIndex: 0),
                const SizedBox(height: DriverSpacing.lg),
                _ProfileHeroCard(
                  colors: colors,
                  typography: typography,
                  model: model,
                  onTap: onEditProfile,
                ).driverFadeSlideIn(staggerIndex: 1),
                const SizedBox(height: DriverSpacing.lg),
                _VehicleSummaryCard(
                  colors: colors,
                  typography: typography,
                  model: model,
                  onTap: onOpenVehicle,
                ).driverFadeSlideIn(staggerIndex: 2),
                const SizedBox(height: DriverSpacing.xl),
                Text(
                  DriverStrings.preferences,
                  style: typography.labelMedium.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DriverSpacing.sm),
                DriverSettingsGroupCard(
                  colors: colors,
                  children: [
                    DriverSettingsNavRow(
                      icon: Icons.tune_rounded,
                      title: DriverStrings.preferences,
                      colors: colors,
                      typography: typography,
                      onTap: onOpenPreferences,
                    ),
                    DriverSettingsNavRow(
                      icon: Icons.bar_chart_rounded,
                      title: DriverStrings.financeAndTax,
                      colors: colors,
                      typography: typography,
                      onTap: onOpenFinance,
                      boldTitle: true,
                      showDivider: false,
                    ),
                  ],
                ).driverFadeSlideIn(staggerIndex: 3),
                SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 88,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.colors,
    required this.typography,
    required this.model,
    required this.onTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverIdentityViewModel model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      onTap: onTap,
      padding: const EdgeInsets.all(DriverSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                child: Text(
                  model.initials,
                  style: typography.headlineSmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: DriverSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.headline,
                      style: typography.headlineSmall.copyWith(
                        color: model.emphasizePlaceholder
                            ? colors.textMuted
                            : colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (model.email != null && model.email!.isNotEmpty) ...[
                      const SizedBox(height: DriverSpacing.xs),
                      Text(
                        model.email!,
                        style: typography.bodySmall.copyWith(
                          color: colors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (model.showFoundingShield) ...[
                      const SizedBox(height: DriverSpacing.sm),
                      DriverStatusBadge(
                        label: model.foundingNumber != null
                            ? '${DriverStrings.billingFoundingMember} #${model.foundingNumber}'
                            : DriverStrings.billingFoundingMember,
                        colors: colors,
                        typography: typography,
                        tone: DriverStatusTone.success,
                        icon: Icons.workspace_premium_rounded,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
          const SizedBox(height: DriverSpacing.lg),
          Row(
            children: [
              Icon(Icons.star_rounded, size: 18, color: colors.primary),
              const SizedBox(width: DriverSpacing.xs),
              Text(
                model.rating.toStringAsFixed(1),
                style: typography.titleMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: Text(
                  DriverStrings.profileRatingHint,
                  style: typography.bodySmall.copyWith(color: colors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (model.isVerifiedBadge)
                DriverStatusBadge(
                  label: DriverStrings.statusVerified,
                  colors: colors,
                  typography: typography,
                  tone: DriverStatusTone.success,
                  icon: Icons.verified_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleSummaryCard extends StatelessWidget {
  const _VehicleSummaryCard({
    required this.colors,
    required this.typography,
    required this.model,
    required this.onTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverIdentityViewModel model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car_rounded, color: colors.primary),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: Text(
                  DriverStrings.vehicle,
                  style: typography.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (model.showVehicleVerified)
                DriverStatusBadge(
                  label: DriverStrings.statusVerified,
                  colors: colors,
                  typography: typography,
                  tone: DriverStatusTone.success,
                ),
            ],
          ),
          const SizedBox(height: DriverSpacing.md),
          Text(
            model.vehiclePlate,
            style: typography.displaySmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: DriverSpacing.xs),
          Text(
            model.vehicleDisplay,
            style: typography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          if (model.apkExpiryLabel != null) ...[
            const SizedBox(height: DriverSpacing.sm),
            Text(
              'APK · ${model.apkExpiryLabel}',
              style: typography.labelSmall.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
