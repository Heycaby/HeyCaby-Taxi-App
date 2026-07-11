import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import '../models/taxi_terug_queue_status.dart';
import '../services/taxi_terug_queue_service.dart';

final taxiTerugQueueServiceProvider =
    Provider<TaxiTerugQueueService>((_) => TaxiTerugQueueService());

final taxiTerugQueueStatusProvider =
    FutureProvider.family<TaxiTerugQueueStatus?, String>((ref, rideId) async {
  final identity = await ref.watch(riderIdentityProvider.future);
  return ref.read(taxiTerugQueueServiceProvider).fetch(
        rideId,
        riderToken: identity.riderToken,
      );
});
