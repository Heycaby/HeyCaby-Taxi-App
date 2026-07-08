import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_ride_flow_common.dart';
import 'driver_ride_map_pins_overlay.dart';
import 'driver_ride_premium_style.dart';
import 'driver_smart_ping_banner.dart';

enum DriverRideBoltPhase {
  enRoutePickup,
  atPickup,
  inProgress,
  completed,
}

/// Bolt-style active ride shell: map-first, floating controls, glass trip card.
class DriverRideBoltScaffold extends StatelessWidget {
  const DriverRideBoltScaffold({
    super.key,
    required this.colors,
    required this.typography,
    required this.phase,
    required this.infoCard,
    required this.bottomBar,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.driverLat,
    this.driverLng,
    this.onToggleRequests,
    this.onSafety,
    this.onChat,
    this.onNavigate,
    this.requestsPaused = false,
    this.statusBusy = false,
    this.showWaitHereHint = false,
    this.onClose,
    this.scrollableInfoCard = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverRideBoltPhase phase;
  final Widget infoCard;
  final Widget bottomBar;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? driverLat;
  final double? driverLng;
  final VoidCallback? onToggleRequests;
  final VoidCallback? onSafety;
  final VoidCallback? onChat;
  final VoidCallback? onNavigate;
  final bool requestsPaused;
  final bool statusBusy;
  final bool showWaitHereHint;
  final VoidCallback? onClose;
  final bool scrollableInfoCard;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final maxInfoHeight = MediaQuery.sizeOf(context).height * 0.52;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _DriverRideBoltMap(
            colors: colors,
            phase: phase,
            pickupLat: pickupLat,
            pickupLng: pickupLng,
            destLat: destLat,
            destLng: destLng,
            driverLat: driverLat,
            driverLng: driverLng,
          ),
          if (showWaitHereHint && pickupLat != null && pickupLng != null)
            Positioned(
              top: topPad + 120,
              left: 0,
              right: 0,
              child: Center(
                child: _WaitHereChip(
                  colors: colors,
                  typography: typography,
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DriverSpacing.screenEdge,
              ),
              child: Row(
                children: [
                  if (onToggleRequests != null)
                    _DriverRideBoltMapFab(
                      colors: colors,
                      icon: requestsPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pan_tool_alt_rounded,
                      onTap: statusBusy ? null : onToggleRequests,
                    ),
                  const Spacer(),
                  if (onSafety != null)
                    _DriverRideBoltMapFab(
                      colors: colors,
                      icon: Icons.shield_outlined,
                      onTap: onSafety,
                    )
                  else if (onClose != null)
                    _DriverRideBoltMapFab(
                      colors: colors,
                      icon: Icons.close_rounded,
                      onTap: onClose,
                    ),
                ],
              ),
            ),
          ),
          if (onChat != null)
            Positioned(
              right: DriverSpacing.screenEdge,
              top: topPad + 72,
              child: _DriverRideBoltMapFab(
                colors: colors,
                icon: Icons.chat_bubble_outline_rounded,
                onTap: onChat,
              ),
            ),
          if (onNavigate != null)
            Positioned(
              right: DriverSpacing.screenEdge,
              bottom: 248,
              child: _DriverRideBoltMapFab(
                colors: colors,
                icon: Icons.navigation_rounded,
                highlighted: true,
                onTap: onNavigate,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: scrollableInfoCard
                    ? MediaQuery.sizeOf(context).height * 0.78
                    : double.infinity,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DriverSpacing.screenEdge,
                    ),
                    child: scrollableInfoCard
                        ? ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: maxInfoHeight),
                            child: SingleChildScrollView(
                              child: infoCard,
                            ),
                          )
                        : infoCard,
                  ),
                  const SizedBox(height: DriverSpacing.sm),
                  bottomBar,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DriverRideBoltInfoCard extends StatelessWidget {
  const DriverRideBoltInfoCard({
    super.key,
    required this.colors,
    required this.typography,
    required this.heroPrimary,
    this.heroSecondary,
    required this.focusAddress,
    this.riderName,
    this.riderRating,
    this.farePill,
    this.onOpenRouteDetails,
    this.onNavigate,
    this.navigateLabel,
    this.navAppLabel,
    this.onCopyAddress,
    this.extra,
    this.assistBanner,
    this.successTone = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String heroPrimary;
  final String? heroSecondary;
  final String focusAddress;
  final String? riderName;
  final String? riderRating;
  final String? farePill;
  final VoidCallback? onOpenRouteDetails;
  final VoidCallback? onNavigate;
  final String? navigateLabel;
  final String? navAppLabel;
  final VoidCallback? onCopyAddress;
  final Widget? extra;
  final Widget? assistBanner;
  final bool successTone;

  @override
  Widget build(BuildContext context) {
    return DriverRidePremiumStyle.glassSurface(
      colors: colors,
      borderRadius: DriverRadius.lgAll,
      blurSigma: 24,
      tintOpacity: 0.9,
      borderColor: successTone
          ? colors.success.withValues(alpha: 0.35)
          : colors.border.withValues(alpha: 0.45),
      boxShadow: DriverShadows.floating(colors),
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.lg,
        DriverSpacing.md,
        DriverSpacing.lg,
        DriverSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: typography.displaySmall.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.05,
                      color: colors.text,
                    ),
                    children: [
                      TextSpan(text: heroPrimary),
                      if (heroSecondary != null && heroSecondary!.isNotEmpty)
                        TextSpan(
                          text: ' $heroSecondary',
                          style: typography.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (onOpenRouteDetails != null)
                IconButton(
                  onPressed: onOpenRouteDetails,
                  icon: Icon(Icons.list_rounded, color: colors.text),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.backgroundAlt,
                  ),
                ),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          if (focusAddress.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    focusAddress,
                    style: typography.bodyLarge.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (onCopyAddress != null)
                  IconButton(
                    onPressed: onCopyAddress,
                    tooltip: DriverStrings.copyAddress,
                    icon: Icon(Icons.copy_rounded, color: colors.primary),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.backgroundAlt,
                    ),
                  ),
              ],
            ),
            if (onNavigate != null && navigateLabel != null) ...[
              const SizedBox(height: DriverSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation_rounded),
                  label: Text(navigateLabel!),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (navAppLabel != null && navAppLabel!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  DriverStrings.navigateOpensIn(navAppLabel!),
                  textAlign: TextAlign.center,
                  style: typography.labelSmall.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ],
          if (assistBanner != null) ...[
            const SizedBox(height: DriverSpacing.sm),
            assistBanner!,
          ],
          if (riderName != null || farePill != null) ...[
            const SizedBox(height: DriverSpacing.md),
            Row(
              children: [
                if (riderName != null)
                  Expanded(
                    child: Text(
                      riderRating != null
                          ? '$riderName · $riderRating'
                          : riderName!,
                      style: typography.titleMedium.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (farePill != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.backgroundAlt,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      farePill!,
                      style: typography.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (extra != null) ...[
            const SizedBox(height: DriverSpacing.md),
            extra!,
          ],
        ],
      ),
    );
  }
}

String driverRideBoltWaitLabel(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String? driverRideBoltFarePill(String? amountLabel) {
  if (amountLabel == null || amountLabel.trim().isEmpty) return null;
  final normalized = amountLabel.replaceFirst('EUR ', '€');
  return DriverStrings.rideFarePill(normalized);
}

String driverRideBoltFareHero(String? amountLabel) {
  if (amountLabel == null || amountLabel.trim().isEmpty) return '—';
  return amountLabel.replaceFirst('EUR ', '€');
}

Future<void> showDriverRideRouteDetailsSheet({
  required BuildContext context,
  required DriverColors colors,
  required DriverTypography typography,
  required String destinationAddress,
  String? farePill,
  String? riderName,
  required VoidCallback onContact,
  required VoidCallback onNavigate,
  VoidCallback? onChangeNavigation,
  VoidCallback? onCancelRide,
  VoidCallback? onToggleRequests,
  bool requestsPaused = false,
  String? navAppLabel,
  String? rideRequestId,
  DriverRideCommunicationPhase? smartPingPhase,
  bool smartPingOnMyWayOnly = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: DriverRidePremiumStyle.glassSurface(
          colors: colors,
          borderRadius: DriverRadius.sheetTop,
          blurSigma: 26,
          tintOpacity: 0.92,
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
              DriverRidePremiumStyle.sheetHandle(colors),
              const SizedBox(height: DriverSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DriverStrings.rideRouteDetailsTitle,
                      style: typography.titleLarge.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (farePill != null) ...[
                const SizedBox(height: 4),
                Text(
                  farePill,
                  style: typography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: DriverSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_rounded, color: colors.error, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      destinationAddress,
                      style: typography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (rideRequestId != null && smartPingPhase != null) ...[
                const SizedBox(height: DriverSpacing.lg),
                DriverSmartPingBanner(
                  rideRequestId: rideRequestId,
                  phase: smartPingPhase,
                  presentation: DriverSmartPingPresentation.inline,
                  onlyOnMyWay: smartPingOnMyWayOnly,
                ),
              ],
              if (onCancelRide != null) ...[
                const SizedBox(height: DriverSpacing.lg),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onCancelRide();
                  },
                  icon: Icon(Icons.close_rounded, color: colors.error),
                  label: Text(
                    DriverStrings.cancelOrder,
                    style: typography.labelLarge.copyWith(
                      color: colors.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const Divider(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.person_outline_rounded, color: colors.text),
                title: Text(
                  riderName != null
                      ? DriverStrings.rideRouteDetailsContact(riderName)
                      : DriverStrings.contactRider,
                  style: typography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onContact();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.navigation_rounded, color: colors.primary),
                title: Text(
                  navAppLabel ?? 'Waze',
                  style: typography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                trailing: onChangeNavigation != null
                    ? TextButton(
                        onPressed: onChangeNavigation,
                        child: Text(DriverStrings.rideRouteDetailsChangeNav),
                      )
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  onNavigate();
                },
              ),
              if (onToggleRequests != null) ...[
                const SizedBox(height: DriverSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onToggleRequests();
                  },
                  icon: Icon(
                    requestsPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pan_tool_alt_rounded,
                  ),
                  label: Text(
                    requestsPaused
                        ? DriverStrings.resumeRequests
                        : DriverStrings.stopNewRequests,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showDriverRideSafetyToolkitSheet({
  required BuildContext context,
  required WidgetRef ref,
  required DriverColors colors,
  required DriverTypography typography,
  required String? rideRequestId,
  required bool canShareTrip,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: DriverRidePremiumStyle.glassSurface(
          colors: colors,
          borderRadius: DriverRadius.sheetTop,
          blurSigma: 26,
          tintOpacity: 0.92,
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
              DriverRidePremiumStyle.sheetHandle(colors),
              const SizedBox(height: DriverSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DriverStrings.rideSafetyToolkitTitle,
                      style: typography.titleLarge.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                DriverStrings.rideSafetyToolkitBody,
                style: typography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: DriverSpacing.lg),
              FilledButton.icon(
                onPressed: () async {
                  final driverId = ref.read(driverIdProvider).valueOrNull;
                  if (driverId != null && driverId.isNotEmpty) {
                    try {
                      await ref.read(driverDataServiceProvider).insertSafetyEvent(
                            driverId,
                            'emergency_call',
                            rideRequestId: rideRequestId,
                          );
                    } catch (_) {}
                  }
                  if (ctx.mounted) {
                    await launchUrl(Uri.parse('tel:112'));
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.card,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.emergency_rounded),
                label: Text(DriverStrings.call112),
              ),
              const SizedBox(height: DriverSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.share_outlined,
                  color: canShareTrip ? colors.text : colors.textMuted,
                ),
                title: Text(
                  DriverStrings.shareTripDetails,
                  style: typography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: canShareTrip ? colors.text : colors.textMuted,
                  ),
                ),
                subtitle: Text(
                  canShareTrip
                      ? DriverStrings.shareTripSubtitleActive
                      : DriverStrings.shareTripSubtitleInactive,
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                onTap: canShareTrip && rideRequestId != null
                    ? () async {
                        final url = await ref
                            .read(driverDataServiceProvider)
                            .getOrCreateRideShareUrl(rideRequestId);
                        if (url != null && ctx.mounted) {
                          await Share.share(url);
                        }
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DriverRideBoltMapFab extends StatelessWidget {
  const _DriverRideBoltMapFab({
    required this.colors,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final DriverColors colors;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted
          ? colors.primary.withValues(alpha: 0.92)
          : colors.card.withValues(alpha: 0.94),
      elevation: 4,
      shadowColor: colors.text.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: highlighted ? colors.onPrimary : colors.text,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _WaitHereChip extends StatelessWidget {
  const _WaitHereChip({
    required this.colors,
    required this.typography,
  });

  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.text.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          DriverStrings.rideMapWaitHere,
          style: typography.labelLarge.copyWith(
            color: colors.card,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DriverRideBoltMap extends StatefulWidget {
  const _DriverRideBoltMap({
    required this.colors,
    required this.phase,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.driverLat,
    this.driverLng,
  });

  final DriverColors colors;
  final DriverRideBoltPhase phase;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? driverLat;
  final double? driverLng;

  @override
  State<_DriverRideBoltMap> createState() => _DriverRideBoltMapState();
}

class _DriverRideBoltMapState extends State<_DriverRideBoltMap> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _lineManager;
  bool _initialized = false;
  int _cameraTick = 0;

  void _onCameraChange(CameraChangedEventData _) {
    if (!mounted) return;
    setState(() => _cameraTick++);
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    await _mapboxMap!.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await _mapboxMap!.compass.updateSettings(CompassSettings(enabled: false));
    await _mapboxMap!.attribution
        .updateSettings(AttributionSettings(enabled: false));
    await _mapboxMap!.logo.updateSettings(LogoSettings(enabled: false));
    _lineManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();
    _initialized = true;
    _fitAndDraw();
  }

  @override
  void didUpdateWidget(_DriverRideBoltMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_initialized) _fitAndDraw();
  }

  Future<void> _fitAndDraw() async {
    if (_mapboxMap == null) return;
    final pLat = widget.pickupLat;
    final pLng = widget.pickupLng;
    final dLat = widget.destLat;
    final dLng = widget.destLng;
    final hasPickup = driverMapCoordIsValid(pLat, pLng);
    final hasDest = driverMapCoordIsValid(dLat, dLng);
    if (!hasPickup && !hasDest) return;

    final boundsPoints = <List<double>>[];
    if (hasPickup) boundsPoints.add([pLng!, pLat!]);
    if (hasDest) boundsPoints.add([dLng!, dLat!]);

    var minLat = boundsPoints.first[1];
    var maxLat = boundsPoints.first[1];
    var minLng = boundsPoints.first[0];
    var maxLng = boundsPoints.first[0];
    for (final p in boundsPoints) {
      minLat = math.min(minLat, p[1]);
      maxLat = math.max(maxLat, p[1]);
      minLng = math.min(minLng, p[0]);
      maxLng = math.max(maxLng, p[0]);
    }
    final latPad = (maxLat - minLat) * 0.3 + 0.012;
    final lngPad = (maxLng - minLng) * 0.3 + 0.012;

    var camera = await _mapboxMap!.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(minLng - lngPad, minLat - latPad)),
        northeast: Point(coordinates: Position(maxLng + lngPad, maxLat + latPad)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 72, left: 24, bottom: 300, right: 24),
      null,
      null,
      null,
      null,
    );
    final zoom = camera.zoom;
    if (zoom != null && zoom < 9.5) {
      camera = CameraOptions(
        center: camera.center,
        zoom: 9.5,
        pitch: camera.pitch ?? 22,
        bearing: camera.bearing,
      );
    }
    await _mapboxMap!.setCamera(camera);

    final drvLat = widget.driverLat;
    final drvLng = widget.driverLng;
    final isCompleted = widget.phase == DriverRideBoltPhase.completed;
    final showDriverLeg = !isCompleted &&
        drvLat != null &&
        drvLng != null &&
        hasPickup &&
        driverMapIncludeDriverLeg(
          driverLat: drvLat,
          driverLng: drvLng,
          pickupLat: pLat!,
          pickupLng: pLng!,
        );

    if (_lineManager != null) {
      await _lineManager!.deleteAll();
      if (showDriverLeg &&
          widget.phase != DriverRideBoltPhase.inProgress) {
        await _lineManager!.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: [
            Position(drvLng!, drvLat!),
            Position(pLng!, pLat!),
          ]),
          lineColor: widget.colors.textMuted.withValues(alpha: 0.45).toARGB32(),
          lineWidth: 2.5,
        ));
      }
      if (hasDest) {
        final fromLng = widget.phase == DriverRideBoltPhase.inProgress &&
                showDriverLeg
            ? drvLng!
            : (hasPickup ? pLng! : dLng!);
        final fromLat = widget.phase == DriverRideBoltPhase.inProgress &&
                showDriverLeg
            ? drvLat!
            : (hasPickup ? pLat! : dLat!);
        await _lineManager!.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: [
            Position(fromLng, fromLat),
            Position(dLng!, dLat!),
          ]),
          lineColor: isCompleted
              ? widget.colors.success.toARGB32()
              : widget.colors.primary.toARGB32(),
          lineWidth: isCompleted ? 4.5 : 4,
        ));
      }
    }

    if (mounted) setState(() => _cameraTick++);
  }

  @override
  Widget build(BuildContext context) {
    final themeId = HeyCabyAppChrome.themeIdOf(context);
    final hasPickup =
        driverMapCoordIsValid(widget.pickupLat, widget.pickupLng);
    final hasDest = driverMapCoordIsValid(widget.destLat, widget.destLng);
    final hasMapData = hasPickup || hasDest;
    final fallbackCenter = hasDest
        ? Point(
            coordinates: Position(widget.destLng!, widget.destLat!),
          )
        : hasPickup
            ? Point(
                coordinates: Position(widget.pickupLng!, widget.pickupLat!),
              )
            : Point(coordinates: Position(4.9041, 52.3676));
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          MapWidget(
            key: ValueKey(
              'driver-ride-bolt-map-$themeId-${widget.phase.name}-'
              '${widget.pickupLat}-${widget.destLat}',
            ),
            styleUri: mapboxStyleUriForTheme(themeId),
            cameraOptions: hasMapData
                ? null
                : CameraOptions(
                    center: fallbackCenter,
                    zoom: 14.2,
                    pitch: 22,
                  ),
            onMapCreated: hasMapData ? _onMapCreated : null,
            onCameraChangeListener: hasMapData ? _onCameraChange : null,
          ),
          if (hasMapData)
            DriverRideMapPinsOverlay(
              mapboxMap: _mapboxMap,
              pickupLat: widget.pickupLat,
              pickupLng: widget.pickupLng,
              destinationLat: widget.destLat,
              destinationLng: widget.destLng,
              pickupColor: widget.colors.warning,
              dropoffColor: widget.colors.error,
              cameraTick: _cameraTick,
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.colors.background.withValues(alpha: 0.06),
                  widget.colors.background.withValues(alpha: 0.02),
                  widget.colors.background.withValues(alpha: 0.55),
                  widget.colors.background.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.35, 0.72, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
