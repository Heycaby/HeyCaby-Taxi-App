import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

enum SavedAddressAddOutcome {
  success,
  limitReached,
  sessionRequired,
  failed,
}

enum SavedAddressUpdateOutcome {
  success,
  notFound,
  sessionRequired,
  failed,
}

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
  Future<bool> _prepareSession() async {
    if (HeyCabySupabase.client.auth.currentUser == null) {
      return false;
    }
    final identity = await ref.read(riderIdentityProvider.future);
    if (!identity.hasSession) {
      return false;
    }
    if (identity.riderToken != null && identity.riderToken!.isNotEmpty) {
      await const RiderSessionService().bindToken(identity.riderToken);
    }
    return true;
  }

  String? _rpcErrorCode(Object? response) {
    if (response is! Map) return 'invalid_response';
    return response['error']?.toString();
  }

  @override
  Future<List<SavedAddress>> build() async {
    final identity = await ref.watch(riderIdentityProvider.future);
    if (!identity.hasSession ||
        HeyCabySupabase.client.auth.currentUser == null) {
      return [];
    }
    return _load();
  }

  Future<List<SavedAddress>> _load() async {
    if (!await _prepareSession()) {
      throw StateError('not_authenticated');
    }
    final response = await HeyCabySupabase.client.rpc(
      'fn_rider_saved_addresses_list',
    );
    if (response is! Map || response['ok'] != true) {
      throw StateError(_rpcErrorCode(response) ?? 'invalid_response');
    }
    final rows = response['addresses'];
    if (rows is! List) return [];
    return rows
        .map((item) => SavedAddress.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static const int maxSavedAddresses = 10;

  Future<SavedAddressAddOutcome> add({
    required String type,
    required String label,
    required String fullAddress,
    required double latitude,
    required double longitude,
  }) async {
    try {
      if (!await _prepareSession()) {
        return SavedAddressAddOutcome.sessionRequired;
      }
      final response = await HeyCabySupabase.client.rpc(
        'fn_rider_saved_address_add',
        params: {
          'p_type': type,
          'p_label': label,
          'p_full_address': fullAddress,
          'p_latitude': latitude,
          'p_longitude': longitude,
        },
      );
      if (response is! Map || response['ok'] != true) {
        final code = _rpcErrorCode(response);
        if (code == 'limit_reached') {
          return SavedAddressAddOutcome.limitReached;
        }
        if (code == 'not_authenticated' || code == 'rider_identity_not_found') {
          return SavedAddressAddOutcome.sessionRequired;
        }
        throw StateError(code ?? 'invalid_response');
      }
      state = const AsyncLoading();
      state = await AsyncValue.guard(_load);
      return SavedAddressAddOutcome.success;
    } catch (e, st) {
      state = AsyncError(e, st);
      return SavedAddressAddOutcome.failed;
    }
  }

  Future<SavedAddressUpdateOutcome> updateAddress({
    required String addressId,
    required String type,
    required String label,
    required String fullAddress,
    required double latitude,
    required double longitude,
  }) async {
    try {
      if (!await _prepareSession()) {
        return SavedAddressUpdateOutcome.sessionRequired;
      }
      final response = await HeyCabySupabase.client.rpc(
        'fn_rider_saved_address_update',
        params: {
          'p_saved_address_id': addressId,
          'p_type': type,
          'p_label': label,
          'p_full_address': fullAddress,
          'p_latitude': latitude,
          'p_longitude': longitude,
        },
      );
      if (response is! Map || response['ok'] != true) {
        final code = _rpcErrorCode(response);
        if (code == 'address_not_found') {
          return SavedAddressUpdateOutcome.notFound;
        }
        if (code == 'not_authenticated' || code == 'rider_identity_not_found') {
          return SavedAddressUpdateOutcome.sessionRequired;
        }
        throw StateError(code ?? 'invalid_response');
      }
      state = const AsyncLoading();
      state = await AsyncValue.guard(_load);
      return SavedAddressUpdateOutcome.success;
    } catch (e, st) {
      state = AsyncError(e, st);
      return SavedAddressUpdateOutcome.failed;
    }
  }

  Future<void> remove(String addressId) async {
    try {
      if (!await _prepareSession()) {
        throw StateError('not_authenticated');
      }
      final response = await HeyCabySupabase.client.rpc(
        'fn_rider_saved_address_delete',
        params: {'p_saved_address_id': addressId},
      );
      if (response is! Map || response['ok'] != true) {
        throw StateError(_rpcErrorCode(response) ?? 'invalid_response');
      }
      state = const AsyncLoading();
      state = await AsyncValue.guard(_load);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> refresh() async {
    final identity = await ref.read(riderIdentityProvider.future);
    if (!identity.hasSession ||
        HeyCabySupabase.client.auth.currentUser == null) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final savedAddressesProvider =
    AsyncNotifierProvider<SavedAddressesNotifier, List<SavedAddress>>(
  SavedAddressesNotifier.new,
);
