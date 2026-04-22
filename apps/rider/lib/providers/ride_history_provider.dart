import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

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
      pickupAddress: json['pickup_address'] as String,
      destinationAddress: json['destination_address'] as String,
      fare: (json['fare'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      driverName: driver?['name'] as String?,
      driverPhoto: driver?['photo_url'] as String?,
    );
  }
}

class RideHistoryNotifier extends AsyncNotifier<List<RideHistoryItem>> {
  String _currentFilter = 'all';

  @override
  Future<List<RideHistoryItem>> build() async {
    return _loadRides();
  }

  Future<List<RideHistoryItem>> _loadRides() async {
    try {
      final userId = HeyCabySupabase.client.auth.currentUser?.id;
      if (userId == null) return [];

      // Build query with filters applied BEFORE order() to maintain filter builder type
      var query = HeyCabySupabase.client
          .from('rides')
          .select('''
            id,
            status,
            pickup_address,
            destination_address,
            fare,
            created_at,
            completed_at,
            driver:driver_id (
              name,
              photo_url
            )
          ''')
          .eq('rider_id', userId);

      // Apply filter (must be before order() to keep PostgrestFilterBuilder type)
      if (_currentFilter != 'all') {
        if (_currentFilter == 'active') {
          query = query.inFilter('status', ['pending', 'assigned', 'arrived', 'in_progress']);
        } else if (_currentFilter == 'bidding') {
          query = query.eq('status', 'marketplace');
        } else if (_currentFilter == 'completed') {
          query = query.eq('status', 'completed');
        } else if (_currentFilter == 'cancelled') {
          query = query.eq('status', 'cancelled');
        }
      }

      // Apply ordering last
      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => RideHistoryItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> setFilter(String filter) async {
    _currentFilter = filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadRides());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadRides());
  }
}

final rideHistoryProvider =
    AsyncNotifierProvider<RideHistoryNotifier, List<RideHistoryItem>>(
  RideHistoryNotifier.new,
);
