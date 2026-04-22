import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../models/ride_matching_variant.dart';

String matchingAlternativesHeadline(
  RideMatchingVariant variant,
  AppLocalizations l10n,
) {
  switch (variant) {
    case RideMatchingVariant.scheduled:
      return l10n.matchingAlternativesTitleScheduled;
    case RideMatchingVariant.marketplace:
    case RideMatchingVariant.instant:
      return l10n.noDriverFoundCard;
  }
}

/// Opens a modal with context-aware actions (scheduled / marketplace / instant).
Future<void> showMatchingAlternativesSheet({
  required BuildContext context,
  required RideMatchingVariant variant,
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typo,
  required AppLocalizations l10n,
  required VoidCallback onNotifyMe,
  required VoidCallback onScheduleRide,
  required VoidCallback onTryMarketplace,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          top: 8,
          left: 8,
          right: 8,
          bottom: 8 + MediaQuery.viewPaddingOf(sheetContext).bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.warning.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.local_taxi,
                            color: colors.warning, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          matchingAlternativesHeadline(variant, l10n),
                          style: typo.bodyMedium.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  MatchingAlternativesActionButtons(
                    variant: variant,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    onNotifyMe: () {
                      Navigator.of(sheetContext).pop();
                      onNotifyMe();
                    },
                    onScheduleRide: () {
                      Navigator.of(sheetContext).pop();
                      onScheduleRide();
                    },
                    onTryMarketplace: () {
                      Navigator.of(sheetContext).pop();
                      onTryMarketplace();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Action rows for matching alternatives (sheet or inline).
class MatchingAlternativesActionButtons extends StatelessWidget {
  final RideMatchingVariant variant;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onNotifyMe;
  final VoidCallback onScheduleRide;
  final VoidCallback onTryMarketplace;

  const MatchingAlternativesActionButtons({
    super.key,
    required this.variant,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onNotifyMe,
    required this.onScheduleRide,
    required this.onTryMarketplace,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case RideMatchingVariant.scheduled:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onNotifyMe,
                icon: Icon(Icons.notifications_active_outlined,
                    color: colors.accent, size: 18),
                label: Text(
                  l10n.notifyMeWhenFound,
                  style: typo.labelLarge.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onTryMarketplace,
                icon: Icon(Icons.storefront_outlined,
                    color: colors.onAccent, size: 18),
                label: Text(
                  l10n.matchingTryMarketplace,
                  style: typo.labelLarge.copyWith(
                    color: colors.onAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
      case RideMatchingVariant.marketplace:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onScheduleRide,
                icon: Icon(Icons.calendar_today_outlined,
                    color: colors.accent, size: 16),
                label: Text(
                  l10n.scheduleRideInstead,
                  style: typo.labelLarge.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onNotifyMe,
                icon: Icon(Icons.notifications_active_outlined,
                    color: colors.onAccent, size: 16),
                label: Text(
                  l10n.notifyMeWhenFound,
                  style: typo.labelLarge.copyWith(
                    color: colors.onAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
      case RideMatchingVariant.instant:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onScheduleRide,
                    icon: Icon(Icons.calendar_today_outlined,
                        color: colors.accent, size: 16),
                    label: Text(
                      l10n.scheduleRideInstead,
                      style: typo.labelLarge.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTryMarketplace,
                    icon: Icon(Icons.storefront_outlined,
                        color: colors.accent, size: 16),
                    label: Text(
                      l10n.matchingTryMarketplace,
                      style: typo.labelLarge.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onNotifyMe,
              icon: Icon(Icons.notifications_active_outlined,
                  color: colors.onAccent, size: 18),
              label: Text(
                l10n.notifyMeWhenFound,
                style: typo.labelLarge.copyWith(
                  color: colors.onAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        );
    }
  }
}
