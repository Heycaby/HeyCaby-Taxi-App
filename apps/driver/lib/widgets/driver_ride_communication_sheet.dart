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
import '../widgets/driver_ride_premium_style.dart';
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
        unawaited(
          const RideVerificationService().recordContact(
            rideId: rideRequestId,
            channel: 'chat',
            outcome: 'chat_opened_from_driver_communication_center',
          ),
        );
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
  int _historyRefresh = 0;
  late Future<RideCommunicationPermissions> _permissions;
  bool _startingCall = false;

  @override
  void initState() {
    super.initState();
    _permissions = const MaskedRideCallingService().permissions(
      rideId: widget.rideRequestId,
    );
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
    final result = await sendDriverRiderPing(
      context: context,
      ref: widget.ref,
      rideRequestId: widget.rideRequestId,
      type: type,
    );
    if (mounted) {
      setState(() {
        _sending = null;
        if (result == DriverPingSendResult.success) {
          _historyRefresh += 1;
        }
      });
    }
  }

  Future<void> _startMaskedCall() async {
    if (_startingCall) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(DriverStrings.communicationCallTitle),
        content: Text(DriverStrings.communicationCallBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(DriverStrings.communicationCallNow),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _startingCall = true);
    final result = await const MaskedRideCallingService().startCall(
      rideId: widget.rideRequestId,
    );
    if (!mounted) return;
    setState(() {
      _startingCall = false;
      _permissions = const MaskedRideCallingService().permissions(
        rideId: widget.rideRequestId,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.ok
          ? DriverStrings.communicationCallQueued
          : DriverStrings.communicationCallUnavailable),
    ));
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
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: DriverRidePremiumStyle.glassSurface(
            colors: widget.colors,
            borderRadius: DriverRadius.sheetTop,
            blurSigma: 26,
            tintOpacity: 0.8,
            padding: EdgeInsets.fromLTRB(
              DriverSpacing.lg,
              DriverSpacing.md,
              DriverSpacing.lg,
              DriverSpacing.lg + bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: widget.colors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.lg),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(DriverSpacing.lg),
                    decoration: BoxDecoration(
                      color: widget.colors.primary.withValues(alpha: 0.08),
                      borderRadius: DriverRadius.lgAll,
                      border: Border.all(
                        color: widget.colors.primary.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: widget.colors.card,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.colors.primary
                                    .withValues(alpha: 0.14),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.forum_rounded,
                            color: widget.colors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: DriverSpacing.md),
                        Text(
                          DriverStrings.communicationCenterTitle,
                          style: widget.typography.titleLarge.copyWith(
                            color: widget.colors.text,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: DriverSpacing.sm),
                        Text(
                          DriverStrings.communicationCenterSubtitle,
                          style: widget.typography.bodyMedium.copyWith(
                            color: widget.colors.textSecondary,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (commContext.nearPickup) ...[
                          const SizedBox(height: DriverSpacing.sm),
                          Text(
                            DriverStrings.communicationNearPickupHint,
                            style: widget.typography.bodySmall.copyWith(
                              color: widget.colors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.lg),
                  FutureBuilder<RideCommunicationPermissions>(
                    future: _permissions,
                    builder: (context, snapshot) {
                      if (snapshot.data?.canCall != true) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: DriverSpacing.sm),
                        child: FilledButton.icon(
                          onPressed: _startingCall ? null : _startMaskedCall,
                          icon: _startingCall
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.call_outlined),
                          label: Text(DriverStrings.communicationMaskedCall),
                        ),
                      );
                    },
                  ),
                  FilledButton.icon(
                    onPressed: widget.onOpenChat,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(DriverStrings.communicationChat),
                  ),
                  const SizedBox(height: DriverSpacing.lg),
                  _SectionLabel(
                    colors: widget.colors,
                    typography: widget.typography,
                    label: DriverStrings.communicationQuickActions,
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  ...pings.map((type) {
                    final remaining = DriverPingCooldown.remaining(
                      widget.rideRequestId,
                      type.apiKind,
                    );
                    final onCooldown = remaining != null;
                    final busy = _sending == type;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: DriverSpacing.sm),
                      child: _PingActionButton(
                        colors: widget.colors,
                        typography: widget.typography,
                        enabled: !onCooldown && !busy,
                        busy: busy,
                        icon: _iconForPing(type),
                        label: onCooldown
                            ? DriverStrings.pingCooldownButton(
                                remaining.inSeconds,
                              )
                            : _labelForPing(type),
                        onTap: () => _sendPing(type),
                      ),
                    );
                  }),
                  const SizedBox(height: DriverSpacing.sm),
                  _SectionLabel(
                    colors: widget.colors,
                    typography: widget.typography,
                    label: DriverStrings.communicationPingHistory,
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.colors.surface,
                      borderRadius: DriverRadius.mdAll,
                      border: Border.all(color: widget.colors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DriverSpacing.md),
                      child: DriverPingHistorySection(
                        key: ValueKey(
                          '${widget.rideRequestId}-$_historyRefresh',
                        ),
                        rideRequestId: widget.rideRequestId,
                        colors: widget.colors,
                        typography: widget.typography,
                      ),
                    ),
                  ),
                ],
              ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.colors,
    required this.typography,
    required this.label,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: typography.labelLarge.copyWith(
        color: colors.textMuted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _PingActionButton extends StatelessWidget {
  const _PingActionButton({
    required this.colors,
    required this.typography,
    required this.enabled,
    required this.busy,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool enabled;
  final bool busy;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? colors.primary.withValues(alpha: 0.06) : colors.surface,
      borderRadius: DriverRadius.mdAll,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: DriverRadius.mdAll,
        child: Container(
          constraints:
              const BoxConstraints(minHeight: DriverSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: DriverSpacing.md,
            vertical: DriverSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: DriverRadius.mdAll,
            border: Border.all(
              color: enabled
                  ? colors.primary.withValues(alpha: 0.20)
                  : colors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: enabled ? colors.primary : colors.textMuted),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: typography.labelLarge.copyWith(
                    color: enabled ? colors.text : colors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? colors.textMuted : colors.border,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
