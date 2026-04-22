import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_state_provider.dart';

class AtPickupScreen extends ConsumerStatefulWidget {
  const AtPickupScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<AtPickupScreen> createState() => _AtPickupScreenState();
}

class _AtPickupScreenState extends ConsumerState<AtPickupScreen> {
  bool _loading = false;
  int _waitSeconds = 0;
  Timer? _waitTimer;
  static const int _noShowAfterSeconds = 300; // 5 min

  @override
  void initState() {
    super.initState();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _waitSeconds++);
    });
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRide() async {
    setState(() => _loading = true);
    try {
      await ref.read(driverApiProvider).startRide(rideRequestId: widget.rideId);
      ref.read(driverStateProvider.notifier).setStatus(DriverAppState.inProgress);
      if (!mounted) return;
      context.go('/driver/ride/progress/${widget.rideId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reportNoShow() async {
    setState(() => _loading = true);
    try {
      await ref.read(driverApiProvider).reportNoShow(payload: {
        'ride_request_id': widget.rideId,
      });
      ref.read(driverStateProvider.notifier).clearActiveRide();
      if (!mounted) return;
      context.go('/driver');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No-show reported')),
      );
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
    final canReportNoShow = _waitSeconds >= _noShowAfterSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('At pickup'),
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
                driver.pickupAddress ?? 'Pickup address',
                style: typo.titleMedium.copyWith(color: colors.text),
              ),
              if (driver.riderContactName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Rider: ${driver.riderContactName}',
                  style: typo.bodyMedium.copyWith(color: colors.textMid),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Waiting: ${_waitSeconds ~/ 60}:${(_waitSeconds % 60).toString().padLeft(2, '0')}',
                style: typo.bodyMedium.copyWith(color: colors.textSoft),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _startRide,
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
                    : const Text('Start ride'),
              ),
              if (canReportNoShow) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : _reportNoShow,
                  child: Text(
                    "Rider didn't show",
                    style: typo.bodyMedium.copyWith(color: colors.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
