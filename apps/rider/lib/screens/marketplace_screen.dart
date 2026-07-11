import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/booking_provider.dart';
import '../providers/marketplace_pricing_provider.dart';
import '../services/booking_flow_navigation.dart';
import '../widgets/address_search_modal.dart';
import '../widgets/marketplace/marketplace_driver_scope_picker.dart';
import '../widgets/marketplace/marketplace_intro_strip.dart';
import '../widgets/marketplace/marketplace_offer_footer.dart';
import '../widgets/marketplace/marketplace_offer_price_panel.dart';
import '../widgets/marketplace/marketplace_offer_route_card.dart';
import '../widgets/marketplace/marketplace_screen_header.dart';
import '../widgets/marketplace/marketplace_step_progress.dart';
import '../widgets/marketplace/taxi_terug_candidates_section.dart';
import '../widgets/marketplace/taxi_terug_wait_tolerance_section.dart';
import 'location_required_screen.dart';

/// Marketplace — name your price; same Supabase booking + auction backend.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  int _bidAmount = 50;
  bool _isSubmitting = false;
  bool _showDriverScope = false;
  bool _bidSyncedFromRoute = false;
  bool _delayedPickupAcknowledged = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(bookingProvider).marketplaceBidEuro;
    if (existing != null && existing > 0) {
      _bidAmount = existing;
    }
  }

  void _syncBidFromReference(double? refFare) {
    if (_bidSyncedFromRoute || refFare == null || refFare <= 0) return;
    final booking = ref.read(bookingProvider);
    if (booking.pickup == null || booking.destination == null) return;
    if (booking.marketplaceBidEuro != null) {
      _bidSyncedFromRoute = true;
      return;
    }
    _bidSyncedFromRoute = true;
    setState(() => _bidAmount = suggestedMarketplaceBid(refFare));
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
      if (type == AddressType.destination) {
        _bidSyncedFromRoute = false;
      }
    }
  }

  Future<void> _submitOffer() async {
    HapticService.mediumTap();
    final currentMode = ref.read(bookingProvider).mode;
    if (currentMode == BookingMode.terug && !_delayedPickupAcknowledged) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).taxiTerugConfirmDelayedPickup),
        ),
      );
      return;
    }
    ref.read(bookingProvider.notifier).setMarketplaceBidEuro(_bidAmount);
    if (currentMode == BookingMode.terug) {
      ref.read(bookingProvider.notifier).setTaxiTerug();
    } else {
      ref.read(bookingProvider.notifier).setMarketplace();
    }
    setState(() => _isSubmitting = true);
    try {
      await BookingFlowNavigation.prefillBookingFromIdentity(ref);
      if (!mounted) return;
      final booking = ref.read(bookingProvider);
      final next = BookingFlowNavigation.routeAfterMarketplacePost(booking);
      context.push(next);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);
    final isTaxiTerug = booking.mode == BookingMode.terug;
    final hasAddresses = booking.pickup != null && booking.destination != null;
    final refFareAsync = ref.watch(marketplaceReferenceFareEuroProvider);

    refFareAsync.whenData(_syncBidFromReference);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MarketplaceScreenHeader(
              colors: colors,
              typo: typo,
              l10n: l10n,
              onClose: _close,
              isTaxiTerug: isTaxiTerug,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
                children: [
                  MarketplaceIntroStrip(
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    isTaxiTerug: isTaxiTerug,
                  ),
                  const SizedBox(height: 16),
                  MarketplaceStepProgress(
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    routeDone: hasAddresses,
                    priceDone: hasAddresses && _bidAmount > 0,
                  ),
                  const SizedBox(height: 20),
                  MarketplaceOfferRouteCard(
                    booking: booking,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    onPickup: () => _openAddressSearch(AddressType.pickup),
                    onDestination: () =>
                        _openAddressSearch(AddressType.destination),
                    onClearPickup: () =>
                        ref.read(bookingProvider.notifier).clearPickup(),
                    onClearDestination: () =>
                        ref.read(bookingProvider.notifier).clearDestination(),
                  ),
                  if (isTaxiTerug && hasAddresses) ...[
                    const SizedBox(height: 20),
                    TaxiTerugWaitToleranceSection(
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                    ),
                    const SizedBox(height: 16),
                    TaxiTerugCandidatesSection(
                      colors: colors,
                      typo: typo,
                      l10n: l10n,
                      onSuggestedBid: (v) {
                        if (_bidSyncedFromRoute && _bidAmount == v) return;
                        setState(() {
                          _bidAmount = v;
                          _bidSyncedFromRoute = true;
                        });
                      },
                    ),
                  ],
                  if (isTaxiTerug && hasAddresses) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _delayedPickupAcknowledged,
                      onChanged: (v) => setState(
                        () => _delayedPickupAcknowledged = v ?? false,
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        l10n.taxiTerugDelayedPickupAck,
                        style: typo.bodySmall.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      activeColor: colors.accent,
                    ),
                  ],
                  const SizedBox(height: 12),
                  MarketplaceOfferPricePanel(
                    bidAmount: _bidAmount,
                    hasAddresses: hasAddresses,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    isTaxiTerug: isTaxiTerug,
                    onBidChanged: (v) => setState(() => _bidAmount = v),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _showDriverScope = !_showDriverScope),
                      icon: Icon(
                        _showDriverScope
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                      ),
                      label: Text(l10n.marketplaceDriverScopeTitle),
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textMid,
                        textStyle: typo.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_showDriverScope)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MarketplaceDriverScopePicker(
                        colors: colors,
                        typo: typo,
                        l10n: l10n,
                      ),
                    ),
                ],
              ),
            ),
            MarketplaceOfferFooter(
              isSubmitting: _isSubmitting,
              hasAddresses: hasAddresses,
              colors: colors,
              typo: typo,
              l10n: l10n,
              onTap: _submitOffer,
            ),
          ],
        ),
      ),
    );
  }
}
