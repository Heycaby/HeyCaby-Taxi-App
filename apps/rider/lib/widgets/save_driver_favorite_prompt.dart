import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/favorites_provider.dart';
import '../providers/pending_save_driver_provider.dart';
import 'email_modal.dart';

enum SaveDriverFavoriteOutcome {
  skipped,
  cancelled,
  saved,
  limitReached,
}

/// After a 4–5 star rating, offer to save the driver to favourites.
/// If the rider has no verified email, prompt them to add and verify one first.
Future<SaveDriverFavoriteOutcome> maybeShowSaveDriverFavoritePrompt(
  BuildContext context, {
  required ProviderContainer container,
  required String rideRequestId,
  required String driverId,
  String? riderToken,
}) async {
  final favorites = await container.read(favoritesProvider.future);
  if (favorites.any((driver) => driver.driverId == driverId)) {
    return SaveDriverFavoriteOutcome.skipped;
  }

  if (!context.mounted) return SaveDriverFavoriteOutcome.skipped;

  // Check if rider has a verified email. If not, prompt email modal first.
  final identity = await container.read(riderIdentityProvider.future);
  final hasEmail = (identity.email ?? '').trim().isNotEmpty;
  if (!hasEmail) {
    if (!context.mounted) return SaveDriverFavoriteOutcome.skipped;
    final emailVerified = await showEmailModal(context);
    if (!emailVerified) return SaveDriverFavoriteOutcome.skipped;
    // Reload favorites after email login since identity may have changed.
    container.invalidate(favoritesProvider);
    final updatedFavorites =
        await container.read(favoritesProvider.future);
    if (updatedFavorites.any((driver) => driver.driverId == driverId)) {
      return SaveDriverFavoriteOutcome.skipped;
    }
  }

  if (!context.mounted) return SaveDriverFavoriteOutcome.skipped;
  final colors = container.read(colorsProvider);
  final typo = container.read(typographyProvider);
  final l10n = AppLocalizations.of(context);
  final confirmed = await showHeyCabyConfirmSheet(
    context,
    colors: colors,
    typography: typo,
    title: l10n.saveDriverModalTitle,
    message: l10n.saveDriverModalBody,
    dismissLabel: l10n.saveDriverModalDismiss,
    confirmLabel: l10n.saveDriverModalConfirm,
    icon: Icons.favorite_rounded,
    iconColor: colors.accent,
    confirmDestructive: false,
  );
  if (!context.mounted || !confirmed) {
    return SaveDriverFavoriteOutcome.cancelled;
  }

  // Re-read identity after potential email login to get fresh riderToken.
  final freshIdentity = await container.read(riderIdentityProvider.future);
  final effectiveRiderToken =
      (riderToken?.trim().isNotEmpty == true) ? riderToken : freshIdentity.riderToken;

  final result = await container.read(favoritesProvider.notifier).addFavorite(
        rideRequestId: rideRequestId,
        driverId: driverId,
        riderToken: effectiveRiderToken,
      );

  if (result.success) {
    return SaveDriverFavoriteOutcome.saved;
  }
  if (result.reason == 'favorite_limit_reached') {
    return SaveDriverFavoriteOutcome.limitReached;
  }
  return SaveDriverFavoriteOutcome.skipped;
}

void queueFavoriteSaveFeedback(
  ProviderContainer container,
  SaveDriverFavoriteOutcome outcome,
) {
  switch (outcome) {
    case SaveDriverFavoriteOutcome.saved:
      container.read(favoriteSaveFeedbackProvider.notifier).state =
          FavoriteSaveFeedback.saved;
    case SaveDriverFavoriteOutcome.limitReached:
      container.read(favoriteSaveFeedbackProvider.notifier).state =
          FavoriteSaveFeedback.limitReached;
    case SaveDriverFavoriteOutcome.skipped:
    case SaveDriverFavoriteOutcome.cancelled:
      break;
  }
}
