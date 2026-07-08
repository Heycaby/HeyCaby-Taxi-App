import 'package:flutter/material.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/widgets/driver_opportunity_screen_body.dart';

/// Golden preview — Opportunity Screen with mock ride data.
class DriverOpportunityPreview extends StatelessWidget {
  const DriverOpportunityPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _mockRide = {
    'pickup_contact_name': 'Sophie van Dijk',
    'pickup_address': 'Damrak 1, Amsterdam',
    'destination_address': 'Schiphol Airport, Evert van de Beekstraat',
    'offered_fare': 42.50,
    'fare_source': 'rider_offer',
    'estimated_distance_km': 18.4,
    'estimated_duration_min': 28,
    'pickup_distance_km': 4.2,
    'pickup_eta_min': 9,
    'pickup_lat': 52.3740,
    'pickup_lng': 4.8952,
    'destination_lat': 52.3105,
    'destination_lng': 4.7683,
    'driver_lat': 52.3676,
    'driver_lng': 4.9041,
    'booking_mode': 'marketplace',
    'marketplace_offered_fare': 42.50,
    'payment_method': 'cash',
    'rider_rating': 4.9,
    'surge_multiplier': 1.2,
  };

  @override
  Widget build(BuildContext context) {
    return DriverOpportunityScreenBody(
      colors: colors,
      typography: typography,
      countdownSeconds: 22,
      totalCountdownSeconds: 30,
      isAccepting: false,
      isDeclining: false,
      onAccept: () {},
      onDecline: () {},
      rideData: _mockRide,
    );
  }
}
