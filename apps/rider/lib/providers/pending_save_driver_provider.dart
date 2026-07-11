import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown on [HomeScreen] after a successful driver rating (4–5 stars).
class PendingSaveDriverPrompt {
  const PendingSaveDriverPrompt({
    required this.rideRequestId,
    required this.driverId,
    this.riderToken,
  });

  final String rideRequestId;
  final String driverId;
  final String? riderToken;
}

final pendingSaveDriverPromptProvider =
    StateProvider<PendingSaveDriverPrompt?>((ref) => null);

enum FavoriteSaveFeedback { saved, limitReached }

/// Snackbar on [HomeScreen] after post-ride favourite save (avoids dead context).
final favoriteSaveFeedbackProvider =
    StateProvider<FavoriteSaveFeedback?>((ref) => null);
