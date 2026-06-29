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
    required this.onClose,
  });

  final bool isSubmitting;
  final bool hasAddresses;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final enabled = hasAddresses && !isSubmitting;

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        HeyCabySpacing.screenEdge,
        12,
        HeyCabySpacing.screenEdge,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: enabled ? onTap : null,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 54,
            height: 54,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Icon(Icons.close, color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}
