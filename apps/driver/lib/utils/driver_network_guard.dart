import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_connectivity_provider.dart';

/// Blocks actions that require network when offline (Program 3E).
Future<bool> ensureDriverNetworkForAction(
  BuildContext context,
  WidgetRef ref,
) async {
  final status = ref.read(driverConnectivityProvider);
  if (isDriverNetworkOnline(status)) return true;
  if (!context.mounted) return false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(DriverStrings.connectivityOfflineActionBlocked)),
  );
  return false;
}

bool isDriverNetworkOnlineFromRef(WidgetRef ref) =>
    isDriverNetworkOnline(ref.read(driverConnectivityProvider));
