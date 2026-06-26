import '../services/rider_runtime_config_service.dart';

/// After this delay we check live DB supply and show alternatives when no drivers are nearby.
Duration get kRiderNoDriverCardDelay =>
    Duration(seconds: riderRuntimeConfig.current.noDriverDelaySeconds);
