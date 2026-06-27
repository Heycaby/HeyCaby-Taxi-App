import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import 'driver_runtime_providers.dart';

/// Driver Grow / invite share URL — from runtime `config.links` (website fallback).
final driverInviteShareUrlProvider = Provider<String>((ref) {
  final config = ref.watch(driverRemoteConfigProvider).valueOrNull;
  if (config != null) return config.links.driverInviteShareUrl();
  return appPublicLinks.current.driverInviteShareUrl();
});

final driverInviteShareReadyProvider = Provider<bool>((ref) {
  final config = ref.watch(driverRemoteConfigProvider).valueOrNull;
  if (config != null) return config.links.driverInviteShareReady;
  return appPublicLinks.current.driverInviteShareReady;
});
