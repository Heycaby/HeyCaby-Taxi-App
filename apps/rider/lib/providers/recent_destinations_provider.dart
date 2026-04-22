import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_models/heycaby_models.dart';

class RecentDestination {
  final String id;
  final String fullAddress;
  final double lat;
  final double lng;
  final DateTime usedAt;

  const RecentDestination({
    required this.id,
    required this.fullAddress,
    required this.lat,
    required this.lng,
    required this.usedAt,
  });

  factory RecentDestination.fromJson(Map<String, dynamic> json) {
    DateTime usedAt;
    final rawUsed = json['used_at'];
    if (rawUsed != null) {
      usedAt = DateTime.parse(rawUsed as String);
    } else {
      final rawCreated = json['created_at'];
      usedAt = rawCreated != null
          ? DateTime.parse(rawCreated as String)
          : DateTime.now();
    }
    return RecentDestination(
      id: json['id'] as String,
      fullAddress: json['full_address'] as String,
      lat: (json['latitude'] as num).toDouble(),
      lng: (json['longitude'] as num).toDouble(),
      usedAt: usedAt,
    );
  }
}

const int kRecentDestinationsMaxStored = 10;

class RecentDestinationsNotifier
    extends AsyncNotifier<List<RecentDestination>> {
  @override
  Future<List<RecentDestination>> build() async {
    return _loadDestinations();
  }

  Future<String?> _resolveRiderIdentityId() async {
    final supabase = HeyCabySupabase.client;
    final userId = supabase.auth.currentUser?.id;
    String? identityId;
    if (userId != null) {
      final identityResponse = await supabase
          .from('rider_identities')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      identityId = identityResponse?['id'] as String?;
    }
    if (identityId == null) {
      final identity = await ref.read(riderIdentityProvider.future);
      identityId = identity.identityId;
    }
    if (identityId == null || identityId.isEmpty) return null;
    return identityId;
  }

  Future<void> _enforceRecentCap(String identityId) async {
    try {
      final supabase = HeyCabySupabase.client;
      final response = await supabase
          .from('saved_addresses')
          .select('id')
          .eq('rider_identity_id', identityId)
          .eq('type', 'recent')
          .order('used_at', ascending: false);

      final list = response as List<dynamic>;
      if (list.length <= kRecentDestinationsMaxStored) return;
      final excess = list.sublist(kRecentDestinationsMaxStored);
      final ids = excess
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toList();
      if (ids.isEmpty) return;
      await supabase.from('saved_addresses').delete().inFilter('id', ids);
    } catch (_) {}
  }

  Future<List<RecentDestination>> _loadDestinations() async {
    try {
      final supabase = HeyCabySupabase.client;
      final identityId = await _resolveRiderIdentityId();
      if (identityId == null) return [];

      // Fetch recent destinations from saved_addresses table
      final response = await supabase
          .from('saved_addresses')
          .select('id, full_address, latitude, longitude, used_at, created_at')
          .eq('rider_identity_id', identityId)
          .eq('type', 'recent')
          .order('used_at', ascending: false)
          .limit(kRecentDestinationsMaxStored);

      return (response as List)
          .map((json) => RecentDestination.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadDestinations());
  }

  /// Removes one server-backed recent row (`saved_addresses.type == recent`).
  Future<bool> removeDestination(String destinationId) async {
    try {
      final identityId = await _resolveRiderIdentityId();
      if (identityId == null) return false;
      final supabase = HeyCabySupabase.client;
      await supabase
          .from('saved_addresses')
          .delete()
          .eq('id', destinationId)
          .eq('rider_identity_id', identityId)
          .eq('type', 'recent');
      state = await AsyncValue.guard(() => _loadDestinations());
      return !state.hasError;
    } catch (_) {
      return false;
    }
  }

  /// Record a destination as recently used
  Future<void> recordDestination({
    required String fullAddress,
    required double lat,
    required double lng,
  }) async {
    try {
      final supabase = HeyCabySupabase.client;
      final identityId = await _resolveRiderIdentityId();
      if (identityId == null) return;

      // Check if this address already exists
      final existing = await supabase
          .from('saved_addresses')
          .select('id')
          .eq('rider_identity_id', identityId)
          .eq('full_address', fullAddress)
          .maybeSingle();

      if (existing != null) {
        // Update used_at timestamp
        await supabase
            .from('saved_addresses')
            .update({'used_at': DateTime.now().toIso8601String()})
            .eq('id', existing['id'] as String);
      } else {
        // Insert new recent destination
        await supabase.from('saved_addresses').insert({
          'rider_identity_id': identityId,
          'type': 'recent',
          'label': fullAddress.split(',').first,
          'full_address': fullAddress,
          'latitude': lat,
          'longitude': lng,
          'used_at': DateTime.now().toIso8601String(),
        });
      }

      await _enforceRecentCap(identityId);

      // Refresh the list
      await refresh();
    } catch (_) {}
  }

  /// Saves pickup and drop-off as `saved_addresses` rows (type `recent`) when possible.
  Future<void> recordTripForLater({
    required AddressResult pickup,
    required AddressResult destination,
  }) async {
    await recordDestination(
      fullAddress: pickup.fullAddress,
      lat: pickup.lat,
      lng: pickup.lng,
    );
    await recordDestination(
      fullAddress: destination.fullAddress,
      lat: destination.lat,
      lng: destination.lng,
    );
  }
}

final recentDestinationsProvider = AsyncNotifierProvider<
    RecentDestinationsNotifier, List<RecentDestination>>(
  RecentDestinationsNotifier.new,
);
