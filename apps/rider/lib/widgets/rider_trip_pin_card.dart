import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Read-only projection of the backend-generated boarding proof.
class RiderTripPinCard extends StatefulWidget {
  const RiderTripPinCard({
    super.key,
    required this.rideId,
    required this.colors,
    required this.typography,
    this.riderToken,
  });

  final String rideId;
  final String? riderToken;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;

  @override
  State<RiderTripPinCard> createState() => _RiderTripPinCardState();
}

class _RiderTripPinCardState extends State<RiderTripPinCard> {
  RideVerificationSnapshot? _snapshot;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final value = await const RideVerificationService().snapshot(
        rideId: widget.rideId,
        riderToken: widget.riderToken,
      );
      if (mounted) setState(() => _snapshot = value);
    } catch (_) {
      // Payment/ride state remains authoritative even if this projection is
      // temporarily unavailable. Do not show a guessed PIN or state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null ||
        !snapshot.isProtected ||
        !snapshot.arrivalVerified ||
        snapshot.boardingVerified) {
      return const SizedBox.shrink();
    }
    final pin = snapshot.boardingPin;
    if (pin == null || pin.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Trip PIN $pin',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.colors.accentL,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: widget.colors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: widget.colors.accent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.pin_rounded, color: widget.colors.onAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your trip PIN',
                    style: widget.typography.labelLarge.copyWith(
                      color: widget.colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pin.split('').join('  '),
                    style: widget.typography.headingLarge.copyWith(
                      color: widget.colors.text,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Share it with the driver only after you are inside the vehicle.',
                    style: widget.typography.bodySmall.copyWith(
                      color: widget.colors.textMid,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy trip PIN',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: pin));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trip PIN copied')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
