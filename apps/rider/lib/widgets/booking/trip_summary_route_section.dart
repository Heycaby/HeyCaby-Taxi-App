import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import '../../providers/booking_provider.dart';

class TripSummaryStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const TripSummaryStatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.accent, size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typo.labelLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TripSummaryRouteCard extends StatelessWidget {
  final BookingState booking;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final void Function(bool isPickup) onEditAddress;

  const TripSummaryRouteCard({
    super.key,
    required this.booking,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onEditAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _TripSummaryRouteRow(
            dotColor: colors.success,
            typeLabel: l10n.pickup,
            addressLabel: booking.pickup?.fullAddress ?? l10n.pickup,
            isPickup: true,
            colors: colors,
            typo: typo,
            onEdit: () {
              HapticService.lightTap();
              onEditAddress(true);
            },
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 11, top: 6, bottom: 6),
            child: Column(
              children: List.generate(
                4,
                (i) => Container(
                  width: 2,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 3),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
          _TripSummaryRouteRow(
            dotColor: colors.error,
            typeLabel: l10n.tripSummaryDropoffLabel,
            addressLabel:
                booking.destination?.fullAddress ?? l10n.destination,
            isPickup: false,
            colors: colors,
            typo: typo,
            onEdit: () {
              HapticService.lightTap();
              onEditAddress(false);
            },
          ),
        ],
      ),
    );
  }
}

class _TripSummaryRouteRow extends StatelessWidget {
  final Color dotColor;
  final String typeLabel;
  final String addressLabel;
  final bool isPickup;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onEdit;

  const _TripSummaryRouteRow({
    required this.dotColor,
    required this.typeLabel,
    required this.addressLabel,
    required this.isPickup,
    required this.colors,
    required this.typo,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: dotColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPickup ? Icons.radio_button_checked : Icons.location_on,
            color: dotColor,
            size: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                typeLabel,
                style: typo.bodySmall.copyWith(color: colors.textSoft),
              ),
              const SizedBox(height: 2),
              Text(
                addressLabel,
                style: typo.bodyMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.bgAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.edit_outlined, color: colors.textMid, size: 16),
          ),
        ),
      ],
    );
  }
}
