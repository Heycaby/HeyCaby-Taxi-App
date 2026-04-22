import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/booking_draft_storage.dart';
import 'booking_provider.dart';

/// Locally saved booking (save-for-later). Auto-dispose refetch when re-entering flow.
final bookingDraftProvider = FutureProvider.autoDispose<BookingState?>((ref) {
  return BookingDraftStorage.load();
});
