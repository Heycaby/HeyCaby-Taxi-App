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
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.marketplaceYourRoute,
            style: typo.labelLarge.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _RouteStop(
            colors: colors,
            typo: typo,
            dotColor: colors.warning,
            label: l10n.pickup,
            value: booking.pickup?.displayName,
            placeholder: l10n.marketplaceWhereAreYouGoing,
            onTap: onPickup,
            onClear: onClearPickup,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 11),
            child: Container(
              width: 2,
              height: 16,
              color: colors.border.withValues(alpha: 0.7),
            ),
          ),
          _RouteStop(
            colors: colors,
            typo: typo,
            dotColor: colors.success,
            label: l10n.destination,
            value: booking.destination?.displayName,
            placeholder: l10n.destination,
            onTap: onDestination,
            onClear: onClearDestination,
          ),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.colors,
    required this.typo,
    required this.dotColor,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Color dotColor;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final isSet = value != null && value!.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.lightTap();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 6, 0, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: typo.labelSmall.copyWith(
                        color: colors.textSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSet ? value! : placeholder,
                      style: typo.bodyMedium.copyWith(
                        color: isSet ? colors.text : colors.textSoft,
                        fontWeight: isSet ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, color: colors.textSoft, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
