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

  const FavoriteDriver({
    required this.id,
    required this.driverId,
    required this.name,
    this.photo,
    required this.rating,
    required this.totalRides,
    required this.addedAt,
  });

  factory FavoriteDriver.fromJson(Map<String, dynamic> json) => FavoriteDriver(
        id: json['id'] as String,
        driverId: json['driver_id'] as String,
        name: json['driver_name'] as String,
        photo: json['driver_photo'] as String?,
        rating: (json['driver_rating'] as num).toDouble(),
        totalRides: json['driver_total_rides'] as int,
        addedAt: DateTime.parse(json['created_at'] as String),
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
    try {
      final response = await HeyCabySupabase.client
          .from('rider_favorite_drivers')
          .select('''
            id,
            driver_id,
            created_at,
            drivers:driver_id (
              full_name,
              profile_photo_url,
              rating,
              trip_count
            )
          ''')
          .eq('rider_identity_id', riderIdentityId)
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        final driver =
            (item['drivers'] ?? item['driver']) as Map<String, dynamic>?;
        if (driver == null) return null;
        final name = (driver['full_name'] as String?)?.trim();
        if (name == null || name.isEmpty) return null;
        return FavoriteDriver(
          id: item['id'] as String,
          driverId: item['driver_id'] as String,
          name: name,
          photo: driver['profile_photo_url'] as String?,
          rating: (driver['rating'] as num?)?.toDouble() ?? 5.0,
          totalRides: (driver['trip_count'] as num?)?.toInt() ?? 0,
          addedAt: DateTime.parse(item['created_at'] as String),
        );
      }).whereType<FavoriteDriver>().toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addFavorite(String driverId) async {
    final identity = await ref.read(riderIdentityProvider.future);
    final riderIdentityId = identity.identityId;
    if (riderIdentityId == null || riderIdentityId.isEmpty) return;

    try {
      await HeyCabySupabase.client.from('rider_favorite_drivers').insert({
        'rider_identity_id': riderIdentityId,
        'driver_id': driverId,
      });

      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _loadFavorites(riderIdentityId));
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> removeFavorite(String favoriteId) async {
    final identity = await ref.read(riderIdentityProvider.future);
    final riderIdentityId = identity.identityId;
    if (riderIdentityId == null || riderIdentityId.isEmpty) return;

    try {
      await HeyCabySupabase.client
          .from('rider_favorite_drivers')
          .delete()
          .eq('id', favoriteId);

      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _loadFavorites(riderIdentityId));
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
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
