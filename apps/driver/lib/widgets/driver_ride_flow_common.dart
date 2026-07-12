import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_ride_action_chip.dart';
import '../ui/driver_ride_card.dart';
import '../ui/driver_status_badge.dart';
import 'driver_ride_premium_style.dart';

/// Guards map camera fitting from null island / stale GPS that zooms to a globe.
bool driverMapCoordIsValid(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  if (lat.abs() > 90 || lng.abs() > 180) return false;
  if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
  return true;
}

bool driverMapIncludeDriverLeg({
  required double driverLat,
  required double driverLng,
  required double pickupLat,
  required double pickupLng,
  double maxKm = 120,
}) {
  if (!driverMapCoordIsValid(driverLat, driverLng)) return false;
  const r = 6371.0;
  double rad(double deg) => deg * math.pi / 180.0;
  final dLat = rad(pickupLat - driverLat);
  final dLng = rad(pickupLng - driverLng);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(driverLat)) *
          math.cos(rad(pickupLat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final km = r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return km <= maxKm;
}

/// Shared scaffold for core ride-flow screens.
class DriverRideFlowScaffold extends StatelessWidget {
  const DriverRideFlowScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.content,
    this.bottomBar,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback? onBack;
  final Widget content;
  final Widget? bottomBar;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _DriverRideMapBackdrop(
            pickupLat: pickupLat,
            pickupLng: pickupLng,
            destLat: destLat,
            destLng: destLng,
            accentColor: colors.primary,
            errorColor: colors.error,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.background.withValues(alpha: 0.04),
                  colors.background.withValues(alpha: 0.18),
                  colors.background.withValues(alpha: 0.88),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final topGap = (constraints.maxHeight * 0.24)
                          .clamp(96.0, 220.0)
                          .toDouble();
                      return SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          DriverSpacing.screenEdge,
                          topGap,
                          DriverSpacing.screenEdge,
                          bottomBar == null
                              ? DriverSpacing.xl +
                                  MediaQuery.paddingOf(context).bottom
                              : 280,
                        ),
                        child: DriverRidePremiumStyle.glassSurface(
                          colors: colors,
                          padding: const EdgeInsets.fromLTRB(
                            DriverSpacing.md,
                            DriverSpacing.md,
                            DriverSpacing.md,
                            DriverSpacing.lg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DriverRidePremiumStyle.sheetHandle(colors),
                              const SizedBox(height: DriverSpacing.md),
                              DriverRidePremiumStyle.modalTopBar(
                                colors: colors,
                                title: title,
                                titleStyle: typography.titleLarge.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w900,
                                ),
                                onBack: onBack,
                              ),
                              const SizedBox(height: DriverSpacing.xl),
                              content,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (bottomBar != null) bottomBar!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverRideMapBackdrop extends StatefulWidget {
  const _DriverRideMapBackdrop({
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.accentColor,
    this.errorColor,
  });

  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final Color? accentColor;
  final Color? errorColor;

  @override
  State<_DriverRideMapBackdrop> createState() => _DriverRideMapBackdropState();
}

class _DriverRideMapBackdropState extends State<_DriverRideMapBackdrop> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _lineManager;
  PointAnnotationManager? _pointManager;
  bool _initialized = false;

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    await _mapboxMap!.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await _mapboxMap!.compass.updateSettings(CompassSettings(enabled: false));
    await _mapboxMap!.attribution
        .updateSettings(AttributionSettings(enabled: false));
    await _mapboxMap!.logo.updateSettings(LogoSettings(enabled: false));
    _lineManager =
        await _mapboxMap!.annotations.createPolylineAnnotationManager();
    _pointManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();
    _initialized = true;
    _fitAndDraw();
  }

  @override
  void didUpdateWidget(_DriverRideMapBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_initialized &&
        (oldWidget.pickupLat != widget.pickupLat ||
            oldWidget.destLat != widget.destLat)) {
      _fitAndDraw();
    }
  }

  Future<void> _fitAndDraw() async {
    if (_mapboxMap == null) return;
    final pLat = widget.pickupLat;
    final pLng = widget.pickupLng;
    final dLat = widget.destLat;
    final dLng = widget.destLng;
    if (pLat == null || pLng == null || dLat == null || dLng == null) return;

    final minLat = pLat < dLat ? pLat : dLat;
    final maxLat = pLat > dLat ? pLat : dLat;
    final minLng = pLng < dLng ? pLng : dLng;
    final maxLng = pLng > dLng ? pLng : dLng;
    final latPad = (maxLat - minLat) * 0.3 + 0.01;
    final lngPad = (maxLng - minLng) * 0.3 + 0.01;

    final camera = await _mapboxMap!.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest:
            Point(coordinates: Position(minLng - lngPad, minLat - latPad)),
        northeast:
            Point(coordinates: Position(maxLng + lngPad, maxLat + latPad)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 40, left: 20, bottom: 40, right: 20),
      null,
      null,
      null,
      null,
    );
    await _mapboxMap!.setCamera(camera);

    final route = await RoutingService(
      accessToken: const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
    ).fetchRoute(
      fromLat: pLat,
      fromLng: pLng,
      toLat: dLat,
      toLng: dLng,
    );
    if (!mounted) return;
    final routeGeometry = route?.coordinates
            .map((point) => Position(point[0], point[1]))
            .toList(growable: false) ??
        const <Position>[];

    // Never present a geometric shortcut as a real road route.
    if (_lineManager != null && routeGeometry.length >= 2) {
      await _lineManager!.deleteAll();
      await _lineManager!.create(PolylineAnnotationOptions(
        geometry: LineString(coordinates: routeGeometry),
        lineColor: (widget.accentColor ?? Colors.blue).toARGB32(),
        lineWidth: 3,
      ));
    }

    // Markers
    if (_pointManager != null) {
      await _pointManager!.deleteAll();
      await _pointManager!.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(pLng, pLat)),
        iconImage: 'marker-15',
        iconSize: 1.5,
        iconColor: (widget.accentColor ?? Colors.green).toARGB32(),
      ));
      await _pointManager!.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(dLng, dLat)),
        iconImage: 'marker-15',
        iconSize: 1.5,
        iconColor: (widget.errorColor ?? Colors.red).toARGB32(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeId = HeyCabyAppChrome.themeIdOf(context);
    final hasCoords = widget.pickupLat != null && widget.destLat != null;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          MapWidgetOrPlaceholder(
            key: ValueKey('driver-ride-map-$themeId'),
            styleUri: mapboxStyleUriForTheme(themeId),
            cameraOptions: hasCoords
                ? null
                : CameraOptions(
                    center: Point(coordinates: Position(4.9041, 52.3676)),
                    zoom: 14.2,
                    pitch: 18,
                  ),
            onMapCreated: hasCoords ? _onMapCreated : null,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.02),
                  Colors.black.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.70),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned bottom actions — primary CTA + optional secondary rows.
