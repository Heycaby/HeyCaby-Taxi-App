import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Driver acceptance has one backend command authority', () {
    final screen =
        File('lib/screens/new_ride_request_screen.dart').readAsStringSync();
    final api = File(
      '../../packages/heycaby_api/lib/src/driver_api.dart',
    ).readAsStringSync();

    expect(screen, contains('.acceptRide(rideRequestId: widget.rideId)'));
    expect(screen, isNot(contains('_persistAcceptedFareSnapshot')));
    expect(screen, isNot(contains('fareSnapshotForInsert')));
    expect(api, contains("_invokeAcceptRpc('fn_driver_accept_ride_invite'"));
  });

  test('accept RPC rechecks server expiry and canonical runtime eligibility',
      () {
    final migration = File(
      '../../supabase/migrations/'
      '20260714084941_driver_accept_runtime_recheck.sql',
    ).readAsStringSync();
    final eligibility = File(
      '../../supabase/migrations/'
      '20260714084930_driver_accept_runtime_eligibility.sql',
    ).readAsStringSync();

    expect(migration, contains('FOR UPDATE'));
    expect(migration, contains("'ride_expired'"));
    expect(migration, contains('fn_driver_accept_runtime_eligibility'));
    expect(migration, contains("SET status = 'superseded'"));
    expect(migration, contains("'dispatch.accept_rejected'"));
    expect(eligibility, contains('fn_driver_readiness_eval'));
    expect(eligibility, contains("'driver_offline'"));
    expect(eligibility, contains("'vehicle_mismatch'"));
    expect(eligibility, contains("'pets_not_supported'"));
  });

  test('scheduled acceptance uses shared ride-fit and atomic authority', () {
    final migration = File(
      '../../supabase/migrations/'
      '20260714090109_scheduled_accept_authority.sql',
    ).readAsStringSync();
    final eligibility = File(
      '../../supabase/migrations/'
      '20260714090052_driver_accept_ride_fit_eligibility.sql',
    ).readAsStringSync();

    expect(migration, contains('FOR UPDATE'));
    expect(migration, contains("'scheduled_departed'"));
    expect(migration, contains('fn_driver_accept_runtime_eligibility'));
    expect(migration, contains('fn_driver_has_overlap'));
    expect(migration, contains('fn_ride_notify_rider'));
    expect(migration, contains("'dispatch.scheduled_accept_rejected'"));
    expect(eligibility, contains('p_require_online'));
    expect(eligibility, contains("'electric_vehicle_required'"));
    expect(eligibility, contains("'wheelchair_vehicle_required'"));
    expect(eligibility, contains('filter_pet_friendly'));
  });
}
