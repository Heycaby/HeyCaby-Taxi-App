import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/widgets/driver_manual_ride_entry_body.dart';
import 'package:heycaby_driver/widgets/driver_return_trips_body.dart';
import 'package:heycaby_driver/widgets/driver_scheduled_rides_body.dart';
import 'package:heycaby_driver/widgets/driver_trip_planning_flow_common.dart';

class DriverManualRideEntryPreview extends StatefulWidget {
  const DriverManualRideEntryPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  State<DriverManualRideEntryPreview> createState() =>
      _DriverManualRideEntryPreviewState();
}

class _DriverManualRideEntryPreviewState
    extends State<DriverManualRideEntryPreview> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _pickup;
  late final TextEditingController _dropoff;
  late final TextEditingController _fare;
  late final TextEditingController _passenger;

  @override
  void initState() {
    super.initState();
    _pickup = TextEditingController(text: 'Coolsingel 40, Rotterdam');
    _dropoff = TextEditingController(text: 'Rotterdam The Hague Airport');
    _fare = TextEditingController(text: '42.50');
    _passenger = TextEditingController(text: 'Jan');
  }

  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    _fare.dispose();
    _passenger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DriverManualRideEntryBody(
      colors: widget.colors,
      typography: widget.typography,
      formKey: _formKey,
      pickupController: _pickup,
      dropoffController: _dropoff,
      fareController: _fare,
      passengerController: _passenger,
      paymentMethod: 'cash',
      saving: false,
      loadingDropoffSuggestions: false,
      dropoffSuggestions: const [],
      farePreviewText: 'You keep 100%: EUR 42.50 • CASH',
      onDropoffChanged: (_) {},
      onSuggestionSelected: (_) {},
      onPaymentMethodChanged: (_) {},
      onFareChanged: () => setState(() {}),
      onSave: () {},
      onCancel: () {},
      onClose: () {},
      validateDropoff: (_) => null,
      validateFare: (_) => null,
    );
  }
}

class DriverReturnTripsPreview extends StatelessWidget {
  const DriverReturnTripsPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _trips = [
    DriverReturnTripOfferItem(
      fromLabel: 'Schiphol',
      toLabel: 'Rotterdam Centrum',
      offeredFareLabel: '€68.00',
      discountedFareLabel: '€54.40',
      distanceLabel: '57.2 km',
      durationLabel: '42 min',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverReturnTripsBody(
      colors: colors,
      typography: typography,
      subtitle: 'Schiphol → Rotterdam Centrum route, 57 km',
      discountPct: 20,
      computedFareText: '€54.40',
      chanceLabel: 'medium',
      chanceColor: colors.warning,
      loading: false,
      trips: _trips,
      onBack: () {},
      onDiscountChanged: (_) {},
      onAcceptTrip: (_) {},
    );
  }
}

class DriverScheduledRidesPreview extends StatelessWidget {
  const DriverScheduledRidesPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _rides = [
    DriverScheduledRideListItem(
      headline: '€38.50 · Pick-up today 16:30',
      distanceLabel: '12.4 km',
      pickupAddress: 'Stationplein 1, Rotterdam',
      destinationAddress: 'Erasmus MC, Rotterdam',
      mapPreview: SizedBox(
        height: 80,
        width: double.infinity,
        child: ColoredBox(color: Color(0xFFE8ECEF)),
      ),
    ),
    DriverScheduledRideListItem(
      headline: '€52.00 · Pick-up today 18:15',
      distanceLabel: '21.0 km',
      pickupAddress: 'Markthal, Rotterdam',
      destinationAddress: 'Den Haag Centraal',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverScheduledRidesBody(
      colors: colors,
      typography: typography,
      requestsSelected: true,
      loading: false,
      emptyMessage: null,
      errorMessage: null,
      rides: _rides,
      onBack: () {},
      onRequestsTap: () {},
      onConfirmedTap: () {},
      onRideTap: (_) {},
    );
  }
}
