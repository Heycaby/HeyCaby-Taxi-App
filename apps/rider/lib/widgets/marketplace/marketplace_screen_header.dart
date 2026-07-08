import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Minimal marketplace header.
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
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            style: IconButton.styleFrom(
              foregroundColor: colors.text,
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 24),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.marketplace,
                  style: typo.headingMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  l10n.marketplaceSubtitle,
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
