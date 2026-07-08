import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import 'trip_summary_details_section.dart';
import 'trip_summary_route_section.dart';

/// Draggable bottom sheet for trip summary (map stays full-screen behind).
class TripSummarySheet extends StatelessWidget {
  final ScrollController scrollController;
  final BookingState booking;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final double distanceKm;
  final String etaText;
  final bool isLoading;
  final void Function(bool isPickup) onEditAddress;
  final VoidCallback onEditPassengerAndRide;
  final VoidCallback onEditPayment;
  final Future<void> Function()? onSaveForLater;
  final bool saveTripForNextTime;
  final ValueChanged<bool>? onSaveTripForNextTimeChanged;
  final VoidCallback onConfirm;

  const TripSummarySheet({
    super.key,
    required this.scrollController,
    required this.booking,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.distanceKm,
    required this.etaText,
    required this.isLoading,
    required this.onEditAddress,
    required this.onEditPassengerAndRide,
    required this.onEditPayment,
    this.onSaveForLater,
    this.saveTripForNextTime = false,
    this.onSaveTripForNextTimeChanged,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      colors: colors,
      typography: typo,
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      tintColor: colors.card,
      child: Column(
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.accentL,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.map_rounded,
                          color: colors.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.tripSummary,
                              style: typo.headingLarge.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              l10n.tripSummarySubtitle,
                              style: typo.bodySmall.copyWith(
                                color: colors.textMid,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                      .slideY(begin: 0.06, end: 0, duration: 300.ms),
                  const SizedBox(height: 16),
                  TripSummaryRouteCard(
                    booking: booking,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    distanceKm: distanceKm,
                    etaText: etaText,
                    priceLabel: _priceLabel(booking),
                    onEditAddress: onEditAddress,
                  )
                      .animate(delay: 60.ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.06, end: 0, duration: 300.ms),
                  const SizedBox(height: 20),
                  TripSummaryPreferencesSection(
                    booking: booking,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    onEditPassengerAndRide: onEditPassengerAndRide,
                    onEditPayment: onEditPayment,
                  )
                      .animate(delay: 180.ms)
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.06, end: 0, duration: 320.ms),
                  if (booking.scheduledAt != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        14, 12, 14, 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        l10n.scheduledCommitmentDisclosure,
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (onSaveTripForNextTimeChanged != null) ...[
                    Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        14, 12, 10, 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.saveTripForNextTimeLabel,
                                  style: typo.titleSmall.copyWith(
                                    color: colors.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.saveTripForNextTimeSubtitle,
                                  style: typo.bodySmall.copyWith(
                                    color: colors.textMid,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: saveTripForNextTime,
                            onChanged: isLoading
                                ? null
                                : onSaveTripForNextTimeChanged,
                            activeTrackColor: colors.accent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (onSaveForLater != null)
                    Center(
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                await onSaveForLater!();
                              },
                        child: Text(
                          l10n.saveBookingForLater,
                          style: typo.labelLarge.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          TripSummaryFindDriverFooter(
            colors: colors,
            typo: typo,
            l10n: l10n,
            isLoading: isLoading,
            onConfirm: onConfirm,
          )
              .animate(delay: 220.ms)
              .fadeIn(duration: 320.ms)
              .slideY(begin: 0.08, end: 0, duration: 320.ms),
        ],
      ),
    );
  }
}

String? _priceLabel(BookingState booking) {
  if (booking.tripPriceBandMinEuro != null &&
      booking.tripPriceBandMaxEuro != null) {
    final min = booking.tripPriceBandMinEuro!;
    final max = booking.tripPriceBandMaxEuro!;
    if ((min - max).abs() < 0.01) {
      return '€${_fmtTripEuro(min)}';
    }
    return '€${_fmtTripEuro(min)}–${_fmtTripEuro(max)}';
  }
  final fare = booking.estimatedFareEuro;
  if (fare == null) return null;
  return fare == fare.roundToDouble()
      ? '€${fare.toStringAsFixed(0)}'
      : '€${fare.toStringAsFixed(1)}';
}

String _fmtTripEuro(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
