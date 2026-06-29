import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Marketplace screen header — matches Home V2 card typography.
class MarketplaceScreenHeader extends StatelessWidget {
  const MarketplaceScreenHeader({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onClose,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            style: IconButton.styleFrom(
              backgroundColor: colors.card,
              foregroundColor: colors.text,
            ),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.accentL,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.savings_outlined, color: colors.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.marketplace,
                  style: typo.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  l10n.marketplaceTagline,
                  style: typo.bodySmall.copyWith(
                    color: colors.textMid,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
