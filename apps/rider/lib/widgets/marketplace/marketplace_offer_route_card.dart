import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';

class MarketplaceOfferRouteCard extends StatelessWidget {
  const MarketplaceOfferRouteCard({
    super.key,
    required this.booking,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onPickup,
    required this.onDestination,
    this.onClearPickup,
    this.onClearDestination,
  });

  final BookingState booking;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onPickup;
  final VoidCallback onDestination;
  final VoidCallback? onClearPickup;
  final VoidCallback? onClearDestination;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _RouteLine(
            colors: colors,
            typo: typo,
            dotColor: colors.success,
            icon: Icons.radio_button_checked,
            label: booking.pickup?.displayName ?? l10n.pickup,
            isSet: booking.pickup != null,
            onTap: onPickup,
            onClear: booking.pickup != null ? onClearPickup : null,
          ),
          Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
          _RouteLine(
            colors: colors,
            typo: typo,
            dotColor: colors.error,
            icon: Icons.location_on_rounded,
            label: booking.destination?.displayName ?? l10n.destination,
            isSet: booking.destination != null,
            onTap: onDestination,
            onClear: booking.destination != null ? onClearDestination : null,
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.colors,
    required this.typo,
    required this.dotColor,
    required this.icon,
    required this.label,
    required this.isSet,
    required this.onTap,
    this.onClear,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Color dotColor;
  final IconData icon;
  final String label;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticService.lightTap();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: dotColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: typo.bodyLarge.copyWith(
                  color: isSet ? colors.text : colors.textSoft,
                  fontWeight: isSet ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
                icon: Icon(Icons.close, color: colors.textSoft, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
