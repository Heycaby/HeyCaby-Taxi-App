import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../constants/rider_rides_status_contract.dart';
import '../services/rider_my_rides_service.dart';

class RideHistoryItem {
  final String id;
  final String status;
  final String pickupAddress;
  final String destinationAddress;
  final double? fare;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? driverName;
  final String? driverPhoto;

  const RideHistoryItem({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    this.fare,
    required this.createdAt,
    this.completedAt,
    this.driverName,
    this.driverPhoto,
  });

  factory RideHistoryItem.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;
    return RideHistoryItem(
      id: json['id'] as String,
      status: json['status'] as String,
      pickupAddress: (json['pickup_address'] as String?) ?? '',
      destinationAddress: (json['destination_address'] as String?) ?? '',
      fare: (json['fare'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      driverName: (driver?['full_name'] ?? driver?['name']) as String?,
      driverPhoto:
          (driver?['profile_photo_url'] ?? driver?['photo_url']) as String?,
    );
  }
}

String _displayStatus(Map<String, dynamic> row) {
  final status = (row['status'] as String?)?.trim() ?? '';
  final bookingMode = (row['booking_mode'] as String?)?.trim().toLowerCase();
  if (status == 'bidding' && bookingMode == 'marketplace') {
    return 'marketplace';
  }
  return status;
}

RideHistoryItem _rideHistoryItemFromRow(Map<String, dynamic> row) {
  final driver = row['driver'] as Map<String, dynamic>?;
  return RideHistoryItem(
    id: row['id'] as String,
    status: _displayStatus(row),
    pickupAddress: (row['pickup_address'] as String?) ?? '',
    destinationAddress: (row['destination_address'] as String?) ?? '',
    fare: HeyCabyRideFare.resolveTotalEuroFromRow(row),
    createdAt: DateTime.parse(row['created_at'] as String),
    completedAt: row['completed_at'] != null
        ? DateTime.tryParse(row['completed_at'] as String)
        : null,
    driverName: driver?['full_name'] as String?,
    driverPhoto: driver?['profile_photo_url'] as String?,
  );
}

Future<List<RideHistoryItem>> fetchRideHistoryItems({
  required RiderIdentityState identity,
  String filter = 'all',
  int? limit,
}) async {
  if (!identity.hasSession) {
    return [];
  }

  final rows = await const RiderMyRidesService().fetchAll(scope: 'history');
  var items = rows.map(_rideHistoryItemFromRow).toList();

  switch (filter) {
    case 'completed':
      items = items.where((ride) => ride.status == 'completed').toList();
      break;
    case 'cancelled':
      items = items
          .where((ride) => riderCancelledHistoryStatuses.contains(ride.status))
          .toList();
      break;
  }

  return limit == null ? items : items.take(limit).toList();
}

class RideHistoryNotifier extends AsyncNotifier<List<RideHistoryItem>> {
  String _currentFilter = 'all';

  @override
  Future<List<RideHistoryItem>> build() async {
    final identity = await ref.watch(riderIdentityProvider.future);
    return fetchRideHistoryItems(identity: identity, filter: _currentFilter);
  }

  Future<void> setFilter(String filter) async {
    _currentFilter = filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final identity = await ref.read(riderIdentityProvider.future);
      return fetchRideHistoryItems(identity: identity, filter: filter);
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final identity = await ref.read(riderIdentityProvider.future);
      return fetchRideHistoryItems(identity: identity, filter: _currentFilter);
    });
  }

  Future<List<RideHistoryItem>> loadWithFilter(
    String filter, {
    int limit = 40,
  }) async {
    final identity = await ref.read(riderIdentityProvider.future);
    return fetchRideHistoryItems(
      identity: identity,
      filter: filter,
      limit: limit,
    );
  }
}

final rideHistoryProvider =
    AsyncNotifierProvider<RideHistoryNotifier, List<RideHistoryItem>>(
  RideHistoryNotifier.new,
);
