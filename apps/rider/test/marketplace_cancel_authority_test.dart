import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marketplace cancellation has one backend command authority', () {
    final screen =
        File('lib/screens/marketplace_matching_screen.dart').readAsStringSync();
    final migration = File(
      '../../supabase/migrations/'
      '20260713132821_domain_authority_phase0_containment.sql',
    ).readAsStringSync();

    expect(screen, contains('cancelExpiredRiderOpenRide('));
    expect(screen, isNot(contains(".from('ride_bids')")));
    expect(migration, contains('trg_expire_marketplace_bids_on_terminal_ride'));
    expect(migration, contains("SET status = 'expired'"));
  });
}
