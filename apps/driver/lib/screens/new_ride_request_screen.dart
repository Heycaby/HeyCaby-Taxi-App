import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_state_provider.dart';
import '../services/sound_service.dart';

class NewRideRequestScreen extends ConsumerStatefulWidget {
  const NewRideRequestScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<NewRideRequestScreen> createState() =>
      _NewRideRequestScreenState();
}

class _NewRideRequestScreenState extends ConsumerState<NewRideRequestScreen> {
  Map<String, dynamic>? _rideData;
  String? _error;
  int _countdown = 30;
  Timer? _countdownTimer;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _loadRide();
    SoundService().playRideRequest();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _countdownTimer?.cancel();
          _onExpired();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    SoundService().stopRideRequest();
    super.dispose();
  }

  Future<void> _loadRide() async {
    try {
      final res = await HeyCabySupabase.client
          .from('ride_requests')
          .select()
          .eq('id', widget.rideId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _rideData = res;
        _error = res == null ? 'Ride not found' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _onExpired() {
    SoundService().stopRideRequest();
    context.go('/driver');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request expired')),
    );
  }

  Future<void> _acceptRide() async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    _countdownTimer?.cancel();
    SoundService().stopRideRequest();

    try {
      await ref.read(driverApiProvider).acceptRide(rideRequestId: widget.rideId);
      // Confirm acceptance with sound + haptic
      SoundService().playRideAccepted();
      HapticService.success();
      final r = _rideData;
      ref.read(driverStateProvider.notifier).setActiveRide(
            rideId: widget.rideId,
            paymentMethod: null,
            pickupAddress: r?['pickup_address'] as String?,
            pickupLat: (r?['pickup_lat'] as num?)?.toDouble(),
            pickupLng: (r?['pickup_lng'] as num?)?.toDouble(),
            destinationAddress: r?['destination_address'] as String?,
            destLat: (r?['destination_lat'] as num?)?.toDouble(),
            destLng: (r?['destination_lng'] as num?)?.toDouble(),
            bookingMode: r?['booking_mode'] as String?,
            riderName: r?['pickup_contact_name'] as String?,
          );
      if (!mounted) return;
      context.go('/driver/ride/active/${widget.rideId}');
    } on DriverAcceptRideException catch (e) {
      if (!mounted) return;
      setState(() => _isAccepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept: ${e.code}')),
      );
      context.go('/driver');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAccepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept: $e')),
      );
      context.go('/driver');
    }
  }

  void _declineRide() {
    SoundService().stopRideRequest();
    context.go('/driver');
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New ride request'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _declineRide,
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: typo.bodyMedium.copyWith(color: colors.error), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/driver'),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: _countdown / 30,
                            strokeWidth: 6,
                            color: colors.accent,
                            backgroundColor: colors.border,
                          ),
                        ),
                        Text(
                          '$_countdown',
                          style: typo.headingLarge.copyWith(color: colors.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_rideData != null) ...[
                    Text(
                      _rideData!['pickup_contact_name'] as String? ?? 'Rider',
                      style: typo.headingMedium.copyWith(color: colors.text),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Pickup',
                      value: _rideData!['pickup_address'] as String? ?? '—',
                      colors: colors,
                      typo: typo,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.flag,
                      label: 'Destination',
                      value: _rideData!['destination_address'] as String? ?? '—',
                      colors: colors,
                      typo: typo,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isAccepting ? null : _declineRide,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _isAccepting ? null : _acceptRide,
                            style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            child: _isAccepting
                                ? SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onAccent,
                                    ),
                                  )
                                : const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    )),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: typo.labelSmall.copyWith(color: colors.textSoft)),
              const SizedBox(height: 2),
              Text(value, style: typo.bodyMedium.copyWith(color: colors.text), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
