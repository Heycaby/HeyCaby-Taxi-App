import 'package:heycaby_api/heycaby_api.dart';

import '../l10n/driver_strings.dart';

/// Maps ride lifecycle failures to explicit driver-facing copy (never generic).
String driverRideLifecycleErrorMessage(Object error) {
  final parsed = _parseLifecycleError(error);
  final lifecycle = DriverStrings.rideLifecycleErrorMessage(
    parsed.code,
    detail: parsed.detail,
  );
  if (!_isGenericLifecycleFallback(lifecycle)) return lifecycle;

  final accept = DriverStrings.acceptRideErrorMessage(parsed.code);
  if (!_isGenericAcceptFallback(accept)) return accept;

  return DriverStrings.rideLifecycleErrorExplicit(parsed.code);
}

class _ParsedLifecycleError {
  const _ParsedLifecycleError({required this.code, this.detail});

  final String code;
  final String? detail;
}

_ParsedLifecycleError _parseLifecycleError(Object error) {
  if (error is DriverRideLifecycleException) {
    return _ParsedLifecycleError(
      code: _normalizeLifecycleErrorCode(error.code, detail: error.message),
      detail: error.message,
    );
  }
  final raw = error.toString();
  return _ParsedLifecycleError(
    code: _normalizeLifecycleErrorCode(raw, detail: raw),
    detail: raw,
  );
}

bool _isGenericLifecycleFallback(String message) =>
    message == DriverStrings.rideActionFailedMessage;

bool _isGenericAcceptFallback(String message) =>
    message == DriverStrings.acceptRideFailedMessage ||
    message == DriverStrings.rideActionFailedMessage;

String _normalizeLifecycleErrorCode(String raw, {String? detail}) {
  final sources = <String>[
    if (detail != null && detail.trim().isNotEmpty) detail.trim(),
    raw.trim(),
  ];

  const knownCodes = [
    'driver_business_account_not_found',
    'driver_location_unavailable',
    'target_location_unavailable',
    'too_far_from_pickup',
    'too_far_from_dropoff',
    'invalid_transition',
    'not_a_driver',
    'proximity_unavailable',
    'ride_not_found',
    'ride_not_completed',
    'missing_ride_request_id',
    'missing_ride_id',
    'invalid_rating',
    'missing_rider_token',
    'invalid_action',
    'invalid_cancel_reason',
    'invalid_paid_amount',
    'invalid_amount',
    'no_valid_invite',
    'not_authorized',
    'terminal_ride',
    'ride_cancelled',
    'network_unreachable',
    'request_timeout',
    'server_unreachable',
    'rpc_failed',
    'rpc_error',
    'rpc_unavailable',
  ];

  for (final source in sources) {
    final lower = source.toLowerCase();
    for (final code in knownCodes) {
      if (lower.contains(code)) return code;
    }
  }

  final head = raw.split(':').first.trim();
  return head.isNotEmpty ? head : 'unknown_error';
}
