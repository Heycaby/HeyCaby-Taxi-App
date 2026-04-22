import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';

String tripSummaryLocalizedPaymentId(String id, AppLocalizations l10n) {
  switch (id) {
    case 'cash':
      return l10n.cash;
    case 'pin':
      return l10n.pin;
    case 'tikkie':
      return l10n.tikkie;
    default:
      return id;
  }
}

String tripSummaryLocalizedVehicleCategory(String? key, AppLocalizations l10n) {
  switch (key) {
    case 'comfort':
      return l10n.vehicleComfort;
    case 'taxibus':
      return l10n.vehicleTaxibus;
    case 'wheelchair':
      return l10n.vehicleWheelchair;
    case 'standard':
    case null:
    case '':
      return l10n.vehicleStandard;
    default:
      return key;
  }
}

/// Passenger, vehicle, and payment blocks with Edit → vehicle / payment screens.
class TripSummaryPreferencesSection extends StatelessWidget {
  final BookingState booking;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onEditPassengerAndRide;
  final VoidCallback onEditPayment;

  const TripSummaryPreferencesSection({
    super.key,
    required this.booking,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onEditPassengerAndRide,
    required this.onEditPayment,
  });

  String _paymentSummary() {
    if (booking.paymentMethods.isNotEmpty) {
      return booking.paymentMethods
          .map((id) => tripSummaryLocalizedPaymentId(id, l10n))
          .join(' · ');
    }
    if (booking.paymentMethod != null &&
        booking.paymentMethod!.trim().isNotEmpty) {
      return booking.paymentMethod!.trim();
    }
    return l10n.cash;
  }

  String _passengerExtras() {
    final parts = <String>[];
    if (booking.petFriendly) parts.add(l10n.petFriendly);
    if (booking.favoritesFirst) parts.add(l10n.favoriteDriversFirstTripDetail);
    if (parts.isEmpty) return '';
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final name = booking.pickupContactName?.trim() ?? '';
    final vehicle = booking.vehicleCategories.length >= 2
        ? booking.vehicleCategories
            .map((k) => tripSummaryLocalizedVehicleCategory(k, l10n))
            .join(' · ')
        : tripSummaryLocalizedVehicleCategory(
            booking.vehicleCategory,
            l10n,
          );
    final extras = _passengerExtras();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TripSummaryEditCard(
          colors: colors,
          typo: typo,
          title: l10n.tripSummaryPassengerRideSection,
          onEdit: onEditPassengerAndRide,
          editLabel: l10n.tripSummaryEdit,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TripSummaryDetailLine(
                icon: Icons.person_outline_rounded,
                text: name.isNotEmpty ? name : l10n.tripSummaryNameNotSet,
                colors: colors,
                typo: typo,
                muted: name.isEmpty,
              ),
              const SizedBox(height: 10),
              _TripSummaryDetailLine(
                icon: Icons.directions_car_rounded,
                text: vehicle,
                colors: colors,
                typo: typo,
                muted: false,
              ),
              if (extras.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  extras,
                  style: typo.bodySmall.copyWith(
                    color: colors.textSoft,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _TripSummaryEditCard(
          colors: colors,
          typo: typo,
          title: l10n.tripSummaryPaymentSection,
          onEdit: onEditPayment,
          editLabel: l10n.tripSummaryEdit,
          child: _TripSummaryDetailLine(
            icon: Icons.payments_rounded,
            text: _paymentSummary(),
            colors: colors,
            typo: typo,
            muted: false,
          ),
        ),
      ],
    );
  }
}

class _TripSummaryEditCard extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final String editLabel;
  final VoidCallback onEdit;
  final Widget child;

  const _TripSummaryEditCard({
    required this.colors,
    required this.typo,
    required this.title,
    required this.editLabel,
    required this.onEdit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: typo.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  HapticService.lightTap();
                  onEdit();
                },
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: colors.accent,
                ),
                label: Text(
                  editLabel,
                  style: typo.labelLarge.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TripSummaryDetailLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool muted;

  const _TripSummaryDetailLine({
    required this.icon,
    required this.text,
    required this.colors,
    required this.typo,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: muted ? colors.textSoft : colors.textMid,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: typo.bodyMedium.copyWith(
              color: muted ? colors.textSoft : colors.text,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyChip {
  final IconData icon;
  final String label;
  const _ReadOnlyChip({required this.icon, required this.label});
}

/// Read-only chips for contexts that only need a compact summary (e.g. scheduled matching).
class TripSummaryDetailSection extends StatelessWidget {
  final BookingState booking;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const TripSummaryDetailSection({
    super.key,
    required this.booking,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final paymentChips = <_ReadOnlyChip>[
      if (booking.paymentMethods.isNotEmpty)
        ...booking.paymentMethods.map(
          (id) => _ReadOnlyChip(
            icon: Icons.payments_rounded,
            label: tripSummaryLocalizedPaymentId(id, l10n),
          ),
        )
      else
        _ReadOnlyChip(
          icon: Icons.payments_rounded,
          label: (booking.paymentMethod != null &&
                  booking.paymentMethod!.trim().isNotEmpty)
              ? booking.paymentMethod!
              : l10n.cash,
        ),
    ];

    final details = <_ReadOnlyChip>[
      if (booking.pickupContactName != null &&
          booking.pickupContactName!.trim().isNotEmpty)
        _ReadOnlyChip(
          icon: Icons.person_outline_rounded,
          label: booking.pickupContactName!.trim(),
        ),
      _ReadOnlyChip(
        icon: Icons.directions_car_rounded,
        label: tripSummaryLocalizedVehicleCategory(booking.vehicleCategory, l10n),
      ),
      ...paymentChips,
      if (booking.petFriendly)
        _ReadOnlyChip(icon: Icons.pets_rounded, label: l10n.petFriendly),
      if (booking.favoritesFirst)
        _ReadOnlyChip(
          icon: Icons.star_rounded,
          label: l10n.favoriteDriversFirstTripDetail,
        ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: details
          .map(
            (d) => Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(d.icon, color: colors.textMid, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    d.label,
                    style: typo.bodySmall.copyWith(
                      color: colors.textMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class TripSummaryFindDriverFooter extends StatefulWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final bool isLoading;
  final VoidCallback onConfirm;

  const TripSummaryFindDriverFooter({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.isLoading,
    required this.onConfirm,
  });

  @override
  State<TripSummaryFindDriverFooter> createState() =>
      _TripSummaryFindDriverFooterState();
}

class _TripSummaryFindDriverFooterState extends State<TripSummaryFindDriverFooter> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = _tapped || widget.isLoading;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: BoxDecoration(
        color: widget.colors.bg,
        border: Border(
          top: BorderSide(color: widget.colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          onPressed: isDisabled
              ? null
              : () {
                  setState(() => _tapped = true);
                  widget.onConfirm();
                },
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: widget.colors.border,
            disabledForegroundColor: widget.colors.textMid,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: (widget.isLoading || _tapped)
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: widget.colors.onAccent,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded,
                        color: widget.colors.onAccent, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      widget.l10n.findMyDriver,
                      style: widget.typo.labelLarge.copyWith(
                        color: widget.colors.onAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
