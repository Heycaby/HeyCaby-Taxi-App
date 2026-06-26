import '../services/rider_runtime_config_service.dart';

/// Show the home “upcoming / matching” banner when scheduled pickup is within this window.
Duration get kRiderNearTermScheduledWindow =>
    Duration(hours: riderRuntimeConfig.current.nearTermWindowHours);
