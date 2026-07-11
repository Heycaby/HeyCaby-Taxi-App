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
import '../services/booking_flow_navigation.dart';
import '../services/nearby_supply_service.dart';
import '../widgets/booking/booking_flow_screen_header.dart';
import '../widgets/primary_cancel_row.dart';

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
  static const _visibleCategories = <RiderVehicleCategory>[
    RiderVehicleCategory.standard,
    RiderVehicleCategory.comfort,
    RiderVehicleCategory.taxibus,
    RiderVehicleCategory.wheelchair,
  ];

  static const _maxSelectedCategories = 3;

  final List<RiderVehicleCategory> _selectedCategories = [];

  bool _seededFromBookingVehicle = false;
  bool _categoryManuallyTouched = false;
  bool _supplyFallbackScheduled = false;
  bool _showInvalidPreferredBanner = false;
  bool _showSupplyFallbackBanner = false;
  bool _selectedFromIdentityPreferred = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

    if (booking.vehicleCategories.isNotEmpty) {
      final fromBooking = booking.vehicleCategories
          .map(RiderVehicleCategory.tryParse)
          .whereType<RiderVehicleCategory>()
          .where(_visibleCategories.contains)
          .take(_maxSelectedCategories)
          .toList();
      if (fromBooking.isNotEmpty) {
        setState(() {
          _seededFromBookingVehicle = true;
          _selectedCategories
            ..clear()
            ..addAll(fromBooking);
          _showInvalidPreferredBanner = booking.vehicleCategories.any(
            (key) =>
                RiderVehicleCategory.tryParse(key) == null ||
                !_visibleCategories
                    .contains(RiderVehicleCategory.tryParse(key)),
          );
        });
        return;
      }
    }

    if (booking.vehicleCategory != null &&
        booking.vehicleCategory!.trim().isNotEmpty) {
      final c = RiderVehicleCategory.tryParse(booking.vehicleCategory);
      if (c != null) {
        setState(() {
          _seededFromBookingVehicle = true;
          _selectedCategories
            ..clear()
            ..add(
              _visibleCategories.contains(c)
                  ? c
                  : RiderVehicleCategory.standard,
            );
          _showInvalidPreferredBanner = !_visibleCategories.contains(c);
        });
      }
      return;
    }
    final identity = await ref.read(riderIdentityProvider.future);
    if (!mounted) return;
    final raw = identity.preferredVehicleCategory?.trim();
    if (raw == null || raw.isEmpty) {
      if (_selectedCategories.isEmpty) {
        setState(() => _selectedCategories.add(RiderVehicleCategory.standard));
      }
      return;
    }

    final c = RiderVehicleCategory.tryParse(raw);
    if (c == null) {
      if (identity.preferredPetFriendly != null) {
        ref
            .read(bookingProvider.notifier)
            .setPetFriendly(identity.preferredPetFriendly!);
      }
      setState(() {
        _selectedCategories
          ..clear()
          ..add(RiderVehicleCategory.standard);
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
      _selectedCategories
        ..clear()
        ..add(
          _visibleCategories.contains(c) ? c : RiderVehicleCategory.standard,
        );
      _showInvalidPreferredBanner = !_visibleCategories.contains(c);
    });
  }

  static CategorySupplySnapshot _snapFor(
    Map<RiderVehicleCategory, CategorySupplySnapshot>? data,
    RiderVehicleCategory c,
  ) {
    if (data == null) return CategorySupplySnapshot.empty(c);
    return data[c] ?? CategorySupplySnapshot.empty(c);
  }

  String _selectedCategoriesLabel(AppLocalizations l10n) {
    return _selectedCategories
        .map((c) => _vehicleLine(c, l10n))
        .join(' · ');
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
        _selectedCategories.isEmpty) {
      return;
    }
    final id = ref.read(riderIdentityProvider).valueOrNull;
    final preferred =
        RiderVehicleCategory.tryParse(id?.preferredVehicleCategory);
    if (preferred == null || !_selectedCategories.contains(preferred)) return;

    final snap =
        supplyMap[preferred] ?? CategorySupplySnapshot.empty(preferred);
    if (snap.driverCount > 0) return;

    RiderVehicleCategory? replacement;
    for (final cat in _visibleCategories) {
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
        _selectedCategories
          ..clear()
          ..add(picked);
        _showSupplyFallbackBanner = true;
      });
    });
  }

  bool _isCategorySelectable(
    RiderVehicleCategory category,
    Map<RiderVehicleCategory, CategorySupplySnapshot>? supplyMap,
    bool supplyLoading,
  ) {
    if (supplyLoading || supplyMap == null) return true;
    final count = _snapFor(supplyMap, category).driverCount;
    if (count > 0) return true;
    final anyNearby = _visibleCategories.any(
      (c) => _snapFor(supplyMap, c).driverCount > 0,
    );
    return !anyNearby;
  }

  void _toggleCategory(
    RiderVehicleCategory category, {
    required bool selectable,
    required AppLocalizations l10n,
  }) {
    if (!selectable && !_selectedCategories.contains(category)) return;

    _categoryManuallyTouched = true;
    if (_selectedCategories.contains(category)) {
      if (_selectedCategories.length <= 1) return;
      setState(() => _selectedCategories.remove(category));
      return;
    }
    if (_selectedCategories.length >= _maxSelectedCategories) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(l10n.vehicleMaxCategoriesSelected),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _selectedCategories.add(category));
  }

  List<NearbyDriverOffer> _offersForSelectedCategories(
    Map<RiderVehicleCategory, CategorySupplySnapshot>? supplyMap,
  ) {
    if (_selectedCategories.isEmpty) return const [];
    final offers = <NearbyDriverOffer>[];
    final seen = <String>{};
    for (final category in _selectedCategories) {
      for (final offer in _snapFor(supplyMap, category).drivers) {
        if (seen.add(offer.driverId)) {
          offers.add(offer);
        }
      }
    }
    return offers;
  }

  String _nextLabel(AppLocalizations l10n) => l10n.next;

  String _fmtEuro(double value) {
    final whole = value == value.roundToDouble();
    return whole
        ? '€${value.toStringAsFixed(0)}'
        : '€${value.toStringAsFixed(1)}';
  }

  String _priceRangeText(List<NearbyDriverOffer> offers) {
    if (offers.isEmpty) return '—';
    final prices = offers.map((e) => e.estimatedFareEuro).toList()..sort();
    final min = prices.first;
    final max = prices.last;
    if (min == max) return _fmtEuro(min);
    return '${_fmtEuro(min)} – ${_fmtEuro(max)}';
  }

  String _pickupRangeText(List<NearbyDriverOffer> offers) {
    if (offers.isEmpty) return '—';
    final nearest =
        offers.map((e) => e.distanceKmPickup).reduce((a, b) => a < b ? a : b);
    final min = math.max(3, (nearest * 3.5).round() + 2);
    final max = min + 3;
    return '$min–$max min';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);
    final hasRoute = booking.pickup != null && booking.destination != null;
    final canProceed = _selectedCategories.isNotEmpty;

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
    final selectedOffers = _offersForSelectedCategories(supplyMap);
    final supplyLoading = supplyAsync.isLoading;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.vehicleCategoryTitle,
              icon: Icons.directions_car_rounded,
              onBack: () => context.pop(),
            ),
            if (booking.pickup == null)
              Material(
                color: colors.warning.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.componentSmall,
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.element,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colors.warning, size: 22),
                      const SizedBox(width: HeyCabySpacing.buttonHorizontal),
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
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.componentSmall,
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.element,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colors.warning, size: 22),
                      const SizedBox(width: HeyCabySpacing.buttonHorizontal),
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
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.componentSmall,
                    HeyCabySpacing.screenEdge,
                    HeyCabySpacing.element,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colors.warning, size: 22),
                      const SizedBox(width: HeyCabySpacing.buttonHorizontal),
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
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 2,
                      bottom: HeyCabySpacing.componentSmall,
                    ),
                    child: Text(
                      l10n.vehicleSelectUpToThree,
                      style: typo.bodyLarge.copyWith(
                        color: colors.textMid,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _MarketSupplySummaryCard(
                    driverCount: selectedOffers.length,
                    priceRange: _priceRangeText(selectedOffers),
                    pickupRange: _pickupRangeText(selectedOffers),
                    colors: colors,
                    typography: typo,
                    isLoading: supplyAsync.isLoading,
                  ),
                  const SizedBox(height: HeyCabySpacing.component),
                  ..._visibleCategories.map((category) {
                    final snap = _snapFor(supplyMap, category);
                    final selected = _selectedCategories.contains(category);
                    final selectable = _isCategorySelectable(
                      category,
                      supplyMap,
                      supplyLoading,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: HeyCabySpacing.componentSmall,
                      ),
                      child: _VehicleNeedCard(
                        selected: selected,
                        enabled: selectable || selected,
                        icon: switch (category) {
                          RiderVehicleCategory.standard =>
                            Icons.local_taxi_outlined,
                          RiderVehicleCategory.comfort =>
                            Icons.drive_eta_rounded,
                          RiderVehicleCategory.taxibus =>
                            Icons.airport_shuttle_outlined,
                          RiderVehicleCategory.wheelchair =>
                            Icons.accessible_forward_rounded,
                        },
                        title: _vehicleLine(category, l10n),
                        subtitle: switch (category) {
                          RiderVehicleCategory.standard =>
                            l10n.vehicleStandardDesc,
                          RiderVehicleCategory.comfort =>
                            l10n.vehicleComfortDesc,
                          RiderVehicleCategory.taxibus =>
                            l10n.vehicleTaxibusDesc,
                          RiderVehicleCategory.wheelchair =>
                            l10n.vehicleWheelchairDesc,
                        },
                        supplyLabel: l10n.vehicleSupplyNearbyCount(snap.driverCount),
                        colors: colors,
                        typography: typo,
                        onTap: () => _toggleCategory(
                          category,
                          selectable: selectable,
                          l10n: l10n,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: HeyCabySpacing.sectionMedium - HeyCabySpacing.componentSmall),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colors.border),
                        boxShadow: [
                          BoxShadow(
                            color: colors.text.withValues(alpha: 0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                            spreadRadius: -6,
                          ),
                        ],
                      ),
                      child: ExpansionTile(
                        tilePadding:
                            const EdgeInsetsDirectional.fromSTEB(18, 8, 14, 8),
                        childrenPadding:
                            const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colors.accentL.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: colors.accent,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          l10n.vehicleOptionalPreferencesTitle,
                          style: typo.titleSmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          l10n.vehicleOptionalPreferencesSubtitle,
                          style:
                              typo.bodySmall.copyWith(color: colors.textSoft),
                        ),
                        children: [
                          _PreferenceSwitchRow(
                            icon: Icons.favorite_rounded,
                            title: l10n.favoriteDriversFirstTripDetail,
                            subtitle: l10n.myDriversHomeSubtitle,
                            value: booking.favoritesFirst,
                            colors: colors,
                            typography: typo,
                            onChanged: (v) {
                              HapticService.lightTap();
                              ref
                                  .read(bookingProvider.notifier)
                                  .setFavoritesFirst(v);
                            },
                          ),
                          _PreferenceSwitchRow(
                            icon: Icons.pets_rounded,
                            title: l10n.vehiclePetsWelcome,
                            subtitle: l10n.petFriendlyDesc,
                            value: booking.petFriendly,
                            colors: colors,
                            typography: typo,
                            onChanged: (v) {
                              HapticService.lightTap();
                              ref
                                  .read(bookingProvider.notifier)
                                  .setPetFriendly(v);
                            },
                          ),
                          _PreferenceSwitchRow(
                            icon: Icons.u_turn_left_rounded,
                            title: l10n.returnTripFareEstimatesTitle,
                            subtitle: hasRoute
                                ? l10n.returnTripFareEstimatesSubtitle
                                : l10n.returnTripFareEstimatesRequiresRoute,
                            value: hasRoute &&
                                booking.returnTripFareEstimatesEnabled,
                            enabled: hasRoute,
                            colors: colors,
                            typography: typo,
                            onChanged: (v) {
                              HapticService.lightTap();
                              ref
                                  .read(bookingProvider.notifier)
                                  .setReturnTripFareEstimatesEnabled(v);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: HeyCabySpacing.sectionMedium),
                  Container(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: colors.border.withValues(alpha: 0.85)),
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
                            color: colors.accentL.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: colors.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: HeyCabySpacing.component),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.vehicleIndependentPricingTitle,
                                style: typo.titleSmall.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.vehicleIndependentPricingBody,
                                style: typo.bodySmall.copyWith(
                                  color: colors.textSoft,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedFromIdentityPreferred &&
                      _selectedCategories.isNotEmpty &&
                      !_showInvalidPreferredBanner &&
                      !_showSupplyFallbackBanner)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: HeyCabySpacing.componentSmall,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: HeyCabySpacing.componentSmall,
                            vertical: HeyCabySpacing.element,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accentL,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: colors.accent.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            l10n.bookingUsualVehicleChip(
                              _selectedCategoriesLabel(l10n),
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
                        final offers = _offersForSelectedCategories(supplyMap);
                        final prices = offers
                            .map((e) => e.estimatedFareEuro)
                            .toList()
                          ..sort();
                        if (prices.isEmpty) {
                          notifier.setTripPriceBand(
                              minEuro: null, maxEuro: null);
                        } else {
                          notifier.setTripPriceBand(
                            minEuro: prices.first,
                            maxEuro: prices.last,
                          );
                        }
                        final keys = _selectedCategories
                            .map((c) => c.storageKey)
                            .toList();
                        notifier.applyVehicleSelection(
                          keys,
                          petFriendly: pet,
                        );
                        notifier.clearSelectedDriver();
                        await ref
                            .read(riderIdentityProvider.notifier)
                            .savePreferredVehicle(
                              keys.first,
                              petFriendly: pet,
                            );
                        if (!context.mounted) return;
                        final next =
                            BookingFlowNavigation.routeAfterVehicleComplete(
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
    );
  }
}

class _MarketSupplySummaryCard extends StatelessWidget {
  const _MarketSupplySummaryCard({
    required this.driverCount,
    required this.priceRange,
    required this.pickupRange,
    required this.colors,
    required this.typography,
    required this.isLoading,
  });

  final int driverCount;
  final String priceRange;
  final String pickupRange;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: colors.card,
        border: Border.all(color: colors.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.055),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.accentL.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: colors.accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.vehicleNearbyMarketTitle,
                      style: typography.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isLoading
                          ? l10n.vehicleNearbyMarketChecking
                          : l10n.vehicleNearbyDriverCount(driverCount),
                      style: typography.bodySmall.copyWith(
                        color: colors.textSoft,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MarketMetric(
                  label: l10n.vehicleFareRangeLabel,
                  value: priceRange,
                  colors: colors,
                  typography: typography,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MarketMetric(
                  label: l10n.vehiclePickupRangeLabel,
                  value: pickupRange,
                  colors: colors,
                  typography: typography,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketMetric extends StatelessWidget {
  const _MarketMetric({
    required this.label,
    required this.value,
    required this.colors,
    required this.typography,
  });

  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.bgAlt.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: typography.labelMedium.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: typography.titleLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleNeedCard extends StatelessWidget {
  const _VehicleNeedCard({
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.supplyLabel,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final String supplyLabel;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.48;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: opacity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                selected ? colors.accent : colors.border.withValues(alpha: 0.8),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? colors.accent.withValues(alpha: 0.16)
                  : colors.text.withValues(alpha: 0.035),
              blurRadius: selected ? 22 : 16,
              offset: const Offset(0, 8),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 15, 16, 15),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.accentL.withValues(alpha: 0.95)
                          : colors.bgAlt.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icon,
                      color: selected ? colors.accent : colors.textMid,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: typography.titleMedium.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: typography.bodySmall.copyWith(
                            color: colors.textSoft,
                            height: 1.28,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          supplyLabel,
                          style: typography.labelMedium.copyWith(
                            color: selected ? colors.accent : colors.textMid,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? colors.accent : Colors.transparent,
                      border: Border.all(
                        color: selected ? colors.accent : colors.border,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded,
                            color: colors.onAccent, size: 18)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceSwitchRow extends StatelessWidget {
  const _PreferenceSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.colors,
    required this.typography,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = enabled && value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active
                  ? colors.accentL.withValues(alpha: 0.85)
                  : colors.bgAlt.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: active ? colors.accent : colors.textMid,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typography.titleSmall.copyWith(
                    color: enabled ? colors.text : colors.textSoft,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: typography.bodySmall.copyWith(
                    color: colors.textSoft,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: colors.accent,
          ),
        ],
      ),
    );
  }
}
