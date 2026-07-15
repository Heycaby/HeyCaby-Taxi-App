import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

final riderReceiptProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, rideId) async {
  final api = ref.read(riderApiProvider);
  final identity = await ref.read(riderIdentityProvider.future);
  final receipt = await api.fetchRideReceipt(
    rideRequestId: rideId,
    riderToken: identity.riderToken,
  );
  if (receipt == null) return null;
  // Merge fare breakdown (actual distance, duration, traffic overtime).
  final breakdown = await api.fetchRideFareBreakdown(rideRequestId: rideId);
  if (breakdown != null) {
    receipt.addAll(breakdown);
  }
  return receipt;
});
