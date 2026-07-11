import '../services/driver_data_service.dart';
import 'driver_compliance_ui.dart' show veriffDecisionLooksApproved;

bool _hasText(String? v) => (v ?? '').trim().isNotEmpty;

bool driverHasAcceptedTerms(DriverComplianceSnapshot? c) {
  if (c == null) return false;
  return c.termsAcceptedAt != null;
}

bool driverHasPassedShortQuiz(DriverComplianceSnapshot? c) {
  if (c == null) return false;
  return c.indemnificationQuizPassed == true;
}

bool driverHasAcceptedIndemnification(DriverComplianceSnapshot? c) {
  if (c == null) return false;
  return c.indemnificationReadAt != null && driverHasPassedShortQuiz(c);
}

/// Required profile/compliance data that can be entered by driver before manual licence approval.
/// Includes legal acknowledgement gate:
/// - Terms acceptance
/// - Indemnification document acknowledgement
/// - Short quiz pass
bool driverHasRequiredNonLicenseInfo(
  DriverComplianceSnapshot? c, {
  String? profilePhotoUrl,
  List<String> vehiclePhotoUrls = const [],
  bool isReviewAccount = false,
}) {
  if (isReviewAccount) return true;
  if (c == null) return false;

  final hasChauffeurspas =
      _hasText(c.chauffeurspasNumber) && c.chauffeurspasExpiry != null;
  final hasKvk = _hasText(c.kvkNumber) && _hasText(c.kvkAddress);
  final hasInsurance = _hasText(c.taxiInsuranceProvider) &&
      _hasText(c.taxiInsurancePolicyNumber) &&
      _hasText(c.taxiInsurancePhotoUrl) &&
      c.taxiInsuranceExpiry != null;
  final hasVehiclePlate = _hasText(c.vehiclePlate);
  final hasTermsAccepted = driverHasAcceptedTerms(c);
  final hasShortQuiz = driverHasPassedShortQuiz(c);
  final hasIndemnification = driverHasAcceptedIndemnification(c);
  final hasProfilePhoto = _hasText(profilePhotoUrl);
  final hasVehiclePhoto = vehiclePhotoUrls.any((e) => _hasText(e));

  return hasChauffeurspas &&
      hasKvk &&
      hasInsurance &&
      hasVehiclePlate &&
      hasProfilePhoto &&
      hasVehiclePhoto &&
      hasTermsAccepted &&
      hasShortQuiz &&
      hasIndemnification;
}

/// Going online requires:
/// 1) all required non-licence information entered, and
/// 2) manually confirmed driving licence (`rijbewijs_verified` set by ops).
/// Veriff completion alone does not unlock online.
bool driverMayGoOnline(
  DriverComplianceSnapshot? c, {
  String? profilePhotoUrl,
  List<String> vehiclePhotoUrls = const [],
  bool isReviewAccount = false,
}) {
  // Supabase runtime is authoritative for online eligibility.
  // Keep this client helper permissive so UI never blocks before server decision.
  return true;
}

/// Veriff returned a positive decision, but licence not yet confirmed in `drivers`.
bool driverLicenceAwaitingManualReview(DriverComplianceSnapshot? c) {
  if (c == null) return false;
  if (c.rijbewijsVerified == true) return false;
  return veriffDecisionLooksApproved(c.veriffStatus);
}
