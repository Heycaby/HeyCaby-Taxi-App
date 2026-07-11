import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/models/driver_runtime_models.dart';

void main() {
  group('driver presence and Platform ride eligibility', () {
    test('an overdue balance does not make presence readiness false', () {
      final runtime = DriverRuntimeSnapshot.fromRpc({
        'ok': true,
        'runtime_version': 3,
        'can_go_online': true,
        'platform_ride_eligible': false,
        'platform_dispatch_eligible_now': false,
        'eligibility_reason': 'platform_balance_overdue',
        'balance_state': 'paused',
        'billing_allowed': false,
        'permissions': {
          'can_go_online': true,
          'checklist': <Object>[],
        },
        'billing': {
          'allowed': false,
          'ride_requests_paused': true,
        },
        'dispatch': {'eligible': false},
        'config': <String, Object>{},
      });

      expect(runtime.ok, isTrue);
      expect(runtime.canGoOnline, isTrue);
      expect(runtime.readiness.canGoOnline, isTrue);
      expect(runtime.platformRideEligible, isFalse);
      expect(runtime.billingAllowed, isFalse);
      expect(runtime.platformDispatchEligibleNow, isFalse);
      expect(runtime.eligibilityReason, 'platform_balance_overdue');
      expect(runtime.balanceState, 'paused');
    });

    test('status response preserves online presence and paused dispatch', () {
      final decision = DriverStatusDecision.fromJson({
        'success': true,
        'status': 'available',
        'driver_status': 'available',
        'platform_ride_eligible': false,
        'eligibility_reason': 'platform_balance_overdue',
        'balance_state': 'paused',
      });

      expect(decision.isBlocked, isFalse);
      expect(decision.status, 'available');
      expect(decision.platformRideEligible, isFalse);
      expect(decision.eligibilityReason, 'platform_balance_overdue');
      expect(decision.balanceState, 'paused');
    });

    test('older runtime payload remains eligible during rolling deploy', () {
      final runtime = DriverRuntimeSnapshot.fromRpc({
        'ok': true,
        'runtime_version': 3,
        'can_go_online': true,
        'permissions': {
          'can_go_online': true,
          'checklist': <Object>[],
        },
        'config': <String, Object>{},
      });

      expect(runtime.platformRideEligible, isTrue);
      expect(runtime.billingAllowed, isTrue);
    });
  });
}