class DriverRideFlowBottomBar extends StatelessWidget {
  const DriverRideFlowBottomBar({
    super.key,
    required this.colors,
    required this.typography,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.primaryIcon,
    this.primaryVariant = DriverButtonVariant.primary,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryLoading = false,
    this.secondaryVariant = DriverButtonVariant.outline,
    this.tertiaryLabel,
    this.onTertiary,
    this.tertiaryDestructive = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final IconData? primaryIcon;
  final DriverButtonVariant primaryVariant;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool secondaryLoading;
  final DriverButtonVariant secondaryVariant;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;
  final bool tertiaryDestructive;

  @override
  Widget build(BuildContext context) {
    return DriverRidePremiumStyle.glassSurface(
      colors: colors,
      borderRadius: DriverRadius.sheetTop,
      blurSigma: 26,
      tintOpacity: 0.8,
      boxShadow: DriverShadows.floating(colors),
      padding: EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.md,
        DriverSpacing.screenEdge,
        DriverSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DriverRidePremiumStyle.sheetHandle(colors),
          const SizedBox(height: DriverSpacing.md),
          DriverButton(
            label: primaryLabel,
            icon: primaryIcon,
            onPressed: onPrimary,
            loading: primaryLoading,
            variant: primaryVariant,
            size: DriverButtonSize.lg,
            colors: colors,
            typography: typography,
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: DriverSpacing.sm),
            DriverButton(
              label: secondaryLabel!,
              onPressed: onSecondary,
              loading: secondaryLoading,
              variant: secondaryVariant,
              colors: colors,
              typography: typography,
            ),
          ],
          if (tertiaryLabel != null) ...[
            const SizedBox(height: DriverSpacing.sm),
            DriverButton(
              label: tertiaryLabel!,
              onPressed: onTertiary,
              variant: tertiaryDestructive
                  ? DriverButtonVariant.destructive
                  : DriverButtonVariant.ghost,
              colors: colors,
              typography: typography,
            ),
          ],
        ],
      ),
    );
  }
}

