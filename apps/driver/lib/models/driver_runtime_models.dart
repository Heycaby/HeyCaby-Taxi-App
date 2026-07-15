import 'package:heycaby_api/heycaby_api.dart';

class DriverRemoteConfig {
  const DriverRemoteConfig({
    required this.searchWindowMinutes,
    required this.noDriverDelaySeconds,
    required this.nearTermWindowHours,
    required this.maxSearchRadiusKm,
    required this.driverLocationMaxAgeMinutes,
    required this.featureFlags,
    required this.links,
  });

  final int searchWindowMinutes;
  final int noDriverDelaySeconds;
  final int nearTermWindowHours;
  final double maxSearchRadiusKm;
  final int driverLocationMaxAgeMinutes;
  final Map<String, bool> featureFlags;
  final AppPublicLinks links;

  /// Server E2E test mode: skip client payment gate before go-online.
  bool get skipGoOnlineGates => featureFlags['skip_go_online_gates'] == true;

  /// Plate-first onboarding: only plate + terms + indemnification block go-online.
  bool get driverOnboardingV2 => featureFlags['driver_onboarding_v2'] == true;

  /// Controls only Driver Mollie OAuth onboarding. Rider payment modes have
  /// their own independent backend flags.
  bool get mollieConnectEnabled =>
      featureFlags['ride_prepaid_driver_connect_enabled'] == true;

  /// Global kill switch for all prepaid ride behavior.
  bool get marketplaceRoutingEnabled =>
      featureFlags['mollie_marketplace_routing_enabled'] == true;

  bool get prepaidPaymentsEnabled =>
      marketplaceRoutingEnabled &&
      featureFlags['ride_prepaid_payments_enabled'] == true;

  bool get arrivalVerificationEnabled =>
      featureFlags['ride_arrival_verification_enabled'] == true;

  bool get boardingPinEnabled => featureFlags['boarding_pin_enabled'] == true;

  bool get verifiedCompletionEnabled =>
      featureFlags['verified_completion_enabled'] == true;

