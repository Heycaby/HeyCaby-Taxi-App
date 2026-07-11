import 'package:flutter/foundation.dart';

/// Debug-only client-side proof log for Phase 2A lifecycle matrix.
///
/// During two-phone tests, grep device logs for `[LifecycleProof]` and mark
/// Realtime / FCM / Engine / Widget columns in the matrix spreadsheet.
abstract final class RiderLifecycleProofLogger {
  static void mark({
    required String rideId,
    required String step,
    required String channel,
    String? detail,
  }) {
    if (!kDebugMode) return;
    final extra = detail == null || detail.isEmpty ? '' : ' $detail';
    debugPrint(
      '[LifecycleProof] ride=$rideId step=$step channel=$channel$extra',
    );
  }

  static void engineRefresh({
    required String rideId,
    required String source,
    required String effectiveStatus,
    required int rideVersion,
  }) {
    mark(
      rideId: rideId,
      step: effectiveStatus,
      channel: 'lifecycle_engine',
      detail: 'source=$source rideVersion=$rideVersion',
    );
  }

  static void widgetUpdated({
    required String rideId,
    required String phase,
    required int rideVersion,
  }) {
    mark(
      rideId: rideId,
      step: phase,
      channel: 'widget',
      detail: 'rideVersion=$rideVersion',
    );
  }
}
