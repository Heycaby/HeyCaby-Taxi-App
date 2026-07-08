import 'dart:math' as math;

import '../services/rider_runtime_config_service.dart';

/// Legacy config key — never used below [kRiderNoSupplyMinSearchElapsed].
Duration get kRiderNoDriverCardDelay =>
    Duration(seconds: riderRuntimeConfig.current.noDriverDelaySeconds);

/// Minimum time searching before we may surface a no-supply hint (live DB check).
Duration get kRiderNoSupplyMinSearchElapsed => Duration(
      seconds: math.max(
        30,
        riderRuntimeConfig.current.noDriverDelaySeconds,
      ),
    );

/// Re-check nearby supply while the request stays open.
const Duration kRiderNoSupplyRecheckInterval = Duration(seconds: 45);
