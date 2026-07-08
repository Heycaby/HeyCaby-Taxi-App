import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

class MarketplaceOfferFooter extends StatelessWidget {
  const MarketplaceOfferFooter({
    super.key,
    required this.isSubmitting,
    required this.hasAddresses,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onTap,
  });

  final bool isSubmitting;
  final bool hasAddresses;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = hasAddresses && !isSubmitting;

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.45))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasAddresses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                l10n.marketplaceSetPickupDestinationHint,
                textAlign: TextAlign.center,
                style: typo.bodySmall.copyWith(color: colors.textMid),
              ),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: enabled ? onTap : null,
              child: isSubmitting
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onAccent,
                      ),
                    )
                  : Text(
                      l10n.marketplacePostRequest,
                      style: typo.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
