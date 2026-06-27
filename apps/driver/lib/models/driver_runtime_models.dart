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

  factory DriverRemoteConfig.fromJson(Map<String, dynamic> json) {
    final search = (json['search'] as Map?)?.cast<String, dynamic>() ?? const {};
    final flagsRaw =
        (json['feature_flags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final flags = <String, bool>{};
    for (final entry in flagsRaw.entries) {
      flags[entry.key] = entry.value == true;
    }
    return DriverRemoteConfig(
      searchWindowMinutes: (search['driver_search_window_minutes'] as num?)?.toInt() ?? 10,
      noDriverDelaySeconds: (search['no_driver_card_delay_seconds'] as num?)?.toInt() ?? 5,
      nearTermWindowHours:
          (search['near_term_scheduled_window_hours'] as num?)?.toInt() ?? 48,
      maxSearchRadiusKm: (search['max_search_radius_km'] as num?)?.toDouble() ?? 12,
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
  });

  final String key;
  final String label;
  final bool complete;
  final String? action;
  final String? note;

  factory DriverReadinessItem.fromJson(Map<String, dynamic> json) {
    return DriverReadinessItem(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      complete: json['complete'] == true,
      action: json['action'] as String?,
      note: json['note'] as String?,
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

  List<DriverReadinessItem> get missingItems =>
      checklist.where((item) => !item.complete).toList();

  bool get hasUpcomingMilestone =>
      nextMilestoneAt > 0 && completedRides < nextMilestoneAt;

  factory DriverReadinessState.fromJson(Map<String, dynamic> json) {
    final checklistRaw = (json['checklist'] as List?) ?? const [];
    return DriverReadinessState(
      canGoOnline: json['can_go_online'] == true,
      gatesSkipped: json['gates_skipped'] == true,
      checklist: checklistRaw
          .whereType<Map>()
          .map((e) => DriverReadinessItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      statusMessage: json['status_message'] as String?,
      complianceType: json['compliance_type'] as String?,
      completedRides: (json['completed_rides'] as num?)?.toInt() ?? 0,
      nextMilestoneAt: (json['next_milestone_at'] as num?)?.toInt() ?? 0,
      onboardingV2Stage: (json['onboarding_v2_stage'] as num?)?.toInt() ?? 0,
      verificationRequired: json['verification_required'] == true,
      premiumEligible: json['premium_eligible'] == true,
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
  final bool billingAllowed;
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
        readiness: const DriverReadinessState(canGoOnline: false, checklist: []),
        config: DriverRemoteConfig.fromJson(const {}),
        error: 'invalid_runtime_response',
      );
    }
    final json = Map<String, dynamic>.from(raw);
    if (json['ok'] == false) {
      return DriverRuntimeSnapshot(
        ok: false,
        canGoOnline: false,
        readiness: const DriverReadinessState(canGoOnline: false, checklist: []),
        config: DriverRemoteConfig.fromJson(const {}),
        error: json['error'] as String? ?? 'runtime_error',
      );
    }

    final readinessRaw = (json['permissions'] as Map?)?.cast<String, dynamic>() ??
        (json['readiness'] as Map?)?.cast<String, dynamic>() ??
        json;
    final configRaw =
        (json['config'] as Map?)?.cast<String, dynamic>() ?? const {};
    final onboardingRaw =
        (json['onboarding'] as Map?)?.cast<String, dynamic>() ?? const {};
    final generatedRaw = json['generated_at'];

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
      billingAllowed: json['billing_allowed'] == true,
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
  });

  final String status;
  final String? blockedReason;
  final String? redirect;
  final String? paymentUrl;
  final String? message;

  bool get isBlocked => blockedReason != null && blockedReason!.isNotEmpty;

  factory DriverStatusDecision.fromJson(Map<String, dynamic> json) {
    return DriverStatusDecision(
      status: (json['status'] ?? '').toString(),
      blockedReason: json['blocked_reason'] as String?,
      redirect: json['redirect'] as String?,
      paymentUrl: json['payment_url'] as String?,
      message: (json['message'] ?? json['error']) as String?,
    );
  }
}
