import 'package:flutter/material.dart';
import 'package:heycaby_driver/theme/driver_colors.dart';
import 'package:heycaby_driver/theme/driver_spacing.dart';
import 'package:heycaby_driver/theme/driver_typography.dart';
import 'package:heycaby_driver/ui/driver_button.dart';
import 'package:heycaby_driver/ui/driver_chip.dart';
import 'package:heycaby_driver/ui/driver_ride_card.dart';
import 'package:heycaby_driver/ui/driver_statistic_card.dart';
import 'package:heycaby_driver/ui/driver_status_badge.dart';
import 'package:heycaby_driver/ui/driver_text_field.dart';

/// Design-system preview — golden baseline for Phase 1 components.
class DriverComponentGallery extends StatelessWidget {
  const DriverComponentGallery({
    super.key,
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    final email = TextEditingController(text: 'driver@heycaby.nl');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DriverSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Components',
            style: typography.headlineMedium.copyWith(color: colors.text),
          ),
          const SizedBox(height: DriverSpacing.lg),
          DriverButton(
            label: 'Primary',
            onPressed: () {},
            colors: colors,
            typography: typography,
          ),
          const SizedBox(height: DriverSpacing.sm),
          DriverButton(
            label: 'Outline',
            onPressed: () {},
            colors: colors,
            typography: typography,
            variant: DriverButtonVariant.outline,
          ),
          const SizedBox(height: DriverSpacing.lg),
          Row(
            children: [
              DriverChip(
                label: 'Online',
                colors: colors,
                typography: typography,
                selected: true,
              ),
              const SizedBox(width: DriverSpacing.sm),
              DriverStatusBadge(
                label: '€124,50',
                colors: colors,
                typography: typography,
                tone: DriverStatusTone.success,
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.lg),
          DriverStatisticCard(
            colors: colors,
            typography: typography,
            label: 'Vandaag',
            value: '€86,20',
            subtitle: '+12% vs gisteren',
          ),
          const SizedBox(height: DriverSpacing.lg),
          DriverRideCard(
            colors: colors,
            typography: typography,
            pickupLabel: 'Damrak, Amsterdam',
            dropoffLabel: 'Schiphol Airport',
            fareLabel: '€42,50',
            metaLabel: '4,2 km',
            statusLabel: 'Incoming',
            statusTone: DriverStatusTone.online,
          ),
          const SizedBox(height: DriverSpacing.lg),
          DriverTextField(
            controller: email,
            colors: colors,
            typography: typography,
            label: 'E-mail',
            hint: 'jouw@email.nl',
          ),
        ],
      ),
    );
  }
}
