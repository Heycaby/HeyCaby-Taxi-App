import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_location_provider.dart';
import '../providers/driver_state_provider.dart';
import '../services/driver_smart_ping_prefs.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../utils/driver_ride_proximity.dart';
import '../utils/driver_rider_ping.dart';

enum DriverSmartPingPresentation {
  banner,
  inline,
}

/// GPS/time-assisted one-tap ping suggestion (Program 3C).
class DriverSmartPingBanner extends ConsumerStatefulWidget {
  const DriverSmartPingBanner({
    super.key,
    required this.rideRequestId,
    required this.phase,
    this.presentation = DriverSmartPingPresentation.banner,
    this.onlyOnMyWay = false,
  });

  final String rideRequestId;
  final DriverRideCommunicationPhase phase;
  final DriverSmartPingPresentation presentation;
  final bool onlyOnMyWay;

  @override
  ConsumerState<DriverSmartPingBanner> createState() =>
      _DriverSmartPingBannerState();
}

class _DriverSmartPingBannerState extends ConsumerState<DriverSmartPingBanner> {
  static const _prefs = DriverSmartPingPrefs();
  final _enRouteStarted = DateTime.now();
  Timer? _ticker;
  DriverSmartPingSuggestion? _suggestion;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || widget.phase == DriverRideCommunicationPhase.inProgress) {
      return;
    }

    final driver = ref.read(driverStateProvider);
    final position = ref.read(driverLocationProvider).valueOrNull;
    double? distanceM;
    if (position != null &&
        driver.pickupLat != null &&
        driver.pickupLng != null) {
      distanceM = distanceToTargetMeters(
        lat: position.latitude,
        lng: position.longitude,
        targetLat: driver.pickupLat!,
        targetLng: driver.pickupLng!,
      );
    }

    final onMyWaySent = _prefs.wasPingSentRecently(
      widget.rideRequestId,
      DriverPingType.onMyWay.apiKind,
    );
    final outsideSent = _prefs.wasPingSentRecently(
      widget.rideRequestId,
      DriverPingType.outside.apiKind,
    );
    final onMyWayDismissed = await _prefs.isDismissed(
      widget.rideRequestId,
      DriverPingType.onMyWay.apiKind,
    );
    final outsideDismissed = await _prefs.isDismissed(
      widget.rideRequestId,
      DriverPingType.outside.apiKind,
    );

    if (!mounted) return;
    var next = resolveSmartPingSuggestion(
      phase: widget.phase,
      enRouteDuration: DateTime.now().difference(_enRouteStarted),
      distanceToPickupM: distanceM,
      onMyWayAlreadySent: onMyWaySent,
      outsideAlreadySent: outsideSent,
      onMyWayDismissed: onMyWayDismissed,
      outsideDismissed: outsideDismissed,
    );
    if (widget.onlyOnMyWay && next == DriverSmartPingSuggestion.outside) {
      next = null;
    }
    if (next != _suggestion) {
      setState(() => _suggestion = next);
    }
  }

  Future<void> _send() async {
    final s = _suggestion;
    if (s == null || _busy) return;
    setState(() => _busy = true);
    await sendDriverRiderPing(
      context: context,
      ref: ref,
      rideRequestId: widget.rideRequestId,
      type: pingTypeForSmartSuggestion(s),
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _suggestion = null;
      });
    }
  }

  Future<void> _dismiss() async {
    final s = _suggestion;
    if (s == null) return;
    final kind = pingTypeForSmartSuggestion(s).apiKind;
    await _prefs.dismiss(widget.rideRequestId, kind);
    if (mounted) setState(() => _suggestion = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = _suggestion;
    if (s == null) return const SizedBox.shrink();

    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    final (title, body) = switch (s) {
      DriverSmartPingSuggestion.onMyWay => (
          DriverStrings.smartPingOnMyWayTitle,
          DriverStrings.smartPingOnMyWayBody,
        ),
      DriverSmartPingSuggestion.outside => (
          DriverStrings.smartPingOutsideTitle,
          DriverStrings.smartPingOutsideBody,
        ),
    };

    return switch (widget.presentation) {
      DriverSmartPingPresentation.banner => _BannerLayout(
          colors: colors,
          typography: typography,
          title: title,
          body: body,
          busy: _busy,
          onDismiss: _dismiss,
          onSend: _send,
        ),
      DriverSmartPingPresentation.inline => _InlineLayout(
          colors: colors,
          typography: typography,
          title: title,
          body: body,
          busy: _busy,
          onDismiss: _dismiss,
          onSend: _send,
        ),
    };
  }
}

class _BannerLayout extends StatelessWidget {
  const _BannerLayout({
    required this.colors,
    required this.typography,
    required this.title,
    required this.body,
    required this.busy,
    required this.onDismiss,
    required this.onSend,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String title;
  final String body;
  final bool busy;
  final VoidCallback onDismiss;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Material(
          color: colors.card,
          elevation: 0,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.success.withValues(alpha: 0.22)),
              gradient: LinearGradient(
                colors: [
                  colors.success.withValues(alpha: 0.10),
                  colors.card,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: colors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: typography.titleSmall.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: typography.bodySmall.copyWith(
                          color: colors.textSecondary,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: busy ? null : onDismiss,
                  child: Text(DriverStrings.smartPingDismiss),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: busy ? null : onSend,
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : Text(DriverStrings.smartPingSend),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineLayout extends StatelessWidget {
  const _InlineLayout({
    required this.colors,
    required this.typography,
    required this.title,
    required this.body,
    required this.busy,
    required this.onDismiss,
    required this.onSend,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String title;
  final String body;
  final bool busy;
  final VoidCallback onDismiss;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colors.success.withValues(alpha: 0.08),
        border: Border.all(color: colors.success.withValues(alpha: 0.20)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: colors.success,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: typography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: busy ? null : onSend,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      )
                    : Text(
                        DriverStrings.smartPingSend,
                        style: typography.labelLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy ? null : onDismiss,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                DriverStrings.smartPingDismiss,
                style: typography.labelMedium.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
