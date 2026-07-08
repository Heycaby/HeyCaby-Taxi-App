import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';

class SavedTrip {
  final String id;
  final String riderIdentityId;
  final String label;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String destinationAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final DateTime createdAt;
  final DateTime? usedAt;

  const SavedTrip({
    required this.id,
    required this.riderIdentityId,
    required this.label,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.createdAt,
    this.usedAt,
  });

  factory SavedTrip.fromJson(Map<String, dynamic> json) => SavedTrip(
        id: json['id'] as String,
        riderIdentityId: json['rider_identity_id'] as String,
        label: (json['label'] as String?) ?? '',
        pickupAddress: json['pickup_address'] as String,
        pickupLatitude: (json['pickup_latitude'] as num).toDouble(),
        pickupLongitude: (json['pickup_longitude'] as num).toDouble(),
        destinationAddress: json['destination_address'] as String,
        destinationLatitude: (json['destination_latitude'] as num).toDouble(),
        destinationLongitude: (json['destination_longitude'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        usedAt: json['used_at'] != null
            ? DateTime.parse(json['used_at'] as String)
            : null,
      );

  AddressResult get pickup => AddressResult(
        displayName: pickupAddress.split(',').first.trim(),
        fullAddress: pickupAddress,
        lat: pickupLatitude,
        lng: pickupLongitude,
      );

  AddressResult get destination => AddressResult(
        displayName: destinationAddress.split(',').first.trim(),
        fullAddress: destinationAddress,
        lat: destinationLatitude,
        lng: destinationLongitude,
      );
}

const int kSavedTripsMax = 12;

class SavedTripsNotifier extends AsyncNotifier<List<SavedTrip>> {
  @override
  Future<List<SavedTrip>> build() async {
    return _load();
  }

  Future<String?> _resolveIdentityId() async {
    final supabase = HeyCabySupabase.client;
    final userId = supabase.auth.currentUser?.id;
    String? identityId;
    if (userId != null) {
      final resp = await supabase
          .from('rider_identities')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      identityId = resp?['id'] as String?;
    }
    if (identityId == null) {
      final identity = await ref.read(riderIdentityProvider.future);
      identityId = identity.identityId;
    }
    return (identityId == null || identityId.isEmpty) ? null : identityId;
  }

  Future<List<SavedTrip>> _load() async {
    try {
      final identityId = await _resolveIdentityId();
      if (identityId == null) return [];

      final response = await HeyCabySupabase.client
          .from('saved_trips')
          .select()
          .eq('rider_identity_id', identityId)
          .order('used_at', ascending: false, nullsFirst: true)
          .limit(kSavedTripsMax);

      return (response as List)
          .map((json) => SavedTrip.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTrip({
    required AddressResult pickup,
    required AddressResult destination,
  }) async {
    try {
      final identityId = await _resolveIdentityId();
      if (identityId == null) return;

      final pickupLabel = pickup.displayName;
      final destLabel = destination.displayName;
      final label = '$pickupLabel → $destLabel';

      final existing = await HeyCabySupabase.client
          .from('saved_trips')
          .select('id')
          .eq('rider_identity_id', identityId)
          .eq('pickup_address', pickup.fullAddress)
          .eq('destination_address', destination.fullAddress)
          .maybeSingle();

      if (existing != null) {
        await HeyCabySupabase.client
            .from('saved_trips')
            .update({'used_at': DateTime.now().toIso8601String()})
            .eq('id', existing['id'] as String);
      } else {
        await HeyCabySupabase.client.from('saved_trips').insert({
          'rider_identity_id': identityId,
          'label': label,
          'pickup_address': pickup.fullAddress,
          'pickup_latitude': pickup.lat,
          'pickup_longitude': pickup.lng,
          'destination_address': destination.fullAddress,
          'destination_latitude': destination.lat,
          'destination_longitude': destination.lng,
          'used_at': DateTime.now().toIso8601String(),
        });
      }

      await _enforceCap(identityId);
      state = await AsyncValue.guard(() => _load());
    } catch (_) {}
  }

  Future<void> _enforceCap(String identityId) async {
    try {
      final response = await HeyCabySupabase.client
          .from('saved_trips')
          .select('id')
          .eq('rider_identity_id', identityId)
          .order('used_at', ascending: false, nullsFirst: true);

      final list = response as List<dynamic>;
      if (list.length <= kSavedTripsMax) return;
      final excess = list.sublist(kSavedTripsMax);
      final ids = excess
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toList();
      if (ids.isEmpty) return;
      await HeyCabySupabase.client
          .from('saved_trips')
          .delete()
          .inFilter('id', ids);
    } catch (_) {}
  }

  Future<bool> removeTrip(String tripId) async {
    try {
      await HeyCabySupabase.client
          .from('saved_trips')
          .delete()
          .eq('id', tripId);
      state = await AsyncValue.guard(() => _load());
      return !state.hasError;
    } catch (_) {
      return false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load());
  }
}

final savedTripsProvider =
    AsyncNotifierProvider<SavedTripsNotifier, List<SavedTrip>>(
  SavedTripsNotifier.new,
);
