import '../constants/driver_progressive_verification.dart';
import '../l10n/driver_strings.dart';
import '../models/driver_runtime_models.dart';
import '../screens/driver_runtime_gate_screen.dart';
import 'driver_readiness_routes.dart';

class DriverRuntimeDecisionMapper {
  static DriverRuntimeGateArgs fromReadiness(DriverReadinessState readiness) {
    final blocking = readiness.missingItems;
    final primaryBlocker = blocking.isEmpty ? null : blocking.first;
    final body = primaryBlocker == null
        ? DriverStrings.runtimeComplianceBlockedBody
        : _messageForRequirement(primaryBlocker);
    final route = primaryBlocker == null
        ? '/driver/documents'
        : flutterRouteForReadinessItem(primaryBlocker) ?? '/driver/documents';
    final cta = primaryBlocker == null
        ? DriverStrings.runtimeOpenDocuments
        : _ctaForRequirement(primaryBlocker);

    return DriverRuntimeGateArgs(
      title: DriverStrings.runtimeComplianceBlockedTitle,
      body: readiness.completedRides < kDriverProgressiveVerificationStartsAt &&
              primaryBlocker == null
          ? DriverStrings.runtimeGoOnlineEarlyOnboardingBody
          : body,
      ctaLabel: cta,
      ctaRoute: route,
      secondaryLabel: DriverStrings.me,
      secondaryRoute: '/driver/me',
      checklist: blocking,
    );
  }

  static DriverRuntimeGateArgs fromStatusDecision(
      DriverStatusDecision decision) {
    final reason = decision.blockedReason ?? '';
    if (reason == 'payment_required') {
      return DriverRuntimeGateArgs(
        title: DriverStrings.runtimePaymentBlockedTitle,
        body: DriverStrings.runtimePaymentBlockedBody,
        ctaLabel: DriverStrings.runtimeOpenBilling,
        ctaRoute: '/driver/billing',
      );
    }
    if (reason == 'missing_tariff' || decision.redirect == '/driver/tariffs') {
      return DriverRuntimeGateArgs(
        title: DriverStrings.initialTariffTitle,
        body: DriverStrings.runtimeMissingInitialTariff,
        ctaLabel: DriverStrings.runtimeOpenTariffs,
        ctaRoute: '/driver/tariffs',
      );
    }
    return DriverRuntimeGateArgs(
      title: DriverStrings.runtimeUnknownBlockedTitle,
      body: DriverStrings.runtimeUnknownBlockedBody,
      ctaLabel: DriverStrings.runtimeOpenDocuments,
      ctaRoute: '/driver/documents',
    );
  }

  static DriverRuntimeGateArgs complianceFallback() {
    return DriverRuntimeGateArgs(
      title: DriverStrings.runtimeComplianceBlockedTitle,
      body: DriverStrings.runtimeComplianceBlockedBody,
      ctaLabel: DriverStrings.runtimeOpenDocuments,
      ctaRoute: '/driver/documents',
      secondaryLabel: DriverStrings.me,
      secondaryRoute: '/driver/me',
    );
  }

  static String _messageForRequirement(DriverReadinessItem item) {
    switch (item.key.trim()) {
      case 'profile_photo':
        return DriverStrings.runtimeMissingProfilePhoto;
      case 'vehicle_photos':
        return DriverStrings.runtimeMissingVehiclePhoto;
      case 'vehicle_plate':
        return DriverStrings.runtimeMissingTaxiVerification;
      case 'terms_of_service':
      case 'indemnification_quiz':
        return DriverStrings.runtimeMissingTerms;
      case 'rijbewijs_verified':
        return DriverStrings.runtimeMissingIdentity;
      case 'initial_tariff':
        return DriverStrings.runtimeMissingInitialTariff;
      default:
        return item.label.trim().isEmpty
            ? DriverStrings.runtimeComplianceBlockedBody
            : DriverStrings.runtimeMissingGeneric(item.label);
    }
  }

  static String _ctaForRequirement(DriverReadinessItem item) {
    switch (item.key.trim()) {
      case 'profile_photo':
        return DriverStrings.driverPhotoMissingCta;
      case 'vehicle_photos':
        return DriverStrings.vehiclePhotoMissingCta;
      case 'vehicle_plate':
        return DriverStrings.lookupPlate;
      case 'rijbewijs_verified':
        return DriverStrings.veriffStart;
      case 'initial_tariff':
        return DriverStrings.runtimeOpenTariffs;
      default:
        return DriverStrings.runtimeOpenDocuments;
    }
  }
}
