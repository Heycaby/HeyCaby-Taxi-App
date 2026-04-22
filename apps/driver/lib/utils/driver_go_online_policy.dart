import '../services/driver_data_service.dart';
import 'driver_compliance_ui.dart' show veriffDecisionLooksApproved;

/// Going online is gated **only** on a manually confirmed driving licence
/// (`rijbewijs_verified` in `drivers`). Other documents may still be pending ops review.
///
/// Veriff alone does not unlock online — operations sets `rijbewijs_verified` after review.
bool driverMayGoOnline(
  DriverComplianceSnapshot? c, {
  bool isReviewAccount = false,
}) {
  if (isReviewAccount) return true;
  if (c == null) return false;
  return c.rijbewijsVerified == true;
}

/// Veriff returned a positive decision, but licence not yet confirmed in `drivers`.
bool driverLicenceAwaitingManualReview(DriverComplianceSnapshot? c) {
  if (c == null) return false;
  if (c.rijbewijsVerified == true) return false;
  return veriffDecisionLooksApproved(c.veriffStatus);
}
