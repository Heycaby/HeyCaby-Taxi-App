import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

class FavoriteDriver {
  final String id;
  final String driverId;
  final String name;
  final String? photo;
  final double rating;
  final int totalRides;
  final DateTime addedAt;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColour;
  final String? vehiclePlate;
  final String driverStatus;
  final bool isAvailable;
  final DateTime? lastRideCompletedAt;

  const FavoriteDriver({
    required this.id,
    required this.driverId,
    required this.name,
    this.photo,
    required this.rating,
    required this.totalRides,
    required this.addedAt,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColour,
    this.vehiclePlate,
    this.driverStatus = 'offline',
    this.isAvailable = false,
    this.lastRideCompletedAt,
  });

  String get vehicleDescription {
    final parts = <String>[];
    if (vehicleColour != null && vehicleColour!.isNotEmpty) {
      parts.add(vehicleColour!);
    }
    if (vehicleMake != null && vehicleMake!.isNotEmpty) {
      parts.add(vehicleMake!);
    }
    if (vehicleModel != null && vehicleModel!.isNotEmpty) {
      parts.add(vehicleModel!);
    }
    return parts.isEmpty ? '' : parts.join(' ');
  }

  factory FavoriteDriver.fromJson(Map<String, dynamic> json) => FavoriteDriver(
        id: json['id'] as String,
        driverId: json['driver_id'] as String,
        name: (json['driver_name'] as String?) ?? '',
        photo: json['driver_photo'] as String?,
        rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
        totalRides: (json['total_rides'] as num?)?.toInt() ?? 0,
        addedAt: DateTime.parse(json['created_at'] as String),
        vehicleMake: json['vehicle_make'] as String?,
        vehicleModel: json['vehicle_model'] as String?,
        vehicleColour: json['vehicle_colour'] as String?,
        vehiclePlate: json['vehicle_plate'] as String?,
        driverStatus: (json['driver_status'] as String?) ?? 'offline',
        isAvailable: (json['is_available'] as bool?) ?? false,
        lastRideCompletedAt: json['last_ride_completed_at'] != null
            ? DateTime.tryParse(json['last_ride_completed_at'] as String)
            : null,
      );
}

class AddFavoriteResult {
  final bool success;
  final String? favoriteId;
  final String? reason;

  const AddFavoriteResult({
    required this.success,
    this.favoriteId,
    this.reason,
  });

  factory AddFavoriteResult.fromJson(Map<String, dynamic> json) =>
      AddFavoriteResult(
        success: json['success'] as bool? ?? false,
        favoriteId: json['favorite_id'] as String?,
        reason: json['reason'] as String?,
      );
}

class FavoritesNotifier extends AsyncNotifier<List<FavoriteDriver>> {
  @override
  Future<List<FavoriteDriver>> build() async {
    final identity = await ref.watch(riderIdentityProvider.future);
    final riderIdentityId = identity.identityId;
    if (riderIdentityId == null || riderIdentityId.isEmpty) {
      return [];
    }
    return _loadFavorites(riderIdentityId);
  }

  Future<List<FavoriteDriver>> _loadFavorites(String riderIdentityId) async {
    final response = await HeyCabySupabase.client.rpc(
      'fn_rider_favorite_drivers',
      params: {'p_rider_identity_id': riderIdentityId},
    );

    final data = Map<String, dynamic>.from(response as Map);
    if (data['success'] != true) {
      throw StateError(
        'Favorite drivers could not be loaded: ${data['reason'] ?? 'unknown'}',
      );
    }

    final drivers = data['drivers'] as List? ?? [];
    return drivers
        .map((item) => FavoriteDriver.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .where((d) => d.name.isNotEmpty)
        .toList();
  }

  Future<AddFavoriteResult> addFavorite({
    required String rideRequestId,
    required String driverId,
    String? riderToken,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_ride_request_id': rideRequestId,
        'p_driver_id': driverId,
      };
      final token = riderToken?.trim();
      if (token != null && token.isNotEmpty) {
        params['p_rider_token'] = token;
      }
      final response = await HeyCabySupabase.client.rpc(
        'fn_rider_add_favorite_driver',
        params: params,
      );

      final result = AddFavoriteResult.fromJson(
        Map<String, dynamic>.from(response as Map),
      );

      if (result.success) {
        final identity = await ref.read(riderIdentityProvider.future);
        final riderIdentityId = identity.identityId;
        if (riderIdentityId != null && riderIdentityId.isNotEmpty) {
          // Defer list refresh so modal dismiss / route transitions are not
          // interrupted by a synchronous home-tab rebuild.
          Future.microtask(() async {
            state = await AsyncValue.guard(
              () => _loadFavorites(riderIdentityId),
            );
          });
        }
      }

      return result;
    } catch (e) {
      return const AddFavoriteResult(success: false, reason: 'network_error');
    }
  }

  Future<bool> removeFavorite(String driverId) async {
    final identity = await ref.read(riderIdentityProvider.future);
    final riderIdentityId = identity.identityId;
    if (riderIdentityId == null || riderIdentityId.isEmpty) return false;

    try {
      final response = await HeyCabySupabase.client.rpc(
        'fn_rider_remove_favorite_driver',
        params: {
          'p_rider_identity_id': riderIdentityId,
          'p_driver_id': driverId,
        },
      );

      final data = Map<String, dynamic>.from(response as Map);
      final success = data['success'] as bool? ?? false;

      if (success) {
        state = const AsyncLoading();
        state = await AsyncValue.guard(() => _loadFavorites(riderIdentityId));
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  Future<void> refresh() async {
    final identity = await ref.read(riderIdentityProvider.future);
    final riderIdentityId = identity.identityId;
    if (riderIdentityId == null || riderIdentityId.isEmpty) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadFavorites(riderIdentityId));
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<FavoriteDriver>>(
  FavoritesNotifier.new,
);