  factory DriverRemoteConfig.fromJson(Map<String, dynamic> json) {
    final search =
        (json['search'] as Map?)?.cast<String, dynamic>() ?? const {};
    final flagsRaw =
        (json['feature_flags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final flags = <String, bool>{};
    for (final entry in flagsRaw.entries) {
      flags[entry.key] = entry.value == true;
    }
    return DriverRemoteConfig(
      searchWindowMinutes:
          (search['driver_search_window_minutes'] as num?)?.toInt() ?? 10,
      noDriverDelaySeconds:
          (search['no_driver_card_delay_seconds'] as num?)?.toInt() ?? 5,
      nearTermWindowHours:
          (search['near_term_scheduled_window_hours'] as num?)?.toInt() ?? 48,
      maxSearchRadiusKm:
          (search['max_search_radius_km'] as num?)?.toDouble() ?? 12,
      driverLocationMaxAgeMinutes:
          (search['driver_location_max_age_minutes'] as num?)?.toInt() ?? 3,
      featureFlags: flags,
      links: AppPublicLinks.fromJson(json['links']),
    );
  }
}

class DriverReadinessItem {
  const DriverReadinessItem({
    required this.key,
    required this.label,
    required this.complete,
    this.action,
    this.note,
    this.priority = 999,
  });

  final String key;
  final String label;
  final bool complete;
  final String? action;
  final String? note;
  final int priority;

  factory DriverReadinessItem.fromJson(Map<String, dynamic> json) {
    return DriverReadinessItem(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      complete: json['complete'] == true,
      action: json['action'] as String?,
      note: json['note'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 999,
    );
  }
}

class DriverReadinessState {
  const DriverReadinessState({
    required this.canGoOnline,
    required this.checklist,
    this.gatesSkipped = false,
    this.statusMessage,
    this.complianceType,
    this.completedRides = 0,
    this.nextMilestoneAt = 0,
    this.onboardingV2Stage = 0,
    this.verificationRequired = false,
    this.premiumEligible = false,
    this.launchRequirements = const [],
    this.launchBlockers = const [],
    this.completedRequirements = const [],
    this.reviewStatus = 'none',
    this.reviewReason,
    this.reviewRestrictsOnline = false,
    this.reviewRequirements = const [],
    this.reviewBlockers = const [],
    this.optionalProfileItems = const [],
  });

  final bool canGoOnline;
  final bool gatesSkipped;
  final List<DriverReadinessItem> checklist;
  final String? statusMessage;
  final String? complianceType;
  final int completedRides;
  final int nextMilestoneAt;
  final int onboardingV2Stage;
  final bool verificationRequired;
  final bool premiumEligible;
  final List<DriverReadinessItem> launchRequirements;
  final List<DriverReadinessItem> launchBlockers;
  final List<String> completedRequirements;
  final String reviewStatus;
  final String? reviewReason;
  final bool reviewRestrictsOnline;
  final List<DriverReadinessItem> reviewRequirements;
  final List<DriverReadinessItem> reviewBlockers;
  final List<String> optionalProfileItems;

  List<DriverReadinessItem> get missingItems => [
        ...launchBlockers,
        ...reviewBlockers,
      ];

  bool get hasActiveReview =>
      reviewStatus != 'none' && reviewStatus != 'cleared';

  bool get hasUpcomingMilestone =>
      nextMilestoneAt > 0 && completedRides < nextMilestoneAt;

  factory DriverReadinessState.fromJson(Map<String, dynamic> json) {
    final checklistRaw = (json['checklist'] as List?) ?? const [];
    List<DriverReadinessItem> parseItems(Object? raw) =>
        (raw as List? ?? const [])
            .whereType<Map>()
            .map((e) => DriverReadinessItem.fromJson(e.cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));

    const launchKeys = {
      'vehicle_plate',
      'terms_of_service',
      'indemnification_quiz',
      'profile_photo',
      'vehicle_photos',
      'initial_tariff',
    };
    final checklist = parseItems(checklistRaw);
    final explicitLaunch = parseItems(json['launch_requirements']);
    final launch = explicitLaunch.isNotEmpty
        ? explicitLaunch
        : checklist.where((item) => launchKeys.contains(item.key)).toList();
    final explicitLaunchBlockers = parseItems(json['launch_blockers']);
    final launchMissing = explicitLaunchBlockers.isNotEmpty
        ? explicitLaunchBlockers
        : launch.where((item) => !item.complete).toList();
    final reviewRequirements = parseItems(json['review_requirements']);
    final reviewBlockers = parseItems(json['review_blockers']);
    return DriverReadinessState(
      canGoOnline: json['can_go_online'] == true,
      gatesSkipped: json['gates_skipped'] == true,
      checklist: checklist,
      statusMessage: json['status_message'] as String?,
      complianceType: json['compliance_type'] as String?,
      completedRides: (json['completed_rides'] as num?)?.toInt() ?? 0,
      nextMilestoneAt: (json['next_milestone_at'] as num?)?.toInt() ?? 0,
      onboardingV2Stage: (json['onboarding_v2_stage'] as num?)?.toInt() ?? 0,
      verificationRequired: json['verification_required'] == true,
      premiumEligible: json['premium_eligible'] == true,
      launchRequirements: launch,
      launchBlockers: launchMissing,
      completedRequirements:
          (json['completed_requirements'] as List? ?? const [])
              .map((value) => value.toString())
              .toList(growable: false),
      reviewStatus: (json['review_status'] ?? 'none').toString(),
      reviewReason: json['review_reason']?.toString(),
      reviewRestrictsOnline: json['review_restricts_online'] == true,
      reviewRequirements: reviewRequirements,
      reviewBlockers: reviewBlockers,
      optionalProfileItems:
          (json['optional_profile_items'] as List? ?? const [])
              .map((value) => value.toString())
              .toList(growable: false),
    );
  }
}

/// Unified Supabase `fn_driver_runtime` payload for the driver app.
class DriverRuntimeSnapshot {
  const DriverRuntimeSnapshot({
    required this.ok,
    required this.canGoOnline,
    required this.readiness,
    required this.config,
    this.runtimeVersion = 0,
    this.generatedAt,
    this.billingAllowed = true,
    this.platformRideEligible = true,
    this.platformDispatchEligibleNow = false,
    this.eligibilityReason,
    this.balanceState = 'current',
    this.plateVerified = false,
    this.termsAccepted = false,
    this.sessionActive = false,
    this.sharedVehicle = false,
    this.platformHealth = 'UNKNOWN',
    this.completedRides = 0,
    this.nextMilestone = 0,
    this.verificationRequired = false,
    this.notices = const [],
    this.error,
  });

  final bool ok;
  final int runtimeVersion;
  final DateTime? generatedAt;
  final bool canGoOnline;
  final DriverReadinessState readiness;
  final DriverRemoteConfig config;

  /// Legacy alias for [platformRideEligible]. It never controls presence.
  final bool billingAllowed;
  final bool platformRideEligible;
  final bool platformDispatchEligibleNow;
  final String? eligibilityReason;
  final String balanceState;
  final bool plateVerified;
  final bool termsAccepted;
  final bool sessionActive;
  final bool sharedVehicle;
  final String platformHealth;
  final int completedRides;
  final int nextMilestone;
  final bool verificationRequired;
  final List<Map<String, dynamic>> notices;
  final String? error;

  factory DriverRuntimeSnapshot.fromRpc(Object? raw) {
    if (raw is! Map) {
      return DriverRuntimeSnapshot(
        ok: false,
        canGoOnline: false,
        readiness:
            const DriverReadinessState(canGoOnline: false, checklist: []),
        config: DriverRemoteConfig.fromJson(const {}),
        error: 'invalid_runtime_response',
      );
    }
    final json = Map<String, dynamic>.from(raw);
    if (json['ok'] == false) {
      return DriverRuntimeSnapshot(
        ok: false,
        canGoOnline: false,
        readiness:
            const DriverReadinessState(canGoOnline: false, checklist: []),
        config: DriverRemoteConfig.fromJson(const {}),
        error: json['error'] as String? ?? 'runtime_error',
      );
    }

    final readinessRaw =
        (json['permissions'] as Map?)?.cast<String, dynamic>() ??
            (json['readiness'] as Map?)?.cast<String, dynamic>() ??
            json;
    final configRaw =
        (json['config'] as Map?)?.cast<String, dynamic>() ?? const {};
    final onboardingRaw =
        (json['onboarding'] as Map?)?.cast<String, dynamic>() ?? const {};
    final billingRaw =
        (json['billing'] as Map?)?.cast<String, dynamic>() ?? const {};
    final dispatchRaw =
        (json['dispatch'] as Map?)?.cast<String, dynamic>() ?? const {};
    final generatedRaw = json['generated_at'];
    final platformEligibilityRaw = json['platform_ride_eligible'] ??
        json['billing_allowed'] ??
        billingRaw['allowed'];
    final platformRideEligible = platformEligibilityRaw != false;

    final plateVerified = json['plate_verified'] == true ||
        onboardingRaw['plate_verified'] == true;
    final termsAccepted = json['terms_accepted'] == true ||
        onboardingRaw['terms_accepted'] == true;

    return DriverRuntimeSnapshot(
      ok: true,
      runtimeVersion: (json['runtime_version'] as num?)?.toInt() ?? 0,
      generatedAt: generatedRaw == null
          ? null
          : DateTime.tryParse(generatedRaw.toString())?.toUtc(),
      canGoOnline: json['can_go_online'] == true,
      readiness: DriverReadinessState.fromJson(readinessRaw),
      config: DriverRemoteConfig.fromJson(configRaw),
      billingAllowed: platformRideEligible,
      platformRideEligible: platformRideEligible,
      platformDispatchEligibleNow:
          json['platform_dispatch_eligible_now'] == true ||
              (json['platform_dispatch_eligible_now'] == null &&
                  dispatchRaw['eligible'] == true),
      eligibilityReason:
          (json['eligibility_reason'] ?? billingRaw['eligibility_reason'])
              ?.toString(),
      balanceState:
          (json['balance_state'] ?? billingRaw['balance_state'] ?? 'current')
              .toString(),
      plateVerified: plateVerified,
      termsAccepted: termsAccepted,
      sessionActive: json['session_active'] == true,
      sharedVehicle: json['shared_vehicle'] == true,
      platformHealth: (json['platform_health'] ?? 'UNKNOWN').toString(),
      completedRides: (json['completed_rides'] as num?)?.toInt() ?? 0,
      nextMilestone: (json['next_milestone'] as num?)?.toInt() ?? 0,
      verificationRequired: json['verification_required'] == true,
      notices: (json['notices'] as List?)
              ?.whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList() ??
          const [],
    );
  }
}

class DriverStatusDecision {
  const DriverStatusDecision({
    required this.status,
    this.blockedReason,
    this.redirect,
    this.paymentUrl,
    this.message,
    this.platformRideEligible = true,
    this.eligibilityReason,
    this.balanceState = 'current',
  });

  final String status;
  final String? blockedReason;
  final String? redirect;
  final String? paymentUrl;
  final String? message;
  final bool platformRideEligible;
  final String? eligibilityReason;
  final String balanceState;

  bool get isBlocked => blockedReason != null && blockedReason!.isNotEmpty;

  factory DriverStatusDecision.fromJson(Map<String, dynamic> json) {
    return DriverStatusDecision(
      status: (json['status'] ?? '').toString(),
      blockedReason: json['blocked_reason'] as String?,
      redirect: json['redirect'] as String?,
      paymentUrl: json['payment_url'] as String?,
      message: (json['message'] ?? json['error']) as String?,
      platformRideEligible: json['platform_ride_eligible'] != false,
      eligibilityReason: json['eligibility_reason'] as String?,
      balanceState: (json['balance_state'] ?? 'current').toString(),
    );
  }
}
