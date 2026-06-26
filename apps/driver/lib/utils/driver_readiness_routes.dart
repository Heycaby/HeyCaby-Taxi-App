import '../models/driver_runtime_models.dart';

/// Maps Go `/api/v1/driver/readiness` checklist [action] / [key] to Flutter routes.
/// Returns null when there is no dedicated navigation (e.g. review-account row).
String? flutterRouteForReadinessItem(DriverReadinessItem item) {
  final key = item.key.trim();
  if (key == 'review_account') return null;

  final raw = item.action?.trim();
  if (raw != null && raw.isNotEmpty) {
    final route = _routeFromActionPath(raw);
    if (route != null) return route;
  }

  switch (key) {
    case 'profile_photo':
      return '/driver/profile';
    case 'vehicle_photos':
      return '/driver/vehicle';
    case 'terms_of_service':
      return '/driver/terms';
    case 'indemnification_quiz':
      return '/driver/indemnification';
    case 'kvk_number':
    case 'kvk_address':
    case 'chauffeurspas':
    case 'taxi_insurance':
    case 'insurance':
    case 'insurance_policy':
      return '/driver/documents';
    case 'vehicle_plate':
      return '/driver/onboarding/plate';
    case 'rijbewijs_verified':
      return '/driver/veriff';
    default:
      return '/driver/documents';
  }
}

String? _routeFromActionPath(String action) {
  final a = action.toLowerCase();
  if (a.startsWith('/driver/profile')) return '/driver/profile';
  if (a.startsWith('/driver/vehicle')) return '/driver/vehicle';
  if (a.startsWith('/driver/terms')) return '/driver/terms';
  if (a.startsWith('/driver/indemnification')) return '/driver/indemnification';
  if (a.startsWith('/driver/billing')) return '/driver/billing';
  if (a.startsWith('/driver/veriff')) return '/driver/veriff';
  if (a.startsWith('/driver/documents')) return '/driver/documents';
  return null;
}
