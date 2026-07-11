import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/taxi_terug_hot_destination.dart';
import '../models/taxi_terug_candidate.dart';
import '../providers/booking_provider.dart';
import '../providers/marketplace_offers_provider.dart';
import '../providers/marketplace_pricing_provider.dart';
import '../providers/taxi_terug_candidates_provider.dart';
import '../providers/taxi_terug_hot_destinations_provider.dart';
import '../services/sound_service.dart';
import '../widgets/address_search_modal.dart';
import 'location_required_screen.dart';

/// Taxi Terug — browse taxis already heading your way; post via bottom FAB.
class TaxiTerugScreen extends ConsumerStatefulWidget {
  const TaxiTerugScreen({super.key});

  @override
  ConsumerState<TaxiTerugScreen> createState() => _TaxiTerugScreenState();
}

class _TaxiTerugScreenState extends ConsumerState<TaxiTerugScreen> {
  int _bidAmount = 45;
  bool _isSubmitting = false;
  RealtimeChannel? _driversChannel;
  RealtimeChannel? _locationsChannel;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(bookingProvider).marketplaceBidEuro;
    if (existing != null && existing > 0) {
      _bidAmount = existing;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingProvider.notifier).setTaxiTerug();
      _subscribeToDriverChanges();
      _startPeriodicRefresh();
    });
  }

  void _subscribeToDriverChanges() {
    _driversChannel = HeyCabySupabase.client
        .channel('taxi-terug-drivers')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drivers',
          callback: (_) {
            ref.invalidate(taxiTerugCandidatesProvider);
            ref.invalidate(taxiTerugHotDestinationsProvider);
          },
        )
        .subscribe();

    _locationsChannel = HeyCabySupabase.client
        .channel('taxi-terug-locations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_locations',
          callback: (_) {
            ref.invalidate(taxiTerugCandidatesProvider);
            ref.invalidate(taxiTerugHotDestinationsProvider);
          },
        )
        .subscribe();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) {
          ref.invalidate(taxiTerugCandidatesProvider);
          ref.invalidate(taxiTerugHotDestinationsProvider);
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_driversChannel != null) {
      HeyCabySupabase.client.removeChannel(_driversChannel!);
    }
    if (_locationsChannel != null) {
      HeyCabySupabase.client.removeChannel(_locationsChannel!);
    }
    super.dispose();
  }

  Future<void> _openAddressSearch(AddressType type) async {
    final ok = await ensureLocationForBooking(context: context, ref: ref);
    if (!ok || !mounted) return;
    final result = await showAddressSearchModal(context, ref, type);
    if (result != null) {
      if (type == AddressType.pickup) {
        ref.read(bookingProvider.notifier).setPickup(result);
      } else {
        ref.read(bookingProvider.notifier).setDestination(result);
      }
    }
  }

  Future<void> _submitRequest() async {
    HapticService.mediumTap();
    final booking = ref.read(bookingProvider);
    if (booking.pickup == null || booking.destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).taxiTerugScreenSetRoute),
        ),
      );
      return;
    }

    if ((booking.pickupContactName ?? '').trim().isEmpty) {
      final identity = await ref.read(riderIdentityProvider.future);
      if (!mounted) return;
      ref.read(bookingProvider.notifier).mergeFromRiderIdentity(identity);
    }

    ref.read(bookingProvider.notifier).setMarketplaceBidEuro(_bidAmount);
    setState(() => _isSubmitting = true);

    final ok = await bootstrapMarketplaceRide(ref);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).taxiTerugScreenLoadError),
        ),
      );
      return;
    }

    await SoundService().playBookingCreated();
    if (mounted) context.go('/home');
  }

  void _bookCandidate(TaxiTerugCandidate candidate) {
    HapticService.mediumTap();
    final booking = ref.read(bookingProvider);
    if (booking.pickup == null || booking.destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).taxiTerugScreenSetRoute),
        ),
      );
      return;
    }
    final suggested = candidate.estimatedFareMin.ceil().clamp(15, 250);
    ref.read(bookingProvider.notifier).setMarketplaceBidEuro(suggested);
    context.push('/marketplace');
  }

  Future<void> _openPostRequestSheet() async {
    HapticService.lightTap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PostRequestSheet(
        bidAmount: _bidAmount,
        isSubmitting: _isSubmitting,
        onBidChanged: (v) => setState(() => _bidAmount = v),
        onSubmit: () async {
          await _submitRequest();
          if (sheetContext.mounted && Navigator.of(sheetContext).canPop()) {
            Navigator.of(sheetContext).pop();
          }
        },
      ),
    );
  }

  Future<void> _refreshCandidates() async {
    ref.invalidate(taxiTerugCandidatesProvider);
    ref.invalidate(taxiTerugHotDestinationsProvider);
    try {
      await ref.read(taxiTerugCandidatesProvider.future);
    } catch (_) {}
  }

  void _selectHotDestination(TaxiTerugHotDestination destination) {
    HapticService.lightTap();
    ref.read(bookingProvider.notifier).setDestination(destination.toAddressResult());
    ref.invalidate(taxiTerugCandidatesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? 0 : 4),
        child: FloatingActionButton.extended(
          onPressed: _isSubmitting ? null : _openPostRequestSheet,
          elevation: 2,
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            l10n.taxiTerugScreenPostButton,
            style: typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              colors: colors,
              typo: typo,
              l10n: l10n,
              onBack: () => context.pop(),
            ),
            _PickupBar(
              colors: colors,
              typo: typo,
              l10n: l10n,
              pickupLabel: booking.pickup?.displayName ??
                  l10n.taxiTerugScreenPickupPlaceholder,
              hasPickup: booking.pickup != null,
              onPickupTap: () => _openAddressSearch(AddressType.pickup),
            ),
            _HotCityPills(
              colors: colors,
              typo: typo,
              l10n: l10n,
              selectedCity: booking.destination?.city ??
                  booking.destination?.displayName,
              onCitySelected: _selectHotDestination,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 6),
              child: Text(
                l10n.taxiTerugScreenTabAvailable,
                style: typo.titleMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Expanded(
              child: _AvailableBody(
                colors: colors,
                typo: typo,
                l10n: l10n,
                fabClearance: 88 + bottomInset,
                onBook: _bookCandidate,
                onRefresh: _refreshCandidates,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onBack,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.text),
            onPressed: onBack,
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.keyboard_return_rounded,
              color: colors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.taxiTerugScreenTitle,
                  style: typo.titleLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.taxiTerugScreenSubtitle,
                  style: typo.bodySmall.copyWith(
                    color: colors.textMid,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupBar extends StatelessWidget {
  const _PickupBar({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.pickupLabel,
    required this.hasPickup,
    required this.onPickupTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String pickupLabel;
  final bool hasPickup;
  final VoidCallback onPickupTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
      child: Material(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border.withValues(alpha: 0.55)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPickupTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 10, 14),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.taxiTerugScreenPickupPlaceholder,
                        style: typo.labelSmall.copyWith(
                          color: colors.textMid,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pickupLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: typo.bodyMedium.copyWith(
                          color: hasPickup ? colors.text : colors.textSoft,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: colors.textSoft, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HotCityPills extends ConsumerWidget {
  const _HotCityPills({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.selectedCity,
    required this.onCitySelected,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String? selectedCity;
  final ValueChanged<TaxiTerugHotDestination> onCitySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(taxiTerugHotDestinationsProvider);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Text(
              l10n.taxiTerugHotDestinationsTitle,
              style: typo.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Text(
              l10n.taxiTerugHotDestinationsSubtitle,
              style: typo.bodySmall.copyWith(
                color: colors.textMid,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: async.when(
              loading: () => _HotCitySkeleton(colors: colors),
              error: (_, __) => _HotCityRow(
                colors: colors,
                typo: typo,
                destinations: kTaxiTerugNlHotCities,
                selectedCity: selectedCity,
                onCitySelected: onCitySelected,
              ),
              data: (destinations) => _HotCityRow(
                colors: colors,
                typo: typo,
                destinations: destinations,
                selectedCity: selectedCity,
                onCitySelected: onCitySelected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotCitySkeleton extends StatelessWidget {
  const _HotCitySkeleton({required this.colors});

  final HeyCabyColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.only(end: 16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, __) => Container(
        width: 118,
        decoration: BoxDecoration(
          color: colors.border.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _HotCityRow extends StatelessWidget {
  const _HotCityRow({
    required this.colors,
    required this.typo,
    required this.destinations,
    required this.selectedCity,
    required this.onCitySelected,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final List<TaxiTerugHotDestination> destinations;
  final String? selectedCity;
  final ValueChanged<TaxiTerugHotDestination> onCitySelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.only(end: 16),
      itemCount: destinations.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final dest = destinations[index];
        final selected = selectedCity != null &&
            selectedCity!.toLowerCase() == dest.city.toLowerCase();
        final hasDrivers = dest.driverCount > 0;

        return Material(
          color: selected
              ? colors.accent
              : colors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: selected
                  ? colors.accent
                  : colors.border.withValues(alpha: 0.65),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onCitySelected(dest),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 14, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasDrivers) ...[
                    Container(
                      constraints: const BoxConstraints(minWidth: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.onAccent.withValues(alpha: 0.18)
                            : colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${dest.driverCount}',
                        textAlign: TextAlign.center,
                        style: typo.labelSmall.copyWith(
                          color: selected ? colors.onAccent : colors.accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    dest.city,
                    style: typo.labelLarge.copyWith(
                      color: selected
                          ? colors.onAccent
                          : (hasDrivers ? colors.text : colors.textMid),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvailableBody extends ConsumerWidget {
  const _AvailableBody({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.fabClearance,
    required this.onBook,
    required this.onRefresh,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final double fabClearance;
  final ValueChanged<TaxiTerugCandidate> onBook;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider);
    if (booking.pickup == null) {
      return _EmptyState(
        colors: colors,
        typo: typo,
        icon: Icons.my_location_rounded,
        title: l10n.taxiTerugScreenPickupPlaceholder,
        body: l10n.taxiTerugIntroBody,
        fabClearance: fabClearance,
      );
    }

    if (booking.destination == null) {
      return _EmptyState(
        colors: colors,
        typo: typo,
        icon: Icons.location_city_rounded,
        title: l10n.taxiTerugPickCityHint,
        body: l10n.taxiTerugHotDestinationsSubtitle,
        fabClearance: fabClearance,
      );
    }

    final async = ref.watch(taxiTerugCandidatesProvider);

    return async.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: colors.accent,
        ),
      ),
      error: (_, __) => _EmptyState(
        colors: colors,
        typo: typo,
        icon: Icons.cloud_off_rounded,
        title: l10n.taxiTerugScreenLoadError,
        body: l10n.connectionProblem,
        fabClearance: fabClearance,
      ),
      data: (snap) {
        if (!snap.enabled) {
          return _EmptyState(
            colors: colors,
            typo: typo,
            icon: Icons.local_taxi_rounded,
            title: l10n.taxiTerugScreenDisabled,
            body: l10n.taxiTerugScreenNoRidesBody,
            fabHint: l10n.taxiTerugScreenPostConfirmation,
            fabClearance: fabClearance,
          );
        }
        if (snap.candidates.isEmpty) {
          return _EmptyState(
            colors: colors,
            typo: typo,
            icon: Icons.directions_car_rounded,
            title: l10n.taxiTerugScreenNoRides,
            body: l10n.taxiTerugScreenNoRidesBody,
            fabHint: l10n.taxiTerugScreenPostConfirmation,
            fabClearance: fabClearance,
          );
        }
        return _CandidateList(
          colors: colors,
          typo: typo,
          l10n: l10n,
          fabClearance: fabClearance,
          candidates: snap.candidates,
          onBook: onBook,
          onRefresh: onRefresh,
        );
      },
    );
  }
}

class _CandidateList extends StatelessWidget {
  const _CandidateList({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.fabClearance,
    required this.candidates,
    required this.onBook,
    required this.onRefresh,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final double fabClearance;
  final List<TaxiTerugCandidate> candidates;
  final ValueChanged<TaxiTerugCandidate> onBook;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: colors.accent,
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, fabClearance),
        itemCount: candidates.length,
        itemBuilder: (context, index) {
          final c = candidates[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CandidateRouteCard(
              candidate: c,
              colors: colors,
              typo: typo,
              l10n: l10n,
              onBook: () => onBook(c),
            ),
          );
        },
      ),
    );
  }
}

class _CandidateRouteCard extends StatelessWidget {
  const _CandidateRouteCard({
    required this.candidate,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onBook,
  });

  final TaxiTerugCandidate candidate;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final vehicle = candidate.vehicle;
    final heading = candidate.headingTo;
    final fareMin = formatMarketplaceEuro(candidate.estimatedFareMin);
    final fareMax = formatMarketplaceEuro(candidate.estimatedFareMax);
    final fareLabel = candidate.estimatedFareMin == candidate.estimatedFareMax
        ? fareMin
        : l10n.taxiTerugCandidateFareRange(fareMin, fareMax);
    final rating = candidate.driverRating.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                if (heading != null && heading.isNotEmpty)
                  Expanded(
                    child: Text(
                      heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      candidate.driverName,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: colors.success),
                      const SizedBox(width: 2),
                      Text(
                        rating,
                        style: typo.labelSmall.copyWith(
                          color: colors.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.driverName,
                  style: typo.bodyMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (vehicle != null && vehicle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    vehicle,
                    style: typo.bodySmall.copyWith(
                      color: colors.textMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 16, color: colors.accent),
                    const SizedBox(width: 6),
                    if (candidate.inTransit &&
                        candidate.pickupAvailableMin != null &&
                        candidate.pickupAvailableMax != null)
                      Text(
                        l10n.taxiTerugCandidatePickupWindow(
                          candidate.pickupAvailableMin!,
                          candidate.pickupAvailableMax!,
                        ),
                        style: typo.bodySmall.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      Text(
                        l10n.taxiTerugCandidateEta(candidate.pickupEtaMinutes),
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (candidate.inTransit) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.taxiTerugCandidateFinishingRide,
                    style: typo.labelSmall.copyWith(
                      color: colors.textMid,
                      height: 1.3,
                    ),
                  ),
                ],
                if (candidate.hasDepartureTime) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 16, color: colors.accent),
                      const SizedBox(width: 6),
                      Text(
                        l10n.taxiTerugCandidateDepartsAt(
                          TimeOfDay.fromDateTime(candidate.departureTime!)
                              .format(context),
                        ),
                        style: typo.bodySmall.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
                if (candidate.whyMatch != null &&
                    candidate.whyMatch!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.bgAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: colors.textMid),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            candidate.whyMatch!,
                            style: typo.labelSmall.copyWith(
                              color: colors.textMid,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Text(
                  fareLabel,
                  style: typo.titleMedium.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onBook,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.taxiTerugScreenBook),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.title,
    required this.body,
    this.fabHint,
    required this.fabClearance,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String title;
  final String body;
  final String? fabHint;
  final double fabClearance;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(28, 24, 28, fabClearance),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: colors.accent.withValues(alpha: 0.65),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: typo.titleMedium.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: typo.bodyMedium.copyWith(
            color: colors.textMid,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (fabHint != null) ...[
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_downward_rounded,
                  size: 18, color: colors.accent.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fabHint!,
                  textAlign: TextAlign.center,
                  style: typo.labelLarge.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PostRequestSheet extends ConsumerWidget {
  const _PostRequestSheet({
    required this.bidAmount,
    required this.isSubmitting,
    required this.onBidChanged,
    required this.onSubmit,
  });

  final int bidAmount;
  final bool isSubmitting;
  final ValueChanged<int> onBidChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);
    final hasRoute = booking.pickup != null && booking.destination != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Material(
          color: colors.surface,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.border.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    l10n.taxiTerugScreenPostTitle,
                    style: typo.titleLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.taxiTerugScreenPostBody,
                    style: typo.bodyMedium.copyWith(
                      color: colors.textMid,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _RouteRow(
                    colors: colors,
                    typo: typo,
                    icon: Icons.my_location_rounded,
                    label: booking.pickup?.displayName ??
                        l10n.taxiTerugScreenPickupPlaceholder,
                    placeholder: booking.pickup == null,
                    onTap: () async {
                      final ok = await ensureLocationForBooking(
                          context: context, ref: ref);
                      if (!ok || !context.mounted) return;
                      final result = await showAddressSearchModal(
                          context, ref, AddressType.pickup);
                      if (result != null) {
                        ref.read(bookingProvider.notifier).setPickup(result);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _RouteRow(
                    colors: colors,
                    typo: typo,
                    icon: Icons.location_on_rounded,
                    label: booking.destination?.displayName ??
                        l10n.taxiTerugScreenDestinationPlaceholder,
                    placeholder: booking.destination == null,
                    onTap: () async {
                      final ok = await ensureLocationForBooking(
                          context: context, ref: ref);
                      if (!ok || !context.mounted) return;
                      final result = await showAddressSearchModal(
                          context, ref, AddressType.destination);
                      if (result != null) {
                        ref
                            .read(bookingProvider.notifier)
                            .setDestination(result);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.taxiTerugScreenOfferLabel,
                    style: typo.titleSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: bidAmount > 10
                            ? () => onBidChanged(bidAmount - 5)
                            : null,
                        icon: Icon(Icons.remove_circle_outline_rounded,
                            color: colors.accent, size: 32),
                      ),
                      Expanded(
                        child: Text(
                          formatMarketplaceEuro(bidAmount.toDouble()),
                          textAlign: TextAlign.center,
                          style: typo.headingMedium.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: bidAmount < 250
                            ? () => onBidChanged(bidAmount + 5)
                            : null,
                        icon: Icon(Icons.add_circle_outline_rounded,
                            color: colors.accent, size: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!hasRoute)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        l10n.taxiTerugScreenSetRoute,
                        textAlign: TextAlign.center,
                        style: typo.bodySmall.copyWith(color: colors.textMid),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: (isSubmitting || !hasRoute) ? null : onSubmit,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isSubmitting
                            ? l10n.taxiTerugScreenPosting
                            : l10n.taxiTerugScreenPostButton,
                        style:
                            typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.taxiTerugScreenPostConfirmation,
                    textAlign: TextAlign.center,
                    style: typo.bodySmall.copyWith(
                      color: colors.textSoft,
                      height: 1.35,
                    ),
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

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.label,
    required this.placeholder,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final IconData icon;
  final String label;
  final bool placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: placeholder
                ? colors.border.withValues(alpha: 0.4)
                : colors.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: typo.bodyMedium.copyWith(
                  color: placeholder ? colors.textMid : colors.text,
                  fontWeight: placeholder ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textMid, size: 24),
          ],
        ),
      ),
    );
  }
}
