import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';

/// Matches Xcode / Podfile minimum iOS for HeyCaby apps.
const int kHeyCabyMinimumIosMajorVersion = 18;

/// When non-null, the device is iOS and below [minimumMajor].
class IosBelowMinimumResult {
  const IosBelowMinimumResult({
    required this.systemVersion,
    required this.majorVersion,
  });

  /// Full string from `UIDevice.systemVersion` (e.g. `17.6.1`).
  final String systemVersion;

  final int majorVersion;
}

int? _majorFromSystemVersion(String v) {
  final part = v.split('.').first.trim();
  if (part.isEmpty) return null;
  return int.tryParse(part);
}

/// Returns a result only on **iOS** when major version is below [minimumMajor].
Future<IosBelowMinimumResult?> checkIosBelowMinimum({
  int minimumMajor = kHeyCabyMinimumIosMajorVersion,
}) async {
  if (!Platform.isIOS) return null;
  final ios = await DeviceInfoPlugin().iosInfo;
  final major = _majorFromSystemVersion(ios.systemVersion) ?? 0;
  if (major >= minimumMajor) return null;
  return IosBelowMinimumResult(
    systemVersion: ios.systemVersion,
    majorVersion: major,
  );
}
