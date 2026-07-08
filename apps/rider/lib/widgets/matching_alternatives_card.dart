import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../models/ride_matching_variant.dart';
import 'booking/matching_recovery_sheet.dart';

String matchingAlternativesHeadline(
  RideMatchingVariant variant,
  AppLocalizations l10n,
) {
  switch (variant) {
    case RideMatchingVariant.scheduled:
      return l10n.matchingAlternativesTitleScheduled;
    case RideMatchingVariant.marketplace:
    case RideMatchingVariant.terug:
    case RideMatchingVariant.instant:
      return l10n.noDriverFoundCard;
  }
}

/// Opens a minimal sheet with progressive recovery options.
Future<void> showMatchingAlternativesSheet({
  required BuildContext context,
  required RideMatchingVariant variant,
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typo,
  required AppLocalizations l10n,
  required VoidCallback onNotifyMe,
  required VoidCallback onScheduleRide,
  required VoidCallback onTryMarketplace,
  String? titleOverride,
  String? bodyOverride,
  bool initiallyExpanded = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.42),
    builder: (sheetContext) {
      final bottom = MediaQuery.paddingOf(sheetContext).bottom;
      void closeAnd(VoidCallback action) {
        Navigator.of(sheetContext).pop();
        action();
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
        child: MatchingRecoverySheet(
          colors: colors,
          typo: typo,
          l10n: l10n,
          title: titleOverride ?? matchingAlternativesHeadline(variant, l10n),
          body: bodyOverride ?? l10n.searchNoSupplyInlineBody,
          variant: variant,
          onNotifyMe: () => closeAnd(onNotifyMe),
          onSchedule: () => closeAnd(onScheduleRide),
          onMarketplace: () => closeAnd(onTryMarketplace),
          initiallyExpanded: initiallyExpanded,
        ),
      );
    },
  );
}
