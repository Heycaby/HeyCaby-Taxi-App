import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/driver_connectivity_status.dart';

class DriverConnectivityNotifier extends Notifier<DriverConnectivityStatus> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _probeInFlight = false;

  @override
  DriverConnectivityStatus build() {
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
    });
    unawaited(_start());
    return DriverConnectivityStatus.online;
  }

  Future<void> _start() async {
    await _refreshFromSystem();
    _subscription ??= Connectivity().onConnectivityChanged.listen((_) {
      unawaited(_refreshFromSystem());
    });
  }

  Future<void> _refreshFromSystem() async {
    if (_probeInFlight) return;
    _probeInFlight = true;
    try {
      final results = await Connectivity().checkConnectivity();
      state = _mapResults(results);
    } catch (e) {
      if (kDebugMode) debugPrint('DriverConnectivityNotifier: $e');
    } finally {
      _probeInFlight = false;
    }
  }

  DriverConnectivityStatus _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return DriverConnectivityStatus.offline;
    final hasPath = results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );
    return hasPath
        ? DriverConnectivityStatus.online
        : DriverConnectivityStatus.offline;
  }

  /// Manual retry from banner tap or app resume.
  Future<void> refresh() => _refreshFromSystem();
}

final driverConnectivityProvider =
    NotifierProvider<DriverConnectivityNotifier, DriverConnectivityStatus>(
  DriverConnectivityNotifier.new,
);

bool isDriverNetworkOnline(DriverConnectivityStatus status) =>
    status == DriverConnectivityStatus.online;
