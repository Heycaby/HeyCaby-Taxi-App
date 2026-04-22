import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../models/rider_vehicle_category.dart';
import '../services/nearby_supply_service.dart';

bool _isDarkSurface(HeyCabyColorTokens colors) =>
    ThemeData.estimateBrightnessForColor(colors.card) == Brightness.dark;

/// Per-category “team” colors — readable on [colors.card] in light and dark themes.
({Color primary, Color soft}) _teamPalette(
  RiderVehicleCategory category,
  bool isDark,
) {
  switch (category) {
    case RiderVehicleCategory.standard:
      return isDark
          ? (primary: const Color(0xFF8AB4E8), soft: const Color(0xFF243548))
          : (primary: const Color(0xFF3566A8), soft: const Color(0xFFE9F0FA));
    case RiderVehicleCategory.comfort:
      return isDark
          ? (primary: const Color(0xFFC4A5FF), soft: const Color(0xFF342A4A))
          : (primary: const Color(0xFF6B4FB8), soft: const Color(0xFFF0EAFA));
    case RiderVehicleCategory.taxibus:
      return isDark
          ? (primary: const Color(0xFF5EEAD4), soft: const Color(0xFF143D38))
          : (primary: const Color(0xFF0F766E), soft: const Color(0xFFE6F7F4));
    case RiderVehicleCategory.wheelchair:
      return isDark
          ? (primary: const Color(0xFFFFB088), soft: const Color(0xFF4A3028))
          : (primary: const Color(0xFFC45D3A), soft: const Color(0xFFFDF0EB));
  }
}

/// Expandable category card with per-driver selection and "Post to All" option.
class VehicleCategorySupplyCard extends StatelessWidget {
  const VehicleCategorySupplyCard({
    super.key,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.snapshot,
    required this.selectedCategory,
    required this.isExpanded,
    required this.onSelect,
    required this.onToggleExpand,
    required this.colors,
    required this.typography,
    required this.petFriendly,
    required this.onPetFriendlyChanged,
    this.selectedDriverId,
    this.postToAllSelected = false,
    this.onSelectDriver,
    this.onPostToAll,
  });

  final RiderVehicleCategory category;
  final String title;
  final String subtitle;
  final IconData icon;
  final CategorySupplySnapshot snapshot;
  final RiderVehicleCategory? selectedCategory;
  final bool isExpanded;
  final VoidCallback onSelect;
  final VoidCallback onToggleExpand;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;

  /// Shared ride flag — toggles on any category card stay in sync.
  final bool petFriendly;
  final ValueChanged<bool> onPetFriendlyChanged;

  /// Which specific driver is selected (null = none / post-to-all).
  final String? selectedDriverId;

  /// True when user explicitly chose "post to all" for this category.
  final bool postToAllSelected;

  final void Function(String driverId, double fare)? onSelectDriver;
  final VoidCallback? onPostToAll;

  static String _fmtKm(double km) =>
      km < 10 ? km.toStringAsFixed(1) : km.round().toString();

