import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_state_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

Future<Map<String, dynamic>?> respondToDriverRouteChange({
  required String rideRequestId,
  required bool accept,
}) async {
  final raw = await HeyCabySupabase.client.rpc(
    'fn_driver_respond_route_change',
    params: {
      'p_ride_request_id': rideRequestId,
      'p_accept': accept,
    },
  );
  if (raw is! Map) return null;
  return Map<String, dynamic>.from(raw);
}

/// Yes / No panel when the rider requests a mid-ride stop or destination change.
class DriverRouteChangeRequestPanel extends ConsumerStatefulWidget {
  const DriverRouteChangeRequestPanel({
    super.key,
    required this.colors,
    required this.typography,
    required this.rideRequestId,
    required this.confirmedRoute,
    required this.pending,
    this.compact = false,
    this.onResponded,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String rideRequestId;
  final ActiveRideRouteState confirmedRoute;
  final PendingRouteChange pending;
  final bool compact;
  final VoidCallback? onResponded;

  @override
  ConsumerState<DriverRouteChangeRequestPanel> createState() =>
      _DriverRouteChangeRequestPanelState();
}

class _DriverRouteChangeRequestPanelState
    extends ConsumerState<DriverRouteChangeRequestPanel> {
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticService.mediumTap();
    try {
      final result = await respondToDriverRouteChange(
        rideRequestId: widget.rideRequestId,
        accept: accept,
      );
      if (!mounted) return;
      if (result?['ok'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.routeChangeRespondFailed)),
        );
        return;
      }
      widget.onResponded?.call();
      if (accept) {
        HapticService.success();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.routeChangeRespondFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typography = widget.typography;
    final stopLabel =
        widget.pending.firstNewStopLabel(widget.confirmedRoute) ??
            widget.pending.destinationAddress;
    final padding = widget.compact
        ? const EdgeInsets.all(DriverSpacing.md)
        : const EdgeInsets.all(DriverSpacing.lg);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DriverRadius.lg),
        border: Border.all(color: colors.warning.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.add_location_alt_rounded,
                  color: colors.warning, size: 22),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverStrings.routeChangeRequestTitle,
                      style: typography.titleSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DriverStrings.routeChangeRequestBody(stopLabel),
                      style: typography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.pending.stops.isNotEmpty) ...[
            const SizedBox(height: DriverSpacing.md),
            for (final stop in widget.pending.stops) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.more_horiz_rounded,
                      color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stop.address,
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
          const SizedBox(height: DriverSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _respond(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: colors.border),
                  ),
                  child: Text(
                    DriverStrings.routeChangeRequestNo,
                    style: typography.labelLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DriverSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _respond(true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : Text(
                          DriverStrings.routeChangeRequestYes,
                          style: typography.labelLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final _lastPromptedRouteChangeKeyProvider =
    StateProvider<String?>((ref) => null);

/// Prompts the driver when a new pending route change arrives mid-ride.
class DriverRouteChangeRequestListener extends ConsumerStatefulWidget {
  const DriverRouteChangeRequestListener({super.key});

  @override
  ConsumerState<DriverRouteChangeRequestListener> createState() =>
      _DriverRouteChangeRequestListenerState();
}

class _DriverRouteChangeRequestListenerState
    extends ConsumerState<DriverRouteChangeRequestListener> {
  @override
  Widget build(BuildContext context) {
    ref.listen<DriverData>(driverStateProvider, (previous, next) {
      final rideId = next.activeRideId;
      final pending = next.pendingRouteChange;
      if (rideId == null || pending == null) return;

      final key = '$rideId:${pending.dedupeKey()}';
      if (ref.read(_lastPromptedRouteChangeKeyProvider) == key) return;
      ref.read(_lastPromptedRouteChangeKeyProvider.notifier).state = key;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final colors = DriverColors.fromTheme(ref.read(colorsProvider));
        final typography =
            DriverTypography.fromTheme(ref.read(typographyProvider));
        unawaited(
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Material(
                  color: colors.surface,
                  borderRadius: DriverRadius.sheetTop,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      DriverSpacing.lg,
                      DriverSpacing.md,
                      DriverSpacing.lg,
                      DriverSpacing.lg + MediaQuery.paddingOf(ctx).bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DriverRouteChangeRequestPanel(
                          colors: colors,
                          typography: typography,
                          rideRequestId: rideId,
                          confirmedRoute: next.activeRouteState,
                          pending: pending,
                          onResponded: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      });
    });

    return const SizedBox.shrink();
  }
}
