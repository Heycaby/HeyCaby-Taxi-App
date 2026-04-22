import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_state_provider.dart';
import '../services/sound_service.dart';

class RideInProgressScreen extends ConsumerStatefulWidget {
  const RideInProgressScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RideInProgressScreen> createState() =>
      _RideInProgressScreenState();
}

class _RideInProgressScreenState extends ConsumerState<RideInProgressScreen> {
  bool _loading = false;

  Future<void> _completeRide() async {
    setState(() => _loading = true);
    try {
      await ref.read(driverApiProvider).completeRide(rideRequestId: widget.rideId);
      ref.read(driverStateProvider.notifier).setStatus(DriverAppState.completed);
      SoundService().playTripComplete();
      if (!mounted) return;
      context.go('/driver/ride/complete/${widget.rideId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final driver = ref.watch(driverStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride in progress'),
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
              const SizedBox(height: 16),
              Text(
                'Destination',
                style: typo.labelSmall.copyWith(color: colors.textSoft),
              ),
              const SizedBox(height: 4),
              Text(
                driver.destinationAddress ?? '—',
                style: typo.titleMedium.copyWith(color: colors.text),
              ),
              if (driver.riderContactName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Rider: ${driver.riderContactName}',
                  style: typo.bodyMedium.copyWith(color: colors.textMid),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _completeRide,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                child: _loading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onAccent,
                        ),
                      )
                    : const Text('Complete ride'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
