import '../services/rider_runtime_config_service.dart';

/// Max time we keep an open driver search (foreground "searching" or background "notify me").
Duration get kRiderDriverSearchWindow =>
    Duration(minutes: riderRuntimeConfig.current.searchWindowMinutes);
