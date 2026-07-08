import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../models/ride_matching_variant.dart';
import '../providers/booking_draft_provider.dart';
import '../providers/booking_provider.dart';
import '../providers/recent_destinations_provider.dart';
import '../providers/ride_request_provider.dart';
import '../providers/saved_trips_provider.dart';
import '../services/booking_draft_storage.dart';
import '../services/booking_flow_navigation.dart';
import 'location_required_screen.dart';
import '../widgets/booking/trip_summary_map_view.dart';
import '../widgets/booking/trip_summary_sheet.dart';
import '../widgets/primary_cancel_row.dart';

class TripSummaryScreen extends ConsumerStatefulWidget {
  const TripSummaryScreen({super.key});

  @override
  ConsumerState<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends ConsumerState<TripSummaryScreen> {
  double _distanceKm = 0;
  int _etaMinutes = 0;
  bool _saveTripForNextTime = false;

  void _onRouteMetrics(double distanceKm, int etaMinutes) {
    if (!mounted) return;
    ref.read(bookingProvider.notifier).setRouteMetrics(
          distanceKm: distanceKm,
          durationMin: etaMinutes,
        );
    setState(() {
      _distanceKm = distanceKm;
      _etaMinutes = etaMinutes;
    });
  }

  void _editAddress(bool isPickup) => context.push(
        '/search',
        extra: BookingSearchRouteArgs(
          returnToSummaryAfterSave: true,
          initialEditTarget: isPickup
              ? BookingAddressEditTarget.pickup
              : BookingAddressEditTarget.destination,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final booking = ref.watch(bookingProvider);
    final screenH = MediaQuery.sizeOf(context).height;

    final hours = _etaMinutes ~/ 60;
    final minutes = _etaMinutes % 60;
    final etaText = hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: TripSummaryMapView(
              height: screenH,
              cameraBottomPadding:
                  screenH * 0.42 + MediaQuery.paddingOf(context).bottom,
              onRouteMetricsChanged: _onRouteMetrics,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: Material(
              color: colors.card.withValues(alpha: 0.92),
              elevation: 2,
              shadowColor: colors.text.withValues(alpha: 0.12),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () async {
                  HapticService.lightTap();
                  final shouldCancel = await showCancelBookingDialog(
                    context,
                    colors: colors,
                    typography: typo,
                  );
                  if (!context.mounted || !shouldCancel) return;
                  ref.read(bookingProvider.notifier).reset();
                  ref.read(rideRequestProvider.notifier).reset();
                  context.go('/home');
                },
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child:
                      Icon(Icons.close_rounded, color: colors.text, size: 22),
                ),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.40,
            minChildSize: 0.28,
            maxChildSize: 0.80,
            snap: true,
            snapSizes: const [0.40, 0.80],
            builder: (context, scrollController) => TripSummarySheet(
              scrollController: scrollController,
              booking: booking,
              colors: colors,
              typo: typo,
              l10n: l10n,
              distanceKm: _distanceKm,
              etaText: etaText,
              isLoading: false,
              onEditAddress: _editAddress,
              onEditPassengerAndRide: () => context.push(
                '/vehicle-category',
                extra: kBookingReturnToSummaryExtra,
              ),
              onEditPayment: () => context.push(
                '/payment',
                extra: kBookingReturnToSummaryExtra,
              ),
              saveTripForNextTime: _saveTripForNextTime,
              onSaveTripForNextTimeChanged: (v) =>
                  setState(() => _saveTripForNextTime = v),
              onSaveForLater: () async {
                await BookingDraftStorage.save(ref.read(bookingProvider));
                ref.invalidate(bookingDraftProvider);
                if (!context.mounted) return;
                context.go('/home');
              },
              onConfirm: () async {
                HapticService.mediumTap();
                if (!mounted) return;
                final bookingNotifier = ref.read(bookingProvider.notifier);
                var bookingNow = ref.read(bookingProvider);
                final bookingName = bookingNow.pickupContactName?.trim() ?? '';
                if (bookingName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.onboardingNameRequired)),
                  );
                  context.push(
                    '/payment',
                    extra: kBookingReturnToSummaryExtra,
                  );
                  return;
                }
                // Safety net: if rider reached normal summary while mode is still
                // marketplace without an offer, treat this as an instant ride.
                final requiresNamedPrice =
                    bookingNow.effectiveRideMode == BookingMode.marketplace ||
                        bookingNow.effectiveRideMode == BookingMode.terug;
                if (requiresNamedPrice &&
                    (bookingNow.marketplaceBidEuro == null ||
                        bookingNow.marketplaceBidEuro! <= 0)) {
                  bookingNotifier.setInstant();
                  bookingNow = ref.read(bookingProvider);
                }
                final locationOk = await ensureLocationForBooking(
                  context: context,
                  ref: ref,
                );
                if (!context.mounted || !locationOk) return;
                ref.read(rideRequestProvider.notifier).reset();
                if (_saveTripForNextTime) {
                  final pu = bookingNow.pickup;
                  final de = bookingNow.destination;
                  if (pu != null && de != null) {
                    unawaited(
                      ref.read(savedTripsProvider.notifier).saveTrip(
                            pickup: pu,
                            destination: de,
                          ),
                    );
                    unawaited(
                      ref
                          .read(recentDestinationsProvider.notifier)
                          .recordTripForLater(
                            pickup: pu,
                            destination: de,
                          ),
                    );
                  }
                }
                final path = rideMatchingVariantForBookingMode(
                  bookingNow.effectiveRideMode,
                ).routePath;
                context.go(path);
              },
            ),
          ),
        ],
      ),
    );
  }
}