  bool get _isSelected => selectedCategory == category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = _isDarkSurface(colors);
    final team = _teamPalette(category, isDark);
    final accent = team.primary;
    final fillTop = Color.lerp(colors.card, team.soft, _isSelected ? 0.72 : 0.38)!;
    final fillBottom = Color.lerp(colors.card, team.soft, _isSelected ? 0.28 : 0.08)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fillTop, fillBottom],
        ),
        border: Border.all(
          color: _isSelected
              ? accent
              : accent.withValues(alpha: isDark ? 0.35 : 0.28),
          width: _isSelected ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: _isSelected ? 0.22 : 0.10),
            blurRadius: _isSelected ? 22 : 14,
            offset: Offset(0, _isSelected ? 8 : 5),
          ),
          BoxShadow(
            color: colors.text.withValues(alpha: _isSelected ? 0.05 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Category header row ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 12, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2),
                    child: Radio<RiderVehicleCategory>(
                      value: category,
                      groupValue: selectedCategory,
                      onChanged: (_) => onSelect(),
                      activeColor: accent,
                      fillColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? accent
                            : colors.textMid,
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: onSelect,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(0, 2, 4, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        team.soft,
                                        Color.lerp(team.soft, accent, 0.22)!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.22),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    icon,
                                    color: accent,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: typography.headingSmall.copyWith(
                                      color: colors.text,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.35,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                8, 6, 4, 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: petFriendly
                                      ? accent.withValues(alpha: 0.42)
                                      : accent.withValues(alpha: 0.14),
                                ),
                                color: petFriendly
                                    ? accent.withValues(
                                        alpha: isDark ? 0.16 : 0.09,
                                      )
                                    : colors.text.withValues(alpha: 0.03),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.pets_rounded,
                                    size: 20,
                                    color: petFriendly
                                        ? accent
                                        : colors.textMid,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.petFriendly,
                                      style: typography.labelLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colors.text,
                                      ),
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: petFriendly,
                                    onChanged: onPetFriendlyChanged,
                                    activeTrackColor: accent,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Driver count: same font family as caption (Plus Jakarta), not display Syne.
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                12, 10, 12, 10,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: isDark ? 0.16 : 0.11),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.groups_rounded,
                                    size: 20,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${snapshot.driverCount}',
                                            style: typography.titleLarge.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: accent,
                                              height: 1.25,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                ' ${l10n.vehicleSupplyCountCaption}',
                                            style: typography.bodyMedium.copyWith(
                                              color: colors.textMid,
                                              fontWeight: FontWeight.w600,
                                              height: 1.25,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              subtitle,
                              style: typography.bodySmall.copyWith(
                                color: colors.textSoft,
                                height: 1.4,
                              ),
                            ),
                            if (snapshot.nearestDistanceKm != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.near_me_rounded,
                                    size: 16,
                                    color: accent.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      l10n.vehicleSupplyNearestKm(
                                        _fmtKm(snapshot.nearestDistanceKm!),
                                      ),
                                      style: typography.bodyMedium.copyWith(
                                        color: colors.text,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (snapshot.fromPriceEuro != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                l10n.vehicleSupplyFromPrice(
                                  snapshot.fromPriceEuro!.toStringAsFixed(
                                    snapshot.fromPriceEuro! ==
                                            snapshot.fromPriceEuro!.roundToDouble()
                                        ? 0
                                        : 1,
                                  ),
                                ),
                                style: typography.headingSmall.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleExpand,
                    tooltip: isExpanded
                        ? l10n.vehicleSupplyHideDrivers
                        : l10n.vehicleSupplyShowDrivers,
                    icon: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: _isSelected ? accent : colors.textMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Expanded driver list ────────────────────────────────────────
            if (isExpanded) ...[
              Divider(height: 1, thickness: 1, color: accent.withValues(alpha: 0.18)),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 16),
                child: snapshot.drivers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: accent.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.vehicleSupplyNoDriversInCategory,
                                style: typography.bodyMedium.copyWith(
                                  color: colors.textMid,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < snapshot.drivers.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            _DriverOfferCard(
                              driver: snapshot.drivers[i],
                              isSelected:
                                  selectedDriverId == snapshot.drivers[i].driverId,
                              colors: colors,
                              typo: typography,
                              accentColor: accent,
                              onSelect: () => onSelectDriver?.call(
                                snapshot.drivers[i].driverId,
                                snapshot.drivers[i].estimatedFareEuro,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _PostToAllButton(
                            count: snapshot.drivers.length,
                            isActive: postToAllSelected,
                            colors: colors,
                            typo: typography,
                            accentColor: accent,
                            onTap: onPostToAll ?? () {},
                          ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Driver offer card (per-driver row in expanded section) ────────────────────
class _DriverOfferCard extends StatelessWidget {
  final NearbyDriverOffer driver;
  final bool isSelected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Color accentColor;
  final VoidCallback onSelect;

  const _DriverOfferCard({
    required this.driver,
    required this.isSelected,
    required this.colors,
    required this.typo,
    required this.accentColor,
    required this.onSelect,
  });

  String get _initials {
    final parts = driver.driverName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return driver.driverName.isNotEmpty ? driver.driverName[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor.withValues(
                alpha: ThemeData.estimateBrightnessForColor(colors.card) ==
                        Brightness.dark
                    ? 0.2
                    : 0.12,
              )
            : colors.bgAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? accentColor : colors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.22)
                  : colors.border.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: driver.driverPhoto != null
                ? ClipOval(
                    child: Image.network(
                      driver.driverPhoto!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(_initials,
                            style: typo.labelLarge.copyWith(
                              color:
                                  isSelected ? accentColor : colors.textMid,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  )
                : Center(
                    child: Text(_initials,
                        style: typo.labelLarge.copyWith(
                          color: isSelected ? accentColor : colors.textMid,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
          ),
          const SizedBox(width: 12),

          // Name + rating + distance
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.driverName,
                  style: typo.bodyMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: colors.warning, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      driver.driverRating.toStringAsFixed(1),
                      style: typo.bodySmall.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '  ·  ${driver.distanceKmPickup < 10 ? driver.distanceKmPickup.toStringAsFixed(1) : driver.distanceKmPickup.round()} km',
                      style: typo.bodySmall.copyWith(color: colors.textSoft),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Fare + select button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                driver.estimatedFareEuro == driver.estimatedFareEuro.roundToDouble()
                    ? '€${driver.estimatedFareEuro.toStringAsFixed(0)}'
                    : '€${driver.estimatedFareEuro.toStringAsFixed(1)}',
                style: typo.headingMedium.copyWith(
                  color: isSelected ? accentColor : colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onSelect,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor : colors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? accentColor : colors.border,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    isSelected ? '✓ Selected' : 'Select',
                    style: typo.labelSmall.copyWith(
                      color: isSelected ? colors.card : accentColor,
                      fontWeight: FontWeight.w700,
                    ),
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

// ── Post to All button ────────────────────────────────────────────────────────
class _PostToAllButton extends StatelessWidget {
  final int count;
  final bool isActive;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Color accentColor;
  final VoidCallback onTap;

  const _PostToAllButton({
    required this.count,
    required this.isActive,
    required this.colors,
    required this.typo,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? accentColor : colors.border,
            width: isActive ? 0 : 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.send_rounded,
              size: 16,
              color: isActive ? colors.card : accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Post to all $count driver${count == 1 ? '' : 's'}',
              style: typo.labelSmall.copyWith(
                color: isActive ? colors.card : accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
