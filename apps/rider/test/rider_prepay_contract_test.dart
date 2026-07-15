import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_rider/providers/booking_provider.dart';
import 'package:heycaby_rider/services/rider_runtime_config_service.dart';
import 'package:heycaby_rider/widgets/rider_prepay_card.dart';

void main() {
  test('all prepaid modes are disabled by default', () {
    final config = RiderRuntimeTuning.fromJson(const {});

    for (final mode in BookingMode.values) {
      expect(riderPrepayEnabledForMode(config, mode), isFalse);
    }
  });

  test('each prepaid mode requires global and mode-specific flags', () {
    final config = RiderRuntimeTuning.fromJson({
      'feature_flags': {
        'ride_prepaid_payments_enabled': true,
        'mollie_marketplace_routing_enabled': true,
        'ride_prepaid_scheduled_enabled': true,
        'ride_prepaid_taxi_terug_enabled': true,
        'ride_prepaid_instant_optional_enabled': true,
      },
    });

    expect(riderPrepayEnabledForMode(config, BookingMode.scheduled), isTrue);
    expect(riderPrepayEnabledForMode(config, BookingMode.terug), isTrue);
    expect(riderPrepayEnabledForMode(config, BookingMode.instant), isTrue);
    expect(riderPrepayEnabledForMode(config, BookingMode.marketplace), isFalse);
  });

  test('mode flag cannot bypass the global kill switch', () {
    final config = RiderRuntimeTuning.fromJson({
      'feature_flags': {'ride_prepaid_scheduled_enabled': true},
    });

    expect(riderPrepayEnabledForMode(config, BookingMode.scheduled), isFalse);
  });

  test('Mollie capability kill switch cannot be bypassed by rollout flags', () {
    final config = RiderRuntimeTuning.fromJson({
      'feature_flags': {
        'ride_prepaid_payments_enabled': true,
        'ride_prepaid_scheduled_enabled': true,
      },
    });

    expect(riderPrepayEnabledForMode(config, BookingMode.scheduled), isFalse);
  });

  test('payment prompt remains visible while Driver approaches', () {
    for (final status in <String>[
      'accepted',
      'driver_en_route',
      'driver_arrived',
      'arrived',
    ]) {
      expect(riderPrepayVisibleForRideStatus(status), isTrue, reason: status);
    }
    expect(riderPrepayVisibleForRideStatus('in_progress'), isFalse);
    expect(riderPrepayVisibleForRideStatus('completed'), isFalse);
  });

  test('backend booking mode wins over stale local presentation state', () {
    expect(
      riderPrepayModeFromBackend('scheduled', BookingMode.instant),
      BookingMode.scheduled,
    );
    expect(
      riderPrepayModeFromBackend('terug', BookingMode.instant),
      BookingMode.terug,
    );
    expect(
      riderPrepayModeFromBackend(null, BookingMode.instant),
      BookingMode.instant,
    );
  });
}