/// Trip summary card used across ride-flow screens.
class DriverRideTripSummary extends StatelessWidget {
  const DriverRideTripSummary({
    super.key,
    required this.colors,
    required this.typography,
    required this.pickupLabel,
    required this.dropoffLabel,
    this.riderName,
    this.fareLabel,
    this.statusLabel,
    this.statusTone = DriverStatusTone.success,
    this.staggerIndex = 0,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupLabel;
  final String dropoffLabel;
  final String? riderName;
  final String? fareLabel;
  final String? statusLabel;
  final DriverStatusTone statusTone;
  final int staggerIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (riderName != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.md,
              vertical: DriverSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_rounded, size: 18, color: colors.primary),
                const SizedBox(width: DriverSpacing.xs),
                Flexible(
                  child: Text(
                    riderName!,
                    style: typography.titleSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ).driverFadeSlideIn(staggerIndex: staggerIndex),
          const SizedBox(height: DriverSpacing.md),
        ],
        DriverRideCard(
          colors: colors,
          typography: typography,
          pickupLabel: pickupLabel,
          dropoffLabel: dropoffLabel,
          fareLabel: fareLabel,
          statusLabel: statusLabel,
          statusTone: statusTone,
        ).driverFadeSlideIn(staggerIndex: staggerIndex + 1),
      ],
    );
  }
}

/// Premium state header for the current ride phase.
class DriverRidePhaseHero extends StatelessWidget {
  const DriverRidePhaseHero({
    super.key,
    required this.colors,
    required this.typography,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    this.tone = DriverStatusTone.success,
    this.metric,
    this.staggerIndex = 0,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final DriverStatusTone tone;
  final String? metric;
  final int staggerIndex;

  Color get _toneColor {
    return switch (tone) {
      DriverStatusTone.online || DriverStatusTone.success => colors.primary,
      DriverStatusTone.busy || DriverStatusTone.warning => colors.warning,
      DriverStatusTone.error => colors.error,
      DriverStatusTone.offline ||
      DriverStatusTone.neutral =>
        colors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final toneColor = _toneColor;

    return Container(
      padding: const EdgeInsets.all(DriverSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            toneColor.withValues(alpha: 0.16),
            colors.card,
            colors.surface.withValues(alpha: 0.82),
          ],
        ),
        border: Border.all(color: toneColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.92),
              borderRadius: DriverRadius.mdAll,
              boxShadow: [
                BoxShadow(
                  color: toneColor.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(icon, color: toneColor, size: 29),
          ),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: typography.labelMedium.copyWith(
                    color: toneColor,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: typography.titleLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
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
          if (metric != null) ...[
            const SizedBox(width: DriverSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DriverSpacing.md,
                vertical: DriverSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                metric!,
                style: typography.labelMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    ).driverFadeSlideIn(staggerIndex: staggerIndex);
  }
}

class DriverRideFlowAction {
  const DriverRideFlowAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
}

/// Grid of ride quick actions.
class DriverRideActionGrid extends StatelessWidget {
  const DriverRideActionGrid({
    super.key,
    required this.colors,
    required this.typography,
    required this.actions,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final List<DriverRideFlowAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = actions.length > 1 && constraints.maxWidth >= 320;
        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: DriverSpacing.sm),
                DriverRideActionChip(
                  label: actions[i].label,
                  icon: actions[i].icon,
                  colors: colors,
                  typography: typography,
                  onTap: actions[i].enabled ? actions[i].onTap : null,
                ),
              ],
            ],
          );
        }

        return Wrap(
          spacing: DriverSpacing.sm,
          runSpacing: DriverSpacing.sm,
          children: [
            for (final action in actions)
              SizedBox(
                width: (constraints.maxWidth - DriverSpacing.sm) / 2,
                child: DriverRideActionChip(
                  label: action.label,
                  icon: action.icon,
                  colors: colors,
                  typography: typography,
                  onTap: action.enabled ? action.onTap : null,
                ),
              ),
          ],
        );
      },
    ).driverFadeSlideIn(staggerIndex: 2);
  }
}
