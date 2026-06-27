import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../../models/marketplace_driver_offer.dart';
import '../../../providers/marketplace_pricing_provider.dart';

class MarketplaceOfferCard extends StatelessWidget {
  const MarketplaceOfferCard({
    super.key,
    required this.offer,
    required this.riderOfferEuro,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onAccept,
    required this.onDecline,
    this.isBusy = false,
    this.recommended = false,
  });

  final MarketplaceDriverOffer offer;
  final double riderOfferEuro;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool isBusy;
  final bool recommended;

  bool get _isAccept => offer.isAcceptAtPrice(riderOfferEuro);

  @override
  Widget build(BuildContext context) {
    final priceColor = _isAccept ? colors.success : colors.warning;
    final statusLabel = _isAccept
        ? l10n.marketplaceOfferAcceptsYourPrice
        : l10n.marketplaceOfferCounterLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colors.accentL,
                backgroundImage:
                    offer.photoUrl != null ? NetworkImage(offer.photoUrl!) : null,
                child: offer.photoUrl == null
                    ? Icon(Icons.person, color: colors.accent)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            offer.driverName,
                            style: typo.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (recommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentL,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l10n.marketplaceRecommended,
                              style: typo.labelSmall.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '⭐ ${offer.rating.toStringAsFixed(1)}',
                      style: typo.bodySmall.copyWith(color: colors.textMid),
                    ),
                    if (offer.vehicleLabel != null)
                      Text(
                        '${offer.vehicleLabel} • ${l10n.marketplaceOfferMinutesAway(offer.etaMinutes)}',
                        style: typo.bodySmall.copyWith(color: colors.textSoft),
                      ),
                  ],
                ),
              ),
              Text(
                formatMarketplaceEuro(offer.bidAmountEuro),
                style: typo.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: priceColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusLabel,
            style: typo.labelLarge.copyWith(
              color: priceColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (offer.message != null && offer.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              offer.message!,
              style: typo.bodySmall.copyWith(
                color: colors.textMid,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onDecline,
                  child: Text(
                    _isAccept ? l10n.marketplaceViewProfile : l10n.declineBid,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: isBusy ? null : onAccept,
                  child: isBusy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onAccent,
                          ),
                        )
                      : Text(l10n.acceptBid),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
