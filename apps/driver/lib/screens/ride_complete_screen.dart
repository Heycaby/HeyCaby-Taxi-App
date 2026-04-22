import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_state_provider.dart';

class RideCompleteScreen extends ConsumerWidget {
  const RideCompleteScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final driver = ref.watch(driverStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride complete'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/driver'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.check_circle, size: 64, color: colors.accent),
              const SizedBox(height: 16),
              Text(
                'Ride completed',
                style: typo.headingMedium.copyWith(color: colors.text),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                driver.destinationAddress ?? 'Destination',
                style: typo.bodyMedium.copyWith(color: colors.textMid),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (driver.riderPaymentMethod != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payment, color: colors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Payment: ${driver.riderPaymentMethod}',
                          style: typo.bodyMedium.copyWith(color: colors.text),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () =>
                    context.push('/driver/ride/rate/$rideId'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                child: const Text('Rate rider'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  ref.read(driverStateProvider.notifier).clearActiveRide();
                  context.go('/driver');
                },
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
