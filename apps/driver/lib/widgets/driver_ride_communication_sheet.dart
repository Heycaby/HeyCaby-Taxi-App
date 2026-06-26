import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../services/driver_ping_cooldown.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_ping_history_section.dart';
import '../utils/driver_rider_ping.dart';

/// Communication center — chat + quick status pings (no phone numbers).
Future<void> showDriverRideCommunicationSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String rideRequestId,
  required DriverRideCommunicationPhase phase,
  required VoidCallback onOpenChat,
  double? distanceToPickupM,
}) {
  final colors = ref.read(colorsProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DriverRideCommunicationSheet(
      colors: DriverColors.fromTheme(colors),
      typography: DriverTypography.fromTheme(ref.read(typographyProvider)),
      rideRequestId: rideRequestId,
      phase: phase,
      distanceToPickupM: distanceToPickupM,
      ref: ref,
      onOpenChat: () {
        Navigator.of(ctx).pop();
        onOpenChat();
      },
    ),
  );
}

class _DriverRideCommunicationSheet extends ConsumerStatefulWidget {
  const _DriverRideCommunicationSheet({
    required this.colors,
    required this.typography,
    required this.rideRequestId,
    required this.phase,
    required this.distanceToPickupM,
    required this.ref,
    required this.onOpenChat,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String rideRequestId;
  final DriverRideCommunicationPhase phase;
  final double? distanceToPickupM;
  final WidgetRef ref;
  final VoidCallback onOpenChat;

  @override
  ConsumerState<_DriverRideCommunicationSheet> createState() =>
      _DriverRideCommunicationSheetState();
}

class _DriverRideCommunicationSheetState
    extends ConsumerState<_DriverRideCommunicationSheet> {
  Timer? _cooldownTicker;
  DriverPingType? _sending;

  @override
  void initState() {
    super.initState();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  Future<void> _sendPing(DriverPingType type) async {
    if (_sending != null) return;
    setState(() => _sending = type);
    await sendDriverRiderPing(
      context: context,
      ref: widget.ref,
      rideRequestId: widget.rideRequestId,
      type: type,
    );
    if (mounted) setState(() => _sending = null);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final commContext = resolveCommunicationContext(
      phase: widget.phase,
      distanceToPickupM: widget.distanceToPickupM,
    );
    final pings = commContext.quickPings;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.colors.card,
            borderRadius: DriverRadius.sheetTop,
            border: Border.all(color: widget.colors.border),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DriverSpacing.lg,
              DriverSpacing.lg,
              DriverSpacing.lg,
              DriverSpacing.lg + bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DriverStrings.communicationCenterTitle,
                  style: widget.typography.titleLarge.copyWith(
                    color: widget.colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DriverSpacing.sm),
                Text(
                  DriverStrings.communicationCenterSubtitle,
                  style: widget.typography.bodyMedium.copyWith(
                    color: widget.colors.textSecondary,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (commContext.nearPickup) ...[
                  const SizedBox(height: DriverSpacing.sm),
                  Text(
                    DriverStrings.communicationNearPickupHint,
                    style: widget.typography.bodySmall.copyWith(
                      color: widget.colors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: DriverSpacing.lg),
                FilledButton.icon(
                  onPressed: widget.onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(DriverStrings.communicationChat),
                ),
                const SizedBox(height: DriverSpacing.lg),
                Divider(color: widget.colors.border),
                const SizedBox(height: DriverSpacing.sm),
                Text(
                  DriverStrings.communicationQuickActions,
                  style: widget.typography.labelLarge.copyWith(
                    color: widget.colors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: DriverSpacing.md),
                ...pings.map((type) {
                  final remaining = DriverPingCooldown.remaining(
                    widget.rideRequestId,
                    type.apiKind,
                  );
                  final onCooldown = remaining != null;
                  final busy = _sending == type;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DriverSpacing.sm),
                    child: OutlinedButton.icon(
                      onPressed: onCooldown || busy
                          ? null
                          : () => _sendPing(type),
                      icon: Icon(_iconForPing(type)),
                      label: Text(
                        onCooldown
                            ? DriverStrings.pingCooldownButton(
                                remaining!.inSeconds,
                              )
                            : _labelForPing(type),
                      ),
                    ),
                  );
                }),
                DriverPingHistorySection(
                  rideRequestId: widget.rideRequestId,
                  colors: widget.colors,
                  typography: widget.typography,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForPing(DriverPingType type) {
    switch (type) {
      case DriverPingType.onMyWay:
        return Icons.directions_car_filled;
      case DriverPingType.outside:
        return Icons.door_front_door_outlined;
      case DriverPingType.arrived:
        return Icons.place_rounded;
      case DriverPingType.runningLate:
        return Icons.schedule_rounded;
      case DriverPingType.trafficDelay:
        return Icons.traffic_rounded;
      case DriverPingType.cantFindRider:
        return Icons.person_search_outlined;
      case DriverPingType.thanks:
        return Icons.thumb_up_alt_outlined;
    }
  }

  String _labelForPing(DriverPingType type) {
    switch (type) {
      case DriverPingType.onMyWay:
        return DriverStrings.pingOnMyWay;
      case DriverPingType.outside:
        return DriverStrings.pingOutside;
      case DriverPingType.arrived:
        return DriverStrings.pingArrived;
      case DriverPingType.runningLate:
        return DriverStrings.pingRunningLate;
      case DriverPingType.trafficDelay:
        return DriverStrings.pingTrafficDelay;
      case DriverPingType.cantFindRider:
        return DriverStrings.pingCantFindRider;
      case DriverPingType.thanks:
        return DriverStrings.pingThanks;
    }
  }
}
