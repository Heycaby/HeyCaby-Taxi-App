import 'package:flutter/material.dart';
import 'package:heycaby_driver/l10n/driver_strings.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/ui/driver_status_badge.dart';
import 'package:heycaby_driver/widgets/driver_ledger_flow_common.dart';
import 'package:heycaby_driver/widgets/driver_todays_ledger_body.dart';
import 'package:heycaby_driver/widgets/driver_trip_receipt_body.dart';

class DriverTodaysLedgerPreview extends StatelessWidget {
  const DriverTodaysLedgerPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static const _rows = [
    DriverTodaysLedgerRow(
      routeLabel: 'Centraal Station → Schiphol',
      fareLabel: '€42,50',
      timeLabel: '14:32',
    ),
    DriverTodaysLedgerRow(
      routeLabel: 'Dam → Zuidas',
      fareLabel: '€18,00',
      timeLabel: '09:15',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverTodaysLedgerBody(
      colors: colors,
      typography: typography,
      loading: false,
      errorMessage: null,
      rows: _rows,
      onBack: () {},
    );
  }
}

class DriverRideHistoryPreview extends StatelessWidget {
  const DriverRideHistoryPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static final _items = [
    DriverLedgerHistoryItem(
      dateLabel: '18 mei 2026, 14:32',
      pickupLabel: 'Centraal Station, Amsterdam',
      dropoffLabel: 'Schiphol Airport',
      fareLabel: 'EUR 42.50',
      statusLabel: 'completed',
      statusTone: DriverStatusTone.success,
    ),
    DriverLedgerHistoryItem(
      dateLabel: '17 mei 2026, 09:15',
      pickupLabel: 'Damrak 1',
      dropoffLabel: 'Zuidas',
      fareLabel: 'EUR 18.00',
      statusLabel: DriverStrings.manualRideTag,
      statusTone: DriverStatusTone.warning,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverRideHistoryBody(
      colors: colors,
      typography: typography,
      loading: false,
      errorMessage: null,
      items: _items,
      onBack: () {},
      onItemTap: (_) {},
    );
  }
}

class DriverTripReceiptPreview extends StatelessWidget {
  const DriverTripReceiptPreview({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  static final _details = [
    DriverLedgerDetailItem(
      label: DriverStrings.type,
      value: DriverStrings.standardRideTag,
    ),
    DriverLedgerDetailItem(
      label: DriverStrings.pickup,
      value: 'Centraal Station, Amsterdam',
    ),
    DriverLedgerDetailItem(
      label: DriverStrings.dropoff,
      value: 'Schiphol Airport',
    ),
    DriverLedgerDetailItem(
      label: DriverStrings.paymentMethod,
      value: 'card',
    ),
    DriverLedgerDetailItem(
      label: DriverStrings.driverEarnings,
      value: 'EUR 40.25',
      emphasize: true,
    ),
    DriverLedgerDetailItem(
      label: DriverStrings.platformFee,
      value: 'EUR 2.25',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DriverTripReceiptBody(
      colors: colors,
      typography: typography,
      loading: false,
      errorMessage: null,
      notFound: false,
      fareLabel: 'EUR 42.50',
      subtitle: '18 mei 2026, 14:32',
      statusLabel: 'completed',
      statusTone: DriverStatusTone.success,
      details: _details,
      onBack: () {},
    );
  }
}
