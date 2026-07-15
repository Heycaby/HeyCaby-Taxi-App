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
    final driver = json['driver'] is Map
        ? Map<String, dynamic>.from(json['driver'] as Map)
        : null;
    final createdAt = _parseRideTimestamp(json['created_at']);
    if (createdAt == null) {
      throw const FormatException('missing created_at');
    }
    return RideHistoryItem(
      id: json['id'] as String,
      status: json['status'] as String,
      pickupAddress: (json['pickup_address'] as String?) ?? '',
      destinationAddress: (json['destination_address'] as String?) ?? '',
      fare: (json['fare'] as num?)?.toDouble(),
      createdAt: createdAt,
      completedAt: _parseRideTimestamp(json['completed_at']),
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

DateTime? _parseRideTimestamp(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

Map<String, dynamic>? _driverMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

RideHistoryItem? _rideHistoryItemFromRow(Map<String, dynamic> row) {
  final id = row['id']?.toString();
  if (id == null || id.isEmpty) return null;

  final createdAt = _parseRideTimestamp(row['created_at']);
  if (createdAt == null) return null;

  final driver = _driverMap(row['driver']);
  return RideHistoryItem(
    id: id,
    status: _displayStatus(row),
    pickupAddress: (row['pickup_address'] as String?) ?? '',
    destinationAddress: (row['destination_address'] as String?) ?? '',
    fare: HeyCabyRideFare.resolveTotalEuroFromRow(row),
    createdAt: createdAt,
    completedAt: _parseRideTimestamp(row['completed_at']),
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
  var items = <RideHistoryItem>[];
  for (final raw in rows) {
    try {
      final item = _rideHistoryItemFromRow(raw);
      if (item != null) items.add(item);
    } catch (_) {
      // Skip malformed rows instead of failing the whole Rides tab.
    }
  }

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
    try {
      return await fetchRideHistoryItems(
        identity: identity,
        filter: _currentFilter,
      );
    } catch (_) {
      return const [];
    }
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
