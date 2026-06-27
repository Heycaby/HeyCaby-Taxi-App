import '../constants/driver_progressive_verification.dart';
import '../l10n/driver_strings.dart';
import '../models/driver_runtime_models.dart';
import '../screens/driver_runtime_gate_screen.dart';

class DriverRuntimeDecisionMapper {
  static DriverRuntimeGateArgs fromReadiness(DriverReadinessState readiness) {
    final blocking = readiness.missingItems;
    final body = readiness.completedRides < kDriverProgressiveVerificationStartsAt
        ? DriverStrings.runtimeGoOnlineEarlyOnboardingBody
        : (readiness.statusMessage ?? DriverStrings.runtimeComplianceBlockedBody);

    return DriverRuntimeGateArgs(
      title: DriverStrings.runtimeComplianceBlockedTitle,
      body: body,
      ctaLabel: DriverStrings.runtimeOpenDocuments,
      ctaRoute: '/driver/documents',
      secondaryLabel: DriverStrings.me,
      secondaryRoute: '/driver/me',
      checklist: blocking,
    );
  }

  static DriverRuntimeGateArgs fromStatusDecision(DriverStatusDecision decision) {
    final reason = decision.blockedReason ?? '';
    if (reason == 'payment_required') {
      return DriverRuntimeGateArgs(
        title: DriverStrings.runtimePaymentBlockedTitle,
        body: decision.message ?? DriverStrings.runtimePaymentBlockedBody,
        ctaLabel: DriverStrings.runtimeOpenBilling,
        ctaRoute: '/driver/billing',
      );
    }
    return DriverRuntimeGateArgs(
      title: DriverStrings.runtimeUnknownBlockedTitle,
      body: decision.message ?? DriverStrings.runtimeUnknownBlockedBody,
      ctaLabel: DriverStrings.runtimeOpenDocuments,
      ctaRoute: '/driver/documents',
    );
  }

  static DriverRuntimeGateArgs complianceFallback() {
    return const DriverRuntimeGateArgs(
      title: DriverStrings.runtimeComplianceBlockedTitle,
      body: DriverStrings.runtimeComplianceBlockedBody,
      ctaLabel: DriverStrings.runtimeOpenDocuments,
      ctaRoute: '/driver/documents',
      secondaryLabel: DriverStrings.me,
      secondaryRoute: '/driver/me',
    );
  }
}
