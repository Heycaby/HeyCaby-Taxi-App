import 'package:flutter_test/flutter_test.dart';
import 'package:heycaby_driver/models/driver_runtime_models.dart';
import 'package:heycaby_driver/utils/driver_readiness_routes.dart';

void main() {
  test('legacy optional documents never become launch blockers', () {
    final state = DriverReadinessState.fromJson({
      'can_go_online': false,
      'checklist': [
        {'key': 'vehicle_plate', 'label': 'Plate', 'complete': true},
        {'key': 'profile_photo', 'label': 'Photo', 'complete': false},
        {'key': 'kvk_number', 'label': 'KVK', 'complete': false},
        {'key': 'chauffeurspas', 'label': 'Card', 'complete': false},
      ],
    });

    expect(state.launchBlockers.map((item) => item.key), ['profile_photo']);
    expect(state.missingItems.map((item) => item.key), ['profile_photo']);
  });

  test('structured review blockers stay separate from launch setup', () {
    final state = DriverReadinessState.fromJson({
      'can_go_online': false,
      'launch_requirements': [
        {'key': 'vehicle_plate', 'label': 'Plate', 'complete': true},
        {'key': 'profile_photo', 'label': 'Photo', 'complete': true},
      ],
      'launch_blockers': [],
      'review_status': 'requested',
      'review_reason': 'identity_mismatch',
      'review_restricts_online': true,
      'review_requirements': [
        {
          'key': 'driving_licence',
          'label': 'Driving licence',
          'complete': false,
          'action': '/driver/veriff',
        },
      ],
      'review_blockers': [
        {
          'key': 'driving_licence',
          'label': 'Driving licence',
          'complete': false,
          'action': '/driver/veriff',
        },
      ],
    });

    expect(state.launchBlockers, isEmpty);
    expect(state.hasActiveReview, isTrue);
    expect(state.reviewReason, 'identity_mismatch');
    expect(state.reviewBlockers.single.key, 'driving_licence');
  });

  test('photo requirements open their direct upload actions', () {
    const profile = DriverReadinessItem(
      key: 'profile_photo',
      label: 'Photo',
      complete: false,
    );
    const vehicle = DriverReadinessItem(
      key: 'vehicle_photos',
      label: 'Taxi photo',
      complete: false,
    );

    expect(
      flutterRouteForReadinessItem(profile),
      '/driver/me?action=profile_photo&return=1',
    );
    expect(
      flutterRouteForReadinessItem(vehicle),
      '/driver/me?action=vehicle_photo&return=1',
    );
  });
}
