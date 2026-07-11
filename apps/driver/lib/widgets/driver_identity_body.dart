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
    required this.completionItems,
    this.profilePhotoUrl,
    this.vehiclePhotoUrl,
    this.email,
    this.emphasizePlaceholder = false,
    this.foundingNumber,
    this.showFoundingShield = false,
    this.isVerifiedBadge = false,
    this.showVehicleVerified = false,
    this.apkExpiryLabel,
    this.vehicleDescriptor,
    this.vehicleSeats,
  });

  final String headline;
  final String initials;
  final String? email;
  final String? profilePhotoUrl;
  final String? vehiclePhotoUrl;
  final bool emphasizePlaceholder;
  final double rating;
  final int? foundingNumber;
  final bool showFoundingShield;
  final bool isVerifiedBadge;
  final String vehiclePlate;
  final String vehicleDisplay;
  final bool showVehicleVerified;
  final String? apkExpiryLabel;
  final String? vehicleDescriptor;
  final int? vehicleSeats;
  final List<DriverIdentityRequirement> completionItems;
}

class DriverIdentityRequirement {
  const DriverIdentityRequirement({
    required this.key,
    required this.label,
    required this.complete,
  });

  final String key;
  final String label;
  final bool complete;
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
    required this.onAddVehiclePhoto,
    required this.onOpenRatings,
    required this.onOpenSettings,
    required this.onOpenRequirement,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverIdentityViewModel model;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenVehicle;
  final VoidCallback onAddVehiclePhoto;
  final VoidCallback onOpenRatings;
  final VoidCallback onOpenSettings;
  final void Function(String key) onOpenRequirement;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DriverSpacing.screenEdge,
              DriverSpacing.sm,
              DriverSpacing.screenEdge,
              DriverSpacing.md,
            ),
            child: Center(
              child: Text(
                DriverStrings.profile,
                style: typography.headlineSmall.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ).driverFadeSlideIn(staggerIndex: 0),
            ),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DriverSpacing.screenEdge,
                    DriverSpacing.sm,
                    DriverSpacing.screenEdge,
                    DriverSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileHeroCard(
                        colors: colors,
                        typography: typography,
                        model: model,
                        onTap: onEditProfile,
                        onOpenRatings: onOpenRatings,
                      ).driverFadeSlideIn(staggerIndex: 1),
                      const SizedBox(height: DriverSpacing.lg),
                      _VehicleSummaryCard(
                        colors: colors,
                        typography: typography,
                        model: model,
                        onTap: onOpenVehicle,
                        onAddPhoto: onAddVehiclePhoto,
                      ).driverFadeSlideIn(staggerIndex: 2),
                      const SizedBox(height: DriverSpacing.lg),
                      _ProfileCompletionCard(
                        colors: colors,
                        typography: typography,
                        items: model.completionItems,
                        onTapItem: onOpenRequirement,
                      ).driverFadeSlideIn(staggerIndex: 3),
                      const SizedBox(height: DriverSpacing.xl),
                      DriverSettingsGroupCard(
                        colors: colors,
                        children: [
                          DriverSettingsNavRow(
                            icon: Icons.settings_rounded,
                            title: DriverStrings.settings,
                            colors: colors,
                            typography: typography,
                            boldTitle: true,
                            showDivider: false,
                            onTap: onOpenSettings,
                          ),
                        ],
                      ).driverFadeSlideIn(staggerIndex: 4),
                      SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 88,
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    required this.onOpenRatings,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverIdentityViewModel model;
  final VoidCallback onTap;
  final VoidCallback onOpenRatings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary.withValues(alpha: 0.055),
                        colors.primary.withValues(alpha: 0.018),
                        colors.card,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DriverSpacing.xl,
                      DriverSpacing.xl,
                      DriverSpacing.xl,
                      DriverSpacing.lg,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colors.card,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.text.withValues(alpha: 0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                backgroundColor:
                                    colors.primary.withValues(alpha: 0.055),
                                child: _ProfileAvatarContent(
                                  photoUrl: model.profilePhotoUrl,
                                  initials: model.initials,
                                  colors: colors,
                                  typography: typography,
                                ),
                              ),
                            ),
                            PositionedDirectional(
                              end: 4,
                              bottom: 4,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: colors.card, width: 3),
                                ),
                                child: Icon(
                                  Icons.edit_rounded,
                                  color: colors.card,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: DriverSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      model.headline,
                                      style: typography.headlineSmall.copyWith(
                                        color: model.emphasizePlaceholder
                                            ? colors.textMuted
                                            : colors.text,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                        height: 1.08,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: colors.textMuted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: DriverSpacing.sm),
                              Wrap(
                                spacing: DriverSpacing.xs,
                                runSpacing: DriverSpacing.xs,
                                children: [
                                  _PlatePill(
                                    label: model.vehiclePlate == '—'
                                        ? DriverStrings.vehicleCardTitle
                                        : model.vehiclePlate,
                                    colors: colors,
                                    typography: typography,
                                  ),
                                  if (model.isVerifiedBadge)
                                    DriverStatusBadge(
                                      label: DriverStrings
                                          .vehicleVerifiedTaxiEnglish,
                                      colors: colors,
                                      typography: typography,
                                      tone: DriverStatusTone.success,
                                      icon: Icons.verified_rounded,
                                    ),
                                ],
                              ),
                              if (model.email != null &&
                                  model.email!.isNotEmpty) ...[
                                const SizedBox(height: DriverSpacing.sm),
                                Text(
                                  model.email!,
                                  style: typography.bodySmall.copyWith(
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DriverSpacing.xl,
                    DriverSpacing.md,
                    DriverSpacing.xl,
                    DriverSpacing.xl,
                  ),
                  child: Row(
                    children: [
                      _ProfileStatPill(
                        colors: colors,
                        typography: typography,
                        icon: Icons.star_rounded,
                        value: model.rating.toStringAsFixed(1),
                        label: DriverStrings.driverRating,
                        onTap: onOpenRatings,
                      ),
                      const SizedBox(width: DriverSpacing.sm),
                      Expanded(
                        child: Text(
                          DriverStrings.profileRatingHint,
                          style: typography.bodySmall.copyWith(
                            color: colors.textMuted,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStatPill extends StatelessWidget {
  const _ProfileStatPill({
    required this.colors,
    required this.typography,
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.md,
            vertical: DriverSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.primary.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colors.warning, size: 18),
              const SizedBox(width: DriverSpacing.xs),
              Text(
                value,
                style: typography.titleMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: DriverSpacing.xs),
              Text(
                label,
                style: typography.labelSmall.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: DriverSpacing.xs),
                Icon(Icons.chevron_right_rounded,
                    color: colors.textMuted, size: 17),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatarContent extends StatelessWidget {
  const _ProfileAvatarContent({
    required this.photoUrl,
    required this.initials,
    required this.colors,
    required this.typography,
  });

  final String? photoUrl;
  final String initials;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    if (url != null && url.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          url,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _InitialsAvatar(
            initials: initials,
            colors: colors,
            typography: typography,
          ),
        ),
      );
    }
    return _InitialsAvatar(
      initials: initials,
      colors: colors,
      typography: typography,
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.initials,
    required this.colors,
    required this.typography,
  });

  final String initials;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: typography.headlineSmall.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PlatePill extends StatelessWidget {
  const _PlatePill({
    required this.label,
    required this.colors,
    required this.typography,
  });

  final String label;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_rounded, size: 14, color: colors.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.labelSmall.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
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
    required this.onAddPhoto,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverIdentityViewModel model;
  final VoidCallback onTap;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final photoUrl = model.vehiclePhotoUrl?.trim();
    final hasPhoto = photoUrl != null && photoUrl.startsWith('http');
    final descriptor = model.vehicleDescriptor?.trim();
    final vehicleTitle = descriptor != null && descriptor.isNotEmpty
        ? descriptor
        : model.vehicleDisplay;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.border.withValues(alpha: 0.84)),
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 172,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasPhoto)
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _VehiclePhotoFallback(
                              colors: colors,
                              typography: typography,
                              onAddPhoto: onAddPhoto,
                            ),
                          ),
                          PositionedDirectional(
                            end: DriverSpacing.lg,
                            top: DriverSpacing.lg,
                            child: _VehiclePhotoActionChip(
                              colors: colors,
                              typography: typography,
                              label: DriverStrings.replaceVehiclePhoto,
                              icon: Icons.photo_camera_rounded,
                              onTap: onAddPhoto,
                            ),
                          ),
                        ],
                      )
                    else
                      _VehiclePhotoFallback(
                        colors: colors,
                        typography: typography,
                        onAddPhoto: onAddPhoto,
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.text.withValues(alpha: 0.00),
                            colors.text.withValues(alpha: 0.08),
                          ],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: DriverSpacing.lg,
                      top: DriverSpacing.lg,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DriverSpacing.md,
                          vertical: DriverSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: colors.card.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.72),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_car_rounded,
                              color: colors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: DriverSpacing.xs),
                            Text(
                              DriverStrings.vehicle,
                              style: typography.labelMedium.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      end: DriverSpacing.lg,
                      bottom: DriverSpacing.lg,
                      child: _VehiclePhotoStatusPill(
                        colors: colors,
                        typography: typography,
                        complete: hasPhoto,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DriverSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            vehicleTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: typography.titleLarge.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w900,
                              height: 1.08,
                            ),
                          ),
                        ),
                        const SizedBox(width: DriverSpacing.md),
                        if (model.showVehicleVerified)
                          DriverStatusBadge(
                            label: DriverStrings.vehicleVerifiedTaxiEnglish,
                            colors: colors,
                            typography: typography,
                            tone: DriverStatusTone.success,
                          ),
                      ],
                    ),
                    const SizedBox(height: DriverSpacing.lg),
                    Text(
                      DriverStrings.vehiclePlate,
                      style: typography.labelSmall.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.vehiclePlate,
                      style: typography.displaySmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    Wrap(
                      spacing: DriverSpacing.sm,
                      runSpacing: DriverSpacing.sm,
                      children: [
                        if (model.vehicleSeats != null &&
                            model.vehicleSeats! > 0)
                          _VehicleInfoChip(
                            colors: colors,
                            typography: typography,
                            icon: Icons.event_seat_rounded,
                            label:
                                '${model.vehicleSeats} ${DriverStrings.vehicleSeatsLabel}',
                          ),
                        if (model.apkExpiryLabel != null)
                          _VehicleInfoChip(
                            colors: colors,
                            typography: typography,
                            icon: Icons.verified_user_rounded,
                            label: DriverStrings.vehicleApkExpiryLine(
                              model.apkExpiryLabel!,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: DriverSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onAddPhoto,
                            icon: const Icon(Icons.add_a_photo_rounded),
                            label: Text(
                              hasPhoto
                                  ? DriverStrings.replaceVehiclePhoto
                                  : DriverStrings.addVehiclePhoto,
                            ),
                          ),
                        ),
                        const SizedBox(width: DriverSpacing.sm),
                        IconButton(
                          tooltip: DriverStrings.vehicleDetails,
                          onPressed: onTap,
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehiclePhotoStatusPill extends StatelessWidget {
  const _VehiclePhotoStatusPill({
    required this.colors,
    required this.typography,
    required this.complete,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: complete ? colors.primary : colors.warning,
            size: 16,
          ),
          const SizedBox(width: DriverSpacing.xs),
          Text(
            complete
                ? DriverStrings.vehiclePhotoUploadedStatus
                : DriverStrings.vehiclePhotoMissingStatus,
            style: typography.labelSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleInfoChip extends StatelessWidget {
  const _VehicleInfoChip({
    required this.colors,
    required this.typography,
    required this.icon,
    required this.label,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverSpacing.md,
        vertical: DriverSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: colors.textMuted),
          const SizedBox(width: DriverSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.labelMedium.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehiclePhotoFallback extends StatelessWidget {
  const _VehiclePhotoFallback({
    required this.colors,
    required this.typography,
    required this.onAddPhoto,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAddPhoto,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surface,
                    colors.surface,
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: DriverSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: colors.text.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.local_taxi_rounded,
                        color: colors.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    _VehiclePhotoActionChip(
                      colors: colors,
                      typography: typography,
                      label: DriverStrings.vehiclePhotoMissingCta,
                      icon: Icons.add_a_photo_rounded,
                      onTap: onAddPhoto,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehiclePhotoActionChip extends StatelessWidget {
  const _VehiclePhotoActionChip({
    required this.colors,
    required this.typography,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.md,
            vertical: DriverSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: colors.card),
              const SizedBox(width: DriverSpacing.xs),
              Text(
                label,
                style: typography.labelMedium.copyWith(
                  color: colors.card,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard({
    required this.colors,
    required this.typography,
    required this.items,
    required this.onTapItem,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final List<DriverIdentityRequirement> items;
  final void Function(String key) onTapItem;

  @override
  Widget build(BuildContext context) {
    final completed = items.where((item) => item.complete).length;
    final total = items.length;
    final progress = total == 0 ? 0.0 : completed / total;

    return DriverCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.task_alt_rounded, color: colors.primary),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverStrings.profileCompletionTitle,
                      style: typography.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      completed == total
                          ? DriverStrings.profileCompletionReady
                          : DriverStrings.profileCompletionProgress(
                              completed,
                              total,
                            ),
                      style: typography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.border.withValues(alpha: 0.55),
              color: colors.primary,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          ...items.map(
            (item) => _RequirementRow(
              item: item,
              colors: colors,
              typography: typography,
              onTap: item.complete ? null : () => onTapItem(item.key),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.item,
    required this.colors,
    required this.typography,
    this.onTap,
  });

  final DriverIdentityRequirement item;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            item.complete
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: item.complete ? colors.primary : colors.textMuted,
            size: 20,
          ),
          const SizedBox(width: DriverSpacing.sm),
          Expanded(
            child: Text(
              item.label,
              style: typography.bodyMedium.copyWith(
                color: item.complete ? colors.textSecondary : colors.text,
                fontWeight: item.complete ? FontWeight.w600 : FontWeight.w800,
              ),
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: colors.textMuted),
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: row,
      ),
    );
  }
}
