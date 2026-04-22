import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'rider_local_recent_addresses_v1';

/// Max entries kept on device for address search (MRU).
const int kMaxLocalRecentAddresses = 10;

/// Substring match on [query] (trimmed, lowercased), min 3 chars — same rule as map search.
List<AddressResult> filterLocalRecentsByQuery(
  List<AddressResult> stored,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.length < 3) return [];
  return stored.where((e) {
    final dn = e.displayName.toLowerCase();
    final fa = e.fullAddress.toLowerCase();
    return dn.contains(q) || fa.contains(q);
  }).toList();
}

class LocalRecentAddressesNotifier extends AsyncNotifier<List<AddressResult>> {
  @override
  Future<List<AddressResult>> build() => _load();

  Future<List<AddressResult>> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              AddressResult.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(List<AddressResult> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefsKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    state = AsyncData(items);
  }

  /// Dedupes by normalized [fullAddress], MRU order, cap [kMaxLocalRecentAddresses].
  Future<void> record(AddressResult r) async {
    if (r.fullAddress.trim().isEmpty) return;
    final current = state.valueOrNull ?? await _load();
    final norm = r.fullAddress.trim().toLowerCase();
    final filtered = current
        .where((e) => e.fullAddress.trim().toLowerCase() != norm)
        .toList();
    final next =
        [r, ...filtered].take(kMaxLocalRecentAddresses).toList();
    await _persist(next);
  }

  List<AddressResult> matchingQuery(String query) {
    return filterLocalRecentsByQuery(state.valueOrNull ?? [], query);
  }

  Future<void> refreshFromDisk() async {
    state = const AsyncLoading();
    state = AsyncValue.data(await _load());
  }
}

final localRecentAddressesProvider =
    AsyncNotifierProvider<LocalRecentAddressesNotifier, List<AddressResult>>(
  LocalRecentAddressesNotifier.new,
);
