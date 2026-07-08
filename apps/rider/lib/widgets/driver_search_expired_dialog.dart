import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../constants/rider_search_window.dart';
import '../models/ride_matching_variant.dart';
import '../providers/active_search_provider.dart';
import '../services/rider_matching_recovery_actions.dart';
import 'booking/matching_recovery_sheet.dart';

/// Shown when the full search window ends without a driver match.
Future<void> showDriverSearchExpiredDialog(
  BuildContext context,
  WidgetRef ref, {
  bool markGrowthModalDismissedAfter = false,
  RideMatchingVariant variant = RideMatchingVariant.instant,
}) async {
  final colors = ref.read(colorsProvider);
  final typo = ref.read(typographyProvider);
  final l10n = AppLocalizations.of(context);
  final minutes = kRiderDriverSearchWindow.inMinutes;

  await showModalBottomSheet<void>(
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
          title: l10n.searchExpiredSheetTitle,
          body: l10n.searchExpiredSheetBody(minutes),
          variant: variant,
          showTryAgain: true,
          onTryAgain: () => closeAnd(() {
            unawaited(RiderMatchingRecoveryActions.tryAgain(ref, context));
          }),
          onNotifyMe: () => closeAnd(() {
            unawaited(RiderMatchingRecoveryActions.notifyMe(ref, context));
          }),
          onSchedule: () => closeAnd(() {
            RiderMatchingRecoveryActions.schedule(ref, context);
          }),
          onMarketplace: () => closeAnd(() {
            RiderMatchingRecoveryActions.marketplace(ref, context);
          }),
          showDismiss: true,
          onDismiss: () => Navigator.of(sheetContext).pop(),
        ),
      );
    },
  );

  if (markGrowthModalDismissedAfter) {
    await ref.read(activeSearchProvider.notifier).markGrowthModalDismissed();
  }
}
