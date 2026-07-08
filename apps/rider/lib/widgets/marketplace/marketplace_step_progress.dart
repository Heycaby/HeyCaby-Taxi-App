import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Minimal 3-step indicator: route → offer → post.
class MarketplaceStepProgress extends StatelessWidget {
  const MarketplaceStepProgress({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.routeDone,
    required this.priceDone,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final bool routeDone;
  final bool priceDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Step(
            colors: colors,
            typo: typo,
            label: l10n.marketplaceStepRoute,
            index: 1,
            active: true,
            done: routeDone,
          ),
        ),
        _connector(colors, routeDone),
        Expanded(
          child: _Step(
            colors: colors,
            typo: typo,
            label: l10n.marketplaceStepOffer,
            index: 2,
            active: routeDone,
            done: priceDone,
          ),
        ),
        _connector(colors, priceDone),
        Expanded(
          child: _Step(
            colors: colors,
            typo: typo,
            label: l10n.marketplaceStepPost,
            index: 3,
            active: routeDone && priceDone,
            done: false,
          ),
        ),
      ],
    );
  }

  Widget _connector(HeyCabyColorTokens colors, bool filled) {
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: filled ? colors.accent : colors.border,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.colors,
    required this.typo,
    required this.label,
    required this.index,
    required this.active,
    required this.done,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String label;
  final int index;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final accent = active || done;
    final fill =
        done ? colors.accent : (active ? colors.accentL : colors.bgAlt);
    final border = done || active ? colors.accent : colors.border;
    final textColor = accent ? colors.text : colors.textSoft;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5),
          ),
          alignment: Alignment.center,
          child: done
              ? Icon(Icons.check_rounded, size: 16, color: colors.onAccent)
              : Text(
                  '$index',
                  style: typo.labelSmall.copyWith(
                    color: accent ? colors.accent : colors.textSoft,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: typo.labelSmall.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
