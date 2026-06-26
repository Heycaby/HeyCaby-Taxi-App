import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../models/rider_vehicle_category.dart';
import '../providers/booking_provider.dart';
import '../providers/nearby_category_supply_provider.dart';
import '../providers/trip_category_estimates_provider.dart';
import '../services/booking_flow_navigation.dart';
import '../services/nearby_supply_service.dart';
import '../widgets/booking/smart_vehicle_bundle_card.dart';
import '../widgets/primary_cancel_row.dart';
import '../widgets/vehicle_category_supply_card.dart';

class VehicleCategoryScreen extends ConsumerStatefulWidget {
  const VehicleCategoryScreen({
    super.key,
    this.returnToSummaryAfterSave = false,
  });

  /// When opened from trip summary (Edit), continue/save returns to summary
  /// without stacking another `/summary` route.
  final bool returnToSummaryAfterSave;

  @override
  ConsumerState<VehicleCategoryScreen> createState() =>
      _VehicleCategoryScreenState();
}

class _VehicleCategoryScreenState extends ConsumerState<VehicleCategoryScreen> {
  RiderVehicleCategory? _selectedCategory;
  RiderVehicleCategory? _expandedCategory;

  /// Specific driver the rider has chosen (null = post to all).
  String? _selectedDriverId;
  double? _selectedDriverFare;

  /// True when rider tapped "Post to all" explicitly.
  bool _postToAll = false;

  bool _seededFromBookingVehicle = false;
  bool _categoryManuallyTouched = false;
  bool _supplyFallbackScheduled = false;
  bool _showInvalidPreferredBanner = false;
  bool _showSupplyFallbackBanner = false;
  bool _selectedFromIdentityPreferred = false;

