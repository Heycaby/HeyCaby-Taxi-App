import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/nearby_category_supply_provider.dart';
import '../../providers/marketplace_pricing_provider.dart';

class MarketplaceOfferHero extends ConsumerWidget {
  const MarketplaceOfferHero({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.pulseValue,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final double pulseValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supply = ref.watch(nearbyCategorySupplyProvider);
    final online = supply.valueOrNull == null
        ? null
        : sumNearbyDriverCount(supply.valueOrNull!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.marketplaceOfferHeadline,
          style: typo.titleLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.marketplaceOfferExplanation,
          style: typo.bodyMedium.copyWith(
            color: colors.textMid,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.marketplaceDriversAcceptHint,
          style: typo.bodySmall.copyWith(
            color: colors.textSoft,
            height: 1.4,
          ),
        ),
        if (online != null && online > 0) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                l10n.marketplaceDriversOnline(online),
                style: typo.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.success
                        .withValues(alpha: 0.3 + pulseValue * 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.85 + pulseValue * 0.3,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.marketplaceLiveBadge,
                      style: typo.labelSmall.copyWith(
                        color: colors.success,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
