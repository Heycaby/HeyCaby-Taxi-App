import '../models/ride_waiting_info.dart';

/// Columns the ride state engine reads from `ride_requests` (keep selects in sync).
const kRiderRideLifecycleSelect =
    'id, status, driver_id, accepted_at, driver_arrived_at, near_pickup_notified_at, '
    'started_at, completed_at, payment_status, updated_at, created_at, '
    'pickup_address, destination_address, rider_token, '
    'waiting_grace_seconds, waiting_rate_per_minute, '
    'chargeable_wait_seconds, waiting_fee_cents, waiting_fee_waived';

/// Parsed backend row used to resolve rider widget phase (status + timestamps).
class RiderRideLifecycleSnapshot {
  const RiderRideLifecycleSnapshot({
    required this.rideRequestId,
    this.status,
    this.driverId,
    this.acceptedAt,
    this.driverArrivedAt,
    this.nearPickupNotifiedAt,
    this.startedAt,
    this.completedAt,
    this.paymentStatus,
    this.waitingInfo,
    this.updatedAt,
  });

  final String rideRequestId;
  final String? status;
  final String? driverId;
  final DateTime? acceptedAt;
  final DateTime? driverArrivedAt;
  final DateTime? nearPickupNotifiedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? paymentStatus;
  final RideWaitingInfo? waitingInfo;
  final DateTime? updatedAt;

  static RiderRideLifecycleSnapshot fromRow(
    Map<String, dynamic> row, {
    required String rideRequestId,
  }) {
    return RiderRideLifecycleSnapshot(
      rideRequestId: rideRequestId,
      status: row['status']?.toString(),
      driverId: row['driver_id']?.toString(),
      acceptedAt: _parseTs(row['accepted_at']),
      driverArrivedAt: _parseTs(row['driver_arrived_at']),
      nearPickupNotifiedAt: _parseTs(row['near_pickup_notified_at']),
      startedAt: _parseTs(row['started_at']),
      completedAt: _parseTs(row['completed_at']),
      paymentStatus: row['payment_status']?.toString(),
      waitingInfo: RideWaitingInfo.fromJson(row),
      updatedAt: _parseTs(row['updated_at']),
    );
  }

  static DateTime? _parseTs(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  /// Canonical lifecycle string for Live Activity + provider sync.
  ///
  /// Priority matches CTO spec: payment → completed → in_progress → arrived →
  /// nearby → en_route → accepted → searching fallback.
  String resolveEffectiveStatus() {
    final ps = (paymentStatus ?? '').trim().toLowerCase();
    if (ps == 'paid') return 'payment_confirmed';

    final st = (status ?? '').trim().toLowerCase();

    if (st == 'completed' || completedAt != null) return 'completed';
    if (st == 'in_progress' || startedAt != null) return 'in_progress';

    if (driverArrivedAt != null ||
        st == 'driver_arrived' ||
        st == 'arrived') {
      return 'driver_arrived';
    }

    if (nearPickupNotifiedAt != null) return 'driver_nearby';

    if (st == 'driver_en_route') return 'driver_en_route';

    if (driverId != null && driverId!.isNotEmpty ||
        acceptedAt != null ||
        st == 'accepted' ||
        st == 'assigned' ||
        st == 'driver_found') {
      if (st.isNotEmpty &&
          st != 'pending' &&
          st != 'bidding' &&
          st != 'cancelled' &&
          st != 'canceled') {
        return st;
      }
      return 'accepted';
    }

    return st.isNotEmpty ? st : 'pending';
  }

  bool get isInWaitingGraceWindow {
    if (waitingInfo == null) return false;
    return resolveEffectiveStatus() == 'driver_arrived' &&
        waitingInfo!.isInGracePeriod;
  }

  /// Fields that changed between two snapshots (for debug logs).
  static List<String> changedFields(
    RiderRideLifecycleSnapshot? prev,
    RiderRideLifecycleSnapshot next,
  ) {
    if (prev == null) return ['initial'];
    final out = <String>[];
    void cmp(String name, Object? a, Object? b) {
      if (a != b) out.add(name);
    }

    cmp('status', prev.status, next.status);
    cmp('driver_id', prev.driverId, next.driverId);
    cmp('accepted_at', prev.acceptedAt?.toIso8601String(),
        next.acceptedAt?.toIso8601String());
    cmp('driver_arrived_at', prev.driverArrivedAt?.toIso8601String(),
        next.driverArrivedAt?.toIso8601String());
    cmp('near_pickup_notified_at', prev.nearPickupNotifiedAt?.toIso8601String(),
        next.nearPickupNotifiedAt?.toIso8601String());
    cmp('started_at', prev.startedAt?.toIso8601String(),
        next.startedAt?.toIso8601String());
    cmp('completed_at', prev.completedAt?.toIso8601String(),
        next.completedAt?.toIso8601String());
    cmp('payment_status', prev.paymentStatus, next.paymentStatus);
    cmp('updated_at', prev.updatedAt?.toIso8601String(),
        next.updatedAt?.toIso8601String());

    final pw = prev.waitingInfo;
    final nw = next.waitingInfo;
    if (pw == null && nw != null) {
      out.add('waiting_info');
    } else if (pw != null && nw != null) {
      cmp('waiting_grace_seconds', pw.graceSeconds, nw.graceSeconds);
      cmp('waiting_fee_cents', pw.frozenFeeCents, nw.frozenFeeCents);
    }
    return out;
  }

  String fingerprint() {
    final w = waitingInfo;
    return [
      status,
      driverId,
      acceptedAt?.millisecondsSinceEpoch,
      driverArrivedAt?.millisecondsSinceEpoch,
      nearPickupNotifiedAt?.millisecondsSinceEpoch,
      startedAt?.millisecondsSinceEpoch,
      completedAt?.millisecondsSinceEpoch,
      paymentStatus,
      w?.graceSeconds,
      w?.frozenFeeCents,
      w?.frozenChargeableSeconds,
    ].join('|');
  }

  /// Monotonic version for ordering updates (`ride_requests.updated_at` ms).
  int get rideVersion => updatedAt?.millisecondsSinceEpoch ?? 0;
}
