import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// One-line explainer: pay what you want + driver choice.
class MarketplaceIntroStrip extends StatelessWidget {
  const MarketplaceIntroStrip({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    this.isTaxiTerug = false,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final bool isTaxiTerug;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.accentL,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTaxiTerug
                ? l10n.taxiTerugOfferHeadline
                : l10n.marketplaceOfferHeadline,
            style: typo.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isTaxiTerug ? l10n.taxiTerugIntroBody : l10n.marketplaceIntroBody,
            style: typo.bodySmall.copyWith(
              color: colors.textMid,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
