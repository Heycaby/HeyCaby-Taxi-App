import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import 'trip_summary_details_section.dart';
import 'trip_summary_route_section.dart';

/// Bottom sheet-style panel for trip summary (map stays on the screen).
class TripSummarySheet extends StatelessWidget {
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
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TripSummaryStatChip(
                        icon: Icons.route_rounded,
                        label: distanceKm > 0
                            ? '${distanceKm.toStringAsFixed(1)} km'
                            : '— km',
                        colors: colors,
                        typo: typo,
                      ),
                      const SizedBox(width: 12),
                      TripSummaryStatChip(
                        icon: Icons.schedule_rounded,
                        label: distanceKm > 0 ? etaText : '—',
                        colors: colors,
                        typo: typo,
                      ),
                      if (booking.tripPriceBandMinEuro != null &&
                          booking.tripPriceBandMaxEuro != null) ...[
                        const SizedBox(width: 12),
                        TripSummaryStatChip(
                          icon: Icons.euro_rounded,
                          label: (booking.tripPriceBandMinEuro! -
                                          booking.tripPriceBandMaxEuro!)
                                      .abs() <
                                  0.01
                              ? '€${_fmtTripEuro(booking.tripPriceBandMinEuro!)}'
                              : '€${_fmtTripEuro(booking.tripPriceBandMinEuro!)}–${_fmtTripEuro(booking.tripPriceBandMaxEuro!)}',
                          colors: colors,
                          typo: typo,
                        ),
                      ] else if (booking.estimatedFareEuro != null) ...[
                        const SizedBox(width: 12),
                        TripSummaryStatChip(
                          icon: Icons.euro_rounded,
                          label: booking.estimatedFareEuro! ==
                                  booking.estimatedFareEuro!.roundToDouble()
                              ? '€${booking.estimatedFareEuro!.toStringAsFixed(0)}'
                              : '€${booking.estimatedFareEuro!.toStringAsFixed(1)}',
                          colors: colors,
                          typo: typo,
                        ),
                      ],
                    ],
                  )
                      .animate(delay: 60.ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.06, end: 0, duration: 300.ms),
                  const SizedBox(height: 24),
                  TripSummaryRouteCard(
                    booking: booking,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    onEditAddress: onEditAddress,
                  )
                      .animate(delay: 120.ms)
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.06, end: 0, duration: 320.ms),
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

String _fmtTripEuro(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
