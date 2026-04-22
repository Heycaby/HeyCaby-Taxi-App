import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

enum SavedAddressAddOutcome { success, limitReached, failed }

class SavedAddress {
  final String id;
  final String riderIdentityId;
  final String type; // home, work, gym, custom, etc.
  final String label;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  const SavedAddress({
    required this.id,
    required this.riderIdentityId,
    required this.type,
    required this.label,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        id: json['id'] as String,
        riderIdentityId: json['rider_identity_id'] as String,
        type: json['type'] as String? ?? 'custom',
        label: json['label'] as String,
        fullAddress: json['full_address'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class SavedAddressesNotifier extends AsyncNotifier<List<SavedAddress>> {
  @override
  Future<List<SavedAddress>> build() async {
    final identity = await ref.watch(riderIdentityProvider.future);
    final riderIdentityId = identity.identityId;
    if (riderIdentityId == null || riderIdentityId.isEmpty) {
      return [];
    }
    return _load(riderIdentityId);
  }

  Future<List<SavedAddress>> _load(String riderIdentityId) async {
    try {
      final response = await HeyCabySupabase.client
          .from('saved_addresses')
          .select('id, rider_identity_id, type, label, full_address, latitude, longitude, created_at')
          .eq('rider_identity_id', riderIdentityId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((item) => SavedAddress.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static const int maxSavedAddresses = 10;

  Future<SavedAddressAddOutcome> add({
    required String riderIdentityId,
    required String type,
    required String label,
    required String fullAddress,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final existing = await _load(riderIdentityId);
      if (existing.length >= maxSavedAddresses) {
        return SavedAddressAddOutcome.limitReached;
      }
      await HeyCabySupabase.client.from('saved_addresses').insert({
        'rider_identity_id': riderIdentityId,
        'type': type,
        'label': label,
        'full_address': fullAddress,
        'latitude': latitude,
        'longitude': longitude,
      });
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _load(riderIdentityId));
      return SavedAddressAddOutcome.success;
    } catch (e, st) {
      state = AsyncError(e, st);
      return SavedAddressAddOutcome.failed;
    }
  }

  Future<void> remove(String addressId) async {
    final identity = await ref.read(riderIdentityProvider.future);
    final riderIdentityId = identity.identityId;
    if (riderIdentityId == null || riderIdentityId.isEmpty) return;
    try {
      await HeyCabySupabase.client
          .from('saved_addresses')
          .delete()
          .eq('id', addressId);
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _load(riderIdentityId));
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
    state = await AsyncValue.guard(() => _load(riderIdentityId));
  }
}

final savedAddressesProvider =
    AsyncNotifierProvider<SavedAddressesNotifier, List<SavedAddress>>(
  SavedAddressesNotifier.new,
);
