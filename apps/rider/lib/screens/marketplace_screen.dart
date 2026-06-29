import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/booking_provider.dart';
import '../providers/marketplace_pricing_provider.dart';
import '../services/booking_flow_navigation.dart';
import '../widgets/address_search_modal.dart';
import '../widgets/marketplace/marketplace_screen_header.dart';
import '../widgets/marketplace/marketplace_driver_scope_picker.dart';
import '../widgets/marketplace/marketplace_offer_footer.dart';
import '../widgets/marketplace/marketplace_offer_price_panel.dart';
import '../widgets/marketplace/marketplace_offer_route_card.dart';
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
    ref.read(bookingProvider.notifier).setMarketplaceBidEuro(_bidAmount);
    ref.read(bookingProvider.notifier).setMarketplace();
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
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
                children: [
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
                  const SizedBox(height: 16),
                  MarketplaceOfferPricePanel(
                    bidAmount: _bidAmount,
                    hasAddresses: hasAddresses,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    onBidChanged: (v) => setState(() => _bidAmount = v),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () =>
                          setState(() => _showDriverScope = !_showDriverScope),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.marketplaceDriverScopeTitle,
                              style: typo.labelLarge.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(
                              _showDriverScope
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: colors.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_showDriverScope)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
              onClose: _close,
            ),
          ],
        ),
      ),
    );
  }
}