  /// Multi-category bundle (keys from Supabase estimates).
  Set<String>? _smartSelection;
  String? _lastEstimateSig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(tripCategoryEstimatesProvider);
      _seedVehicleFromProfile();
      _mergeContactFromIdentityIfEmpty();
    });
  }

  Future<void> _mergeContactFromIdentityIfEmpty() async {
    if (!mounted) return;
    final b = ref.read(bookingProvider);
    if ((b.pickupContactName ?? '').trim().isNotEmpty) return;
    final identity = await ref.read(riderIdentityProvider.future);
    if (!mounted) return;
    ref.read(bookingProvider.notifier).mergeFromRiderIdentity(identity);
  }

  Future<void> _seedVehicleFromProfile() async {
    if (!mounted) return;
    final booking = ref.read(bookingProvider);
    if (booking.vehicleCategory != null &&
        booking.vehicleCategory!.trim().isNotEmpty) {
      final c = RiderVehicleCategory.tryParse(booking.vehicleCategory);
      if (c != null) {
        setState(() {
          _seededFromBookingVehicle = true;
          _selectedCategory = c;
          _expandedCategory = c;
        });
      }
      return;
    }
    final identity = await ref.read(riderIdentityProvider.future);
    if (!mounted) return;
    final raw = identity.preferredVehicleCategory?.trim();
    if (raw == null || raw.isEmpty) return;

    final c = RiderVehicleCategory.tryParse(raw);
    if (c == null) {
      if (identity.preferredPetFriendly != null) {
        ref
            .read(bookingProvider.notifier)
            .setPetFriendly(identity.preferredPetFriendly!);
      }
      setState(() {
        _selectedCategory = RiderVehicleCategory.standard;
        _expandedCategory = RiderVehicleCategory.standard;
        _showInvalidPreferredBanner = true;
      });
      return;
    }

    if (identity.preferredPetFriendly != null) {
      ref
          .read(bookingProvider.notifier)
          .setPetFriendly(identity.preferredPetFriendly!);
    }
    setState(() {
      _selectedFromIdentityPreferred = true;
      _selectedCategory = c;
      _expandedCategory = c;
    });
  }

  static CategorySupplySnapshot _snapFor(
    Map<RiderVehicleCategory, CategorySupplySnapshot>? data,
    RiderVehicleCategory c,
  ) {
    if (data == null) return CategorySupplySnapshot.empty(c);
    return data[c] ?? CategorySupplySnapshot.empty(c);
  }

  void _selectCategory(RiderVehicleCategory c) {
    _categoryManuallyTouched = true;
    setState(() {
      if (_selectedCategory != c) {
        _selectedDriverId = null;
        _selectedDriverFare = null;
        _postToAll = false;
      }
      _selectedCategory = c;
      _expandedCategory = c;
    });
  }

  void _toggleExpand(RiderVehicleCategory c) {
    setState(() {
      _expandedCategory = _expandedCategory == c ? null : c;
    });
  }

  void _selectDriver(String driverId, double fare) {
    HapticService.selectionClick();
    setState(() {
      _selectedDriverId = driverId;
      _selectedDriverFare = fare;
      _postToAll = false;
    });
  }

  void _postToAllForCategory() {
    HapticService.selectionClick();
    setState(() {
      _selectedDriverId = null;
      _selectedDriverFare = null;
      _postToAll = true;
    });
  }

  String _nextLabel(AppLocalizations l10n) {
    if (_selectedDriverId != null) return l10n.bookDriver;
    if (_postToAll) return l10n.postToAllDrivers;
    return l10n.next;
  }

  String _vehicleLine(RiderVehicleCategory c, AppLocalizations l10n) {
    switch (c) {
      case RiderVehicleCategory.standard:
        return l10n.vehicleStandard;
      case RiderVehicleCategory.comfort:
        return l10n.vehicleComfort;
      case RiderVehicleCategory.taxibus:
        return l10n.vehicleTaxibus;
      case RiderVehicleCategory.wheelchair:
        return l10n.vehicleWheelchair;
    }
  }

  void _maybeApplySupplyFallback(
    Map<RiderVehicleCategory, CategorySupplySnapshot>? supplyMap,
  ) {
    if (supplyMap == null ||
        _seededFromBookingVehicle ||
        _categoryManuallyTouched ||
        _supplyFallbackScheduled ||
        _selectedCategory == null) {
      return;
    }
    final id = ref.read(riderIdentityProvider).valueOrNull;
    final preferred =
        RiderVehicleCategory.tryParse(id?.preferredVehicleCategory);
    if (preferred == null || _selectedCategory != preferred) return;

    final snap = supplyMap[preferred] ?? CategorySupplySnapshot.empty(preferred);
    if (snap.driverCount > 0) return;

    RiderVehicleCategory? replacement;
    for (final cat in RiderVehicleCategory.values) {
      final s = supplyMap[cat] ?? CategorySupplySnapshot.empty(cat);
      if (s.driverCount > 0) {
        replacement = cat;
        break;
      }
    }
    if (replacement == null) return;

    final picked = replacement;
    _supplyFallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedCategory = picked;
        _expandedCategory = picked;
        _showSupplyFallbackBanner = true;
        _selectedDriverId = null;
        _selectedDriverFare = null;
        _postToAll = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);
    final estAsync = ref.watch(tripCategoryEstimatesProvider);
    final estimates = estAsync.valueOrNull ?? [];
    final hasRoute = booking.pickup != null && booking.destination != null;
    final hasEstimateRows = estimates.isNotEmpty;
    final showSmartExperience = hasRoute;
    final showDegradedPicker = showSmartExperience &&
        !estAsync.isLoading &&
        !hasEstimateRows;

    ref.listen(tripCategoryEstimatesProvider, (prev, next) {
      next.whenData((list) {
        if (list.isEmpty || !mounted) return;
        final sig = list.map((e) => '${e.categoryKey}:${e.priceEuro}').join('|');
        if (_lastEstimateSig == sig) return;
        _lastEstimateSig = sig;
        final b = ref.read(bookingProvider);
        final fromB =
            b.vehicleCategories.where((k) => list.any((e) => e.categoryKey == k)).toSet();
        final initial = fromB.isNotEmpty
            ? fromB
            : (b.vehicleCategory != null &&
                    list.any((e) => e.categoryKey == b.vehicleCategory)
                ? {b.vehicleCategory!}
                : list.map((e) => e.categoryKey).toSet());
        setState(() => _smartSelection = initial);
      });
    });

    final canProceed = !showSmartExperience
        ? _selectedCategory != null
        : hasEstimateRows
            ? (_smartSelection != null && _smartSelection!.isNotEmpty)
            : _selectedCategory != null;

    final mq = MediaQuery.of(context);
    // PrimaryCancelRow is 52px tall inside padded footer; reserve space so the
    // last scrollable card clears the sticky action bar.
    final footerReserve = HeyCabySpacing.component +
        52 +
        math.max(HeyCabySpacing.screenEdge, mq.padding.bottom) +
        HeyCabySpacing.element;

    final supplyAsync = ref.watch(nearbyCategorySupplyProvider);
    final supplyMap = supplyAsync.valueOrNull;
    _maybeApplySupplyFallback(supplyMap);

    Widget buildCategoryCard(
      RiderVehicleCategory cat,
      String title,
      String subtitle,
      IconData icon,
    ) {
      return VehicleCategorySupplyCard(
        category: cat,
        title: title,
        subtitle: subtitle,
        icon: icon,
        snapshot: _snapFor(supplyMap, cat),
        selectedCategory: _selectedCategory,
        isExpanded: _expandedCategory == cat,
        onSelect: () => _selectCategory(cat),
        onToggleExpand: () => _toggleExpand(cat),
        colors: colors,
        typography: typo,
        selectedDriverId: _selectedCategory == cat ? _selectedDriverId : null,
        postToAllSelected: _selectedCategory == cat && _postToAll,
        onSelectDriver: _selectDriver,
        onPostToAll: _postToAllForCategory,
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        shadowColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: colors.border),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'What kind of ride do you want?',
          style: typo.headingSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.15,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.bg,
              Color.lerp(colors.bg, colors.accent, 0.045)!,
            ],
          ),
        ),
        child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (booking.pickup == null)
              Material(
                color: colors.warning.withValues(alpha: 0.12),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.componentSmall,
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.element,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colors.warning, size: 22),
                      SizedBox(width: HeyCabySpacing.buttonHorizontal),
                      Expanded(
                        child: Text(
                          l10n.vehicleSupplyNoPickup,
                          style: typo.bodySmall.copyWith(color: colors.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showInvalidPreferredBanner)
              Material(
                color: colors.warning.withValues(alpha: 0.12),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.componentSmall,
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.element,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colors.warning, size: 22),
                      SizedBox(width: HeyCabySpacing.buttonHorizontal),
                      Expanded(
                        child: Text(
                          l10n.vehiclePreferredCategoryUnavailable,
                          style: typo.bodySmall.copyWith(color: colors.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showSupplyFallbackBanner)
              Material(
                color: colors.warning.withValues(alpha: 0.12),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.componentSmall,
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.element,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colors.warning, size: 22),
                      SizedBox(width: HeyCabySpacing.buttonHorizontal),
                      Expanded(
                        child: Text(
                          l10n.vehiclePreferredNoDriversNearby,
                          style: typo.bodySmall.copyWith(color: colors.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (supplyAsync.isLoading)
              LinearProgressIndicator(
                backgroundColor: colors.border,
                color: colors.accent,
                minHeight: 3,
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  HeyCabySpacing.screenEdge,
                  HeyCabySpacing.sectionMedium,
                  HeyCabySpacing.screenEdge,
                  HeyCabySpacing.sectionMedium + footerReserve,
                ),
                children: [
                  if (showSmartExperience) ...[
                    if (hasEstimateRows && _smartSelection != null)
                      SmartVehicleBundleCard(
                        estimates: estimates,
                        selectedKeys: _smartSelection!,
                        onSelectionChanged: (s) =>
                            setState(() => _smartSelection = s),
                        colors: colors,
                        typography: typo,
                        l10n: l10n,
                      )
                    else if (estAsync.isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colors.accent,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          18, 18, 18, 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: colors.card,
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: colors.text.withValues(alpha: 0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.smartBundleLoadError,
                              style: typo.bodyMedium.copyWith(
                                color: colors.textMid,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.tonal(
                              onPressed: () {
                                HapticService.lightTap();
                                ref.invalidate(tripCategoryEstimatesProvider);
                              },
                              child: Text(l10n.smartBundleRetry),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: HeyCabySpacing.sectionMedium),
                  ],
                  if (!showSmartExperience || showDegradedPicker) ...[
                    buildCategoryCard(
                      RiderVehicleCategory.standard,
                      l10n.vehicleStandard,
                      'Everyday rides - Up to 4 passengers',
                      Icons.directions_car_outlined,
                    ),
                    SizedBox(height: HeyCabySpacing.componentSmall),
                    buildCategoryCard(
                      RiderVehicleCategory.comfort,
                      l10n.vehicleComfort,
                      'More comfort and space - Up to 4 passengers',
                      Icons.airline_seat_recline_extra,
                    ),
                    SizedBox(height: HeyCabySpacing.componentSmall),
                    buildCategoryCard(
                      RiderVehicleCategory.taxibus,
                      'Taxi Bus',
                      'Larger vehicle - Up to 8-9 passengers',
                      Icons.airport_shuttle_outlined,
                    ),
                    SizedBox(height: HeyCabySpacing.componentSmall),
                    buildCategoryCard(
                      RiderVehicleCategory.wheelchair,
                      l10n.vehicleWheelchair,
                      'Accessible vehicle',
                      Icons.accessible,
                    ),
                    SizedBox(height: HeyCabySpacing.sectionMedium),
                  ],
                  Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: booking.favoritesFirst
                            ? colors.accent.withValues(alpha: 0.35)
                            : colors.border.withValues(alpha: 0.85),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.text.withValues(alpha: 0.035),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: booking.favoritesFirst
                                ? colors.accent.withValues(alpha: 0.12)
                                : colors.bgAlt.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            color: booking.favoritesFirst
                                ? colors.accent
                                : colors.textMid,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: HeyCabySpacing.component),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preferences (optional)',
                                style: typo.titleSmall.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Favorite drivers first',
                                style: typo.bodySmall.copyWith(
                                  color: colors.textSoft,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: booking.favoritesFirst,
                          onChanged: (v) {
                            HapticService.lightTap();
                            ref
                                .read(bookingProvider.notifier)
                                .setFavoritesFirst(v);
                          },
                          activeTrackColor: colors.accent,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: HeyCabySpacing.componentSmall),
                  Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: booking.petFriendly
                            ? colors.accent.withValues(alpha: 0.35)
                            : colors.border.withValues(alpha: 0.85),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.text.withValues(alpha: 0.035),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: booking.petFriendly
                                ? colors.accent.withValues(alpha: 0.12)
                                : colors.bgAlt.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.pets_rounded,
                            color: booking.petFriendly
                                ? colors.accent
                                : colors.textMid,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: HeyCabySpacing.component),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pet-friendly ride',
                                style: typo.titleSmall.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.petFriendlyDesc,
                                style: typo.bodySmall.copyWith(
                                  color: colors.textSoft,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: booking.petFriendly,
                          onChanged: (v) {
                            HapticService.lightTap();
                            ref.read(bookingProvider.notifier).setPetFriendly(v);
                          },
                          activeTrackColor: colors.accent,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: HeyCabySpacing.componentSmall),
                  Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: booking.returnTripFareEstimatesEnabled && hasRoute
                            ? colors.accent.withValues(alpha: 0.35)
                            : colors.border.withValues(alpha: 0.85),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.text.withValues(alpha: 0.035),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: booking.returnTripFareEstimatesEnabled && hasRoute
                                ? colors.accent.withValues(alpha: 0.12)
                                : colors.bgAlt.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.u_turn_left_rounded,
                            color: booking.returnTripFareEstimatesEnabled && hasRoute
                                ? colors.accent
                                : colors.textMid,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: HeyCabySpacing.component),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.returnTripFareEstimatesTitle,
                                style: typo.titleSmall.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasRoute
                                    ? l10n.returnTripFareEstimatesSubtitle
                                    : l10n.returnTripFareEstimatesRequiresRoute,
                                style: typo.bodySmall.copyWith(
                                  color: colors.textSoft,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: hasRoute && booking.returnTripFareEstimatesEnabled,
                          onChanged: hasRoute
                              ? (v) {
                                  HapticService.lightTap();
                                  ref
                                      .read(bookingProvider.notifier)
                                      .setReturnTripFareEstimatesEnabled(v);
                                  setState(() {
                                    _selectedDriverId = null;
                                    _selectedDriverFare = null;
                                    _postToAll = false;
                                  });
                                }
                              : null,
                          activeTrackColor: colors.accent,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: HeyCabySpacing.sectionMedium),
                  if (_selectedFromIdentityPreferred &&
                      _selectedCategory != null &&
                      !_showInvalidPreferredBanner &&
                      !_showSupplyFallbackBanner)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: HeyCabySpacing.componentSmall,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          padding: EdgeInsetsDirectional.symmetric(
                            horizontal: HeyCabySpacing.componentSmall,
                            vertical: HeyCabySpacing.element,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accentL,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            l10n.bookingUsualVehicleChip(
                              _vehicleLine(_selectedCategory!, l10n),
                            ),
                            style: typo.labelMedium.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Text(
                    l10n.vehicleSupplyEstimatesNote,
                    style: typo.bodySmall.copyWith(color: colors.textSoft),
                  ),
                ],
              ),
            ),

            // ── Footer ─────────────────────────────────────────────────────
            Container(
              padding: EdgeInsetsDirectional.fromSTEB(
                HeyCabySpacing.screenEdge,
                HeyCabySpacing.component,
                HeyCabySpacing.screenEdge,
                math.max(HeyCabySpacing.screenEdge, mq.padding.bottom),
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: colors.border.withValues(alpha: 0.65),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.text.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: PrimaryCancelRow(
                primaryLabel: _nextLabel(l10n),
                onPrimary: !canProceed
                    ? null
                    : () async {
                        final notifier = ref.read(bookingProvider.notifier);
                        final pet = ref.read(bookingProvider).petFriendly;
                        if (hasEstimateRows && _smartSelection != null) {
                          final keys = _smartSelection!.toList()
                            ..sort((a, b) {
                              final ia = estimates.indexWhere((e) => e.categoryKey == a);
                              final ib = estimates.indexWhere((e) => e.categoryKey == b);
                              return ia.compareTo(ib);
                            });
                          notifier.applyVehicleSelection(keys, petFriendly: pet);
                          final prices = estimates
                              .where((e) => _smartSelection!.contains(e.categoryKey))
                              .map((e) => e.priceEuro)
                              .toList()
                            ..sort();
                          if (prices.length == 1) {
                            notifier.setTripPriceBand(
                              minEuro: prices.first,
                              maxEuro: prices.first,
                            );
                          } else if (prices.isNotEmpty) {
                            notifier.setTripPriceBand(
                              minEuro: prices.first,
                              maxEuro: prices.last,
                            );
                          }
                          notifier.clearSelectedDriver();
                          await ref
                              .read(riderIdentityProvider.notifier)
                              .savePreferredVehicle(
                                keys.first,
                                petFriendly: pet,
                              );
                        } else {
                          notifier.setTripPriceBand(minEuro: null, maxEuro: null);
                          notifier.setVehicleCategory(
                            _selectedCategory!.storageKey,
                            petFriendly: pet,
                          );
                          await ref
                              .read(riderIdentityProvider.notifier)
                              .savePreferredVehicle(
                                _selectedCategory!.storageKey,
                                petFriendly: pet,
                              );
                          if (_selectedDriverId != null &&
                              _selectedDriverFare != null) {
                            notifier.setSelectedDriver(
                                _selectedDriverId!, _selectedDriverFare!);
                          } else {
                            notifier.clearSelectedDriver();
                          }
                        }
                        if (!context.mounted) return;
                        final next = BookingFlowNavigation.routeAfterVehicleComplete(
                          ref.read(bookingProvider),
                        );
                        final backToSummary = widget.returnToSummaryAfterSave;
                        if (backToSummary) {
                          if (next == '/summary') {
                            context.go('/summary');
                          } else if (next == '/payment') {
                            context.push(
                              '/payment',
                              extra: kBookingReturnToSummaryExtra,
                            );
                          } else {
                            context.push(next);
                          }
                        } else {
                          context.push(next);
                        }
                      },
                colors: colors,
                typography: typo,
                onCancel: () async {
                  final shouldCancel = await showCancelBookingDialog(
                    context,
                    colors: colors,
                    typography: typo,
                  );
                  if (!context.mounted || !shouldCancel) return;
                  context.go('/home');
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
