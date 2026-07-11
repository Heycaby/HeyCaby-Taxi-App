import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

final riderReceiptProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, rideId) async {
  final api = ref.read(riderApiProvider);
  final identity = await ref.read(riderIdentityProvider.future);
  return api.fetchRideReceipt(
    rideRequestId: rideId,
    riderToken: identity.riderToken,
  );
});
