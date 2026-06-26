import 'package:flutter/material.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/widgets/driver_active_trip_body.dart';
import 'package:heycaby_driver/widgets/driver_navigation_focus_body.dart';
import 'package:heycaby_driver/widgets/driver_pickup_arrival_body.dart';
import 'package:heycaby_driver/widgets/driver_reward_screen_body.dart';

/// Shared mock trip data for ride-flow golden previews.
const _pickup = 'Damrak 1, Amsterdam';
const _dropoff = 'Schiphol Airport, Evert van de Beekstraat';
const _rider = 'Sophie van Dijk';
const _fare = '€ 42,50';

/// Golden preview — Active Trip (navigate to pickup).
class DriverActiveTripPreview extends StatelessWidget {
  const DriverActiveTripPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverActiveTripBody(
      colors: colors,
      typography: typography,
      pickupAddress: _pickup,
      destinationAddress: _dropoff,
      riderName: _rider,
      requestsPaused: false,
      statusBusy: false,
      arriving: false,
      onBack: () {},
      onArrived: () {},
      onNavigate: () {},
      onOpenCommunication: () {},
      onCancelOrder: () {},
      onToggleRequests: () {},
    );
  }
}

/// Golden preview — Pickup Arrival (awaiting rider).
class DriverPickupArrivalPreview extends StatelessWidget {
  const DriverPickupArrivalPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverPickupArrivalBody(
      colors: colors,
      typography: typography,
      pickupAddress: _pickup,
      destinationAddress: _dropoff,
      riderName: _rider,
      waitSeconds: 125,
      canReportNoShow: false,
      loading: false,
      onBack: () {},
      onStartRide: () {},
      onOpenCommunication: () {},
      onReportNoShow: () {},
      onCancelRide: () {},
    );
  }
}

/// Golden preview — Navigation Focus (ride in progress).
class DriverNavigationFocusPreview extends StatelessWidget {
  const DriverNavigationFocusPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverNavigationFocusBody(
      colors: colors,
      typography: typography,
      pickupAddress: _pickup,
      destinationAddress: _dropoff,
      riderName: _rider,
      expectedAmountLabel: _fare,
      completing: false,
      onBack: () {},
      onNavigate: () {},
      onCompleteRide: () {},
      onOpenCommunication: () {},
      onCancelRide: () {},
    );
  }
}

/// Golden preview — Reward Screen (ride complete).
class DriverRewardPreview extends StatefulWidget {
  const DriverRewardPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverRewardPreview> createState() => _DriverRewardPreviewState();
}

class _DriverRewardPreviewState extends State<DriverRewardPreview> {
  late final TextEditingController _paidController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _paidController = TextEditingController(text: '42,50');
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _paidController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DriverRewardScreenBody(
      colors: widget.colors,
      typography: widget.typography,
      destinationAddress: _dropoff,
      expectedLabel: _fare,
      paidController: _paidController,
      noteController: _noteController,
      paymentMethod: 'cash',
      sendingReceipt: false,
      onPaymentMethodChanged: (_) {},
      onSendReceipt: () {},
      onRateRider: () {},
      onSkip: () {},
      onBack: () {},
    );
  }
}
