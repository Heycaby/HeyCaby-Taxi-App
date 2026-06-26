import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_location_provider.dart';
import '../services/driver_data_service.dart';
import '../services/driver_navigation_launcher.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_performance_flow_common.dart';
import 'driver_hotspots_models.dart';

const _kHotspotsScoresSource = 'hc_hotspots_scores_src';
const _kHotspotsScoresLayer = 'hc_hotspots_scores_layer';

enum _HotspotRenderMode { aggregateTiles, detailCircles }

class _HotspotTileCell {
  _HotspotTileCell({
    required this.gridX,
    required this.gridY,
    required this.cellSizeDeg,
  });

  final int gridX;
  final int gridY;
  final double cellSizeDeg;
  int totalDemand = 0;

  double get west => gridX * cellSizeDeg;
  double get east => (gridX + 1) * cellSizeDeg;
  double get south => gridY * cellSizeDeg;
  double get north => (gridY + 1) * cellSizeDeg;
}

class DriverHotspotsScreen extends ConsumerStatefulWidget {
  const DriverHotspotsScreen({super.key});

  @override
  ConsumerState<DriverHotspotsScreen> createState() => _DriverHotspotsScreenState();
}

class _DriverHotspotsScreenState extends ConsumerState<DriverHotspotsScreen> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleManager;
  PolygonAnnotationManager? _polygonManager;
  List<ZoneDemand> _zones = const [];
  Timer? _pulseTimer;
  Timer? _cameraTimer;
  int _pulsePhase = 0;
  double _currentZoom = 10.8;
  _HotspotRenderMode _renderMode = _HotspotRenderMode.aggregateTiles;
  final bool _enableAggregatedTiles = true;

  @override
  void dispose() {
    _cameraTimer?.cancel();
    _pulseTimer?.cancel();
    _circleManager?.deleteAll();
    _polygonManager?.deleteAll();
    super.dispose();
  }

  List<ZoneDemand> get _filtered {
    return _zones.toList()..sort((a, b) => b.waitingPassengers.compareTo(a.waitingPassengers));
  }

  ZoneDemand? get _bestZone {
    final f = _filtered;
    if (f.isEmpty) return null;
    return f.first;
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    _circleManager = await map.annotations.createCircleAnnotationManager();
    _polygonManager = await map.annotations.createPolygonAnnotationManager();
    await Future.wait([
      map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
      map.compass.updateSettings(CompassSettings(enabled: true)),
      map.attribution.updateSettings(AttributionSettings(enabled: false)),
      map.logo.updateSettings(LogoSettings(enabled: false)),
    ]);
    await map.setBounds(
      CameraBoundsOptions(
        bounds: CoordinateBounds(
          southwest: Point(coordinates: Position(3.31, 50.75)),
          northeast: Point(coordinates: Position(7.23, 53.55)),
          infiniteBounds: false,
        ),
        minZoom: 7.0,
        maxZoom: 18.0,
      ),
    );
    _startCameraMonitor();
    await _refreshHotspots();
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _mapboxMap;
    final colors = ref.read(colorsProvider);
    if (map == null) return;
    final accent = colors.accent;
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: accent.toARGB32(),
      pulsingMaxRadius: 42,
      showAccuracyRing: true,
      accuracyRingColor: accent.withValues(alpha: 0.18).toARGB32(),
    ));
    await _flyToBestOrUser();
  }

  Future<void> _flyToBestOrUser() async {
    final map = _mapboxMap;
    if (map == null) return;
    final best = _bestZone;
    if (best?.centerLng != null && best?.centerLat != null) {
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(best!.centerLng!, best.centerLat!)),
          zoom: 11.2,
        ),
        MapAnimationOptions(duration: 900),
      );
      return;
    }
    final pos = ref.read(driverLocationProvider).valueOrNull;
    if (pos != null) {
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 11.5,
        ),
        MapAnimationOptions(duration: 900),
      );
    }
  }

  Future<void> _recenterMyLocation() async {
    HapticService.lightTap();
    await ref.read(driverLocationProvider.notifier).refresh();
    final pos = ref.read(driverLocationProvider).valueOrNull;
    final map = _mapboxMap;
    if (pos == null || map == null) return;
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 14.0,
      ),
      MapAnimationOptions(duration: 700),
    );
  }

  void _startCameraMonitor() {
    _cameraTimer?.cancel();
    _cameraTimer = Timer.periodic(const Duration(milliseconds: 650), (_) async {
      final map = _mapboxMap;
      if (!mounted || map == null) return;
      try {
        final camera = await map.getCameraState();
        final zoom = camera.zoom;
        if ((zoom - _currentZoom).abs() < 0.18) return;
        _currentZoom = zoom;
        await _drawHotspots(_zones, force: true);
      } catch (_) {
        // camera polling should never crash UI
      }
    });
  }

  _HotspotRenderMode _resolveRenderMode(double zoom) {
    if (!_enableAggregatedTiles) return _HotspotRenderMode.detailCircles;
    switch (_renderMode) {
      case _HotspotRenderMode.aggregateTiles:
        return zoom > 13.2
            ? _HotspotRenderMode.detailCircles
            : _HotspotRenderMode.aggregateTiles;
      case _HotspotRenderMode.detailCircles:
        return zoom < 11.8
            ? _HotspotRenderMode.aggregateTiles
            : _HotspotRenderMode.detailCircles;
    }
  }

  double _cellSizeForZoom(double zoom) {
    if (zoom < 10.4) return 0.05;
    if (zoom < 11.8) return 0.03;
    return 0.02;
  }

  List<_HotspotTileCell> _aggregateCells(List<ZoneDemand> zones, double zoom) {
    final cell = _cellSizeForZoom(zoom);
    final buckets = <String, _HotspotTileCell>{};
    for (final z in zones) {
      final lat = z.centerLat;
      final lng = z.centerLng;
      if (lat == null || lng == null) continue;
      final gx = (lng / cell).floor();
      final gy = (lat / cell).floor();
      final key = '$gx,$gy';
      final bucket = buckets.putIfAbsent(
        key,
        () => _HotspotTileCell(gridX: gx, gridY: gy, cellSizeDeg: cell),
      );
      bucket.totalDemand += z.waitingPassengers;
    }
    final out = buckets.values
        .where((e) => e.totalDemand >= 2)
        .toList()
      ..sort((a, b) => b.totalDemand.compareTo(a.totalDemand));
    if (zoom < 10.4 && out.length > 24) return out.take(24).toList();
    return out;
  }

  Future<void> _refreshHotspots() async {
    ref.invalidate(zoneDemandProvider);
    final zones = await ref.read(zoneDemandProvider.future);
    if (!mounted) return;
    setState(() => _zones = zones);
    await _drawHotspots(zones, force: true);
  }

  void _restartPulseIfNeeded(List<ZoneDemand> zones) {
    final anyHot = zones.any((z) => z.waitingPassengers >= 20);
    if (anyHot && _pulseTimer == null) {
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
        if (!mounted) return;
        setState(() => _pulsePhase = (_pulsePhase + 1) % 2);
        _drawHotspots(_zones, force: true);
      });
    } else if (!anyHot) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
    }
  }

  Future<void> _drawHotspots(List<ZoneDemand> zones, {bool force = false}) async {
    final colors = ref.read(colorsProvider);
    if (_circleManager == null || _polygonManager == null || _mapboxMap == null) return;
    final nextMode = _resolveRenderMode(_currentZoom);
    final modeChanged = nextMode != _renderMode;
    if (modeChanged) {
      _renderMode = nextMode;
    } else if (!force) {
      return;
    }

    if (_renderMode == _HotspotRenderMode.aggregateTiles) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
      await _circleManager!.deleteAll();
      final cells = _aggregateCells(zones, _currentZoom);
      final polygons = <PolygonAnnotationOptions>[];
      for (final c in cells) {
        final tier = hotspotTierForDemand(c.totalDemand);
        final fill = hotspotHeatInnerArgb(colors, tier);
        const gap = 0.00045;
        final west = c.west + gap;
        final east = c.east - gap;
        final south = c.south + gap;
        final north = c.north - gap;
        polygons.add(
          PolygonAnnotationOptions(
            geometry: Polygon(
              coordinates: [
                [
                  Position(west, south),
                  Position(east, south),
                  Position(east, north),
                  Position(west, north),
                  Position(west, south),
                ],
              ],
            ),
            fillColor: fill,
            fillOpacity: 0.86,
            fillOutlineColor: colors.card.toARGB32(),
          ),
        );
      }
      await _polygonManager!.deleteAll();
      if (polygons.isNotEmpty) await _polygonManager!.createMulti(polygons);
      await _syncScoreLayer(_mapboxMap!, const [], colors);
      return;
    }

    await _polygonManager!.deleteAll();
    await _circleManager!.deleteAll();
    _restartPulseIfNeeded(zones);
    final circles = <CircleAnnotationOptions>[];
    for (final z in zones) {
      if (z.centerLat == null || z.centerLng == null) continue;
      final tier = hotspotTierForDemand(z.waitingPassengers);
      final outer = hotspotHeatOuterArgb(colors, tier);
      final inner = hotspotHeatInnerArgb(colors, tier);
      var outerR = ((z.radiusM ?? 520) / 7).clamp(22.0, 88.0);
      var innerR = (outerR * 0.42).clamp(14.0, 36.0);
      if (tier == HotspotDemandTier.high) {
        outerR *= _pulsePhase == 0 ? 1.0 : 1.06;
      }
      circles.add(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(z.centerLng!, z.centerLat!)),
          circleColor: outer,
          circleRadius: outerR,
        ),
      );
      circles.add(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(z.centerLng!, z.centerLat!)),
          circleColor: inner,
          circleRadius: innerR,
          circleStrokeColor: colors.card.toARGB32(),
          circleStrokeWidth: 2,
        ),
      );
    }
    if (circles.isNotEmpty) await _circleManager!.createMulti(circles);
    await _syncScoreLayer(_mapboxMap!, zones, colors);
  }

  Future<void> _syncScoreLayer(MapboxMap map, List<ZoneDemand> zones, HeyCabyColorTokens colors) async {
    try {
      final features = <Map<String, dynamic>>[];
      for (final z in zones) {
        if (z.centerLat == null || z.centerLng == null) continue;
        if (z.waitingPassengers < 2) continue;
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [z.centerLng, z.centerLat],
          },
          'properties': {'score': z.waitingPassengers.toString()},
        });
      }
      final geoJson = jsonEncode({'type': 'FeatureCollection', 'features': features});
      final exists = await map.style.styleSourceExists(_kHotspotsScoresSource);
      if (exists) {
        await map.style.setStyleSourceProperty(_kHotspotsScoresSource, 'data', geoJson);
      } else if (features.isNotEmpty) {
        await map.style.addSource(GeoJsonSource(id: _kHotspotsScoresSource, data: geoJson));
        final halo = (ThemeData.estimateBrightnessForColor(colors.card) == Brightness.dark
                ? colors.bg
                : colors.card)
            .withValues(alpha: 0.94)
            .toARGB32();
        await map.style.addLayer(
          SymbolLayer(
            id: _kHotspotsScoresLayer,
            sourceId: _kHotspotsScoresSource,
            textFieldExpression: ['get', 'score'],
            textSize: 15,
            textColor: colors.card.toARGB32(),
            textHaloColor: halo,
            textHaloWidth: 1.8,
          ),
        );
      }
      if (features.isEmpty && exists) {
        await map.style.setStyleSourceProperty(_kHotspotsScoresSource, 'data', geoJson);
      }
    } catch (_) {}
  }

  Future<void> _openNavigationChooser(ZoneDemand zone) async {
    final lat = zone.smartTargetLat ?? zone.centerLat;
    final lng = zone.smartTargetLng ?? zone.centerLng;
    if (lat == null || lng == null || !mounted) return;
    await DriverNavigationLauncher.showChooser(
      context,
      lat: lat,
      lng: lng,
    );
  }

  void _openZoneInsights(ZoneDemand zone) {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final tierLabel = hotspotDemandLevelLine(zone);
    final avgFare = zone.avgOfferedFareEur;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                zone.zoneName ?? zone.zoneId,
                style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w800),
              ),
              if ((zone.smartTargetLabel ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${DriverStrings.hotspotsSmartTargetPrefix}${zone.smartTargetLabel}',
                    style: typo.bodySmall.copyWith(color: colors.textSoft),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                '${DriverStrings.hotspotsRidersWaitingCaption}: ${zone.waitingPassengers}',
                style: typo.bodyMedium.copyWith(color: colors.text),
              ),
              Text(DriverStrings.hotspotsDemandLabel(tierLabel), style: typo.bodyMedium.copyWith(color: colors.text)),
              Text(
                DriverStrings.hotspotsOnlineDrivers(zone.onlineDriversInZone),
                style: typo.bodyMedium.copyWith(color: colors.text),
              ),
              Text(
                DriverStrings.hotspotsRecentRides120m(zone.recentBookings120m),
                style: typo.bodyMedium.copyWith(color: colors.text),
              ),
              Text(
                avgFare != null && avgFare > 0
                    ? DriverStrings.hotspotsAvgOfferedFare(avgFare)
                    : DriverStrings.hotspotsAvgFareUnavailable,
                style: typo.bodyMedium.copyWith(color: colors.text),
              ),
              if ((zone.smartTargetReason ?? '').isNotEmpty)
                Text(
                  '${DriverStrings.hotspotsTargetLogicPrefix}${zone.smartTargetReason}',
                  style: typo.bodySmall.copyWith(color: colors.textSoft),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openNavigationChooser(zone);
                  },
                  child: Text(DriverStrings.hotspotsNavigateHere),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final tokenColors = ref.watch(colorsProvider);
    final mapViewTheme = HeyCabyAppChrome.themeIdOf(context);
    final best = _bestZone;

    ref.listen(zoneDemandProvider, (_, next) {
      next.whenData((z) {
        if (mounted) {
          setState(() => _zones = z);
          _drawHotspots(z, force: true);
        }
      });
    });

    Color? tierColor;
    if (best != null) {
      final tier = hotspotTierForDemand(best.waitingPassengers);
      tierColor = hotspotTierFill(tokenColors, tier);
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey('hotspots-map'),
              styleUri: mapboxStyleUriForTheme(mapViewTheme),
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(4.9041, 52.3676)),
                zoom: 10.8,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
            ),
          ),
          DriverDemandRadarOverlay(
            title: DriverStrings.hotspots,
            colors: colors,
            typography: typography,
            onBack: () => context.pop(),
            onRefresh: _refreshHotspots,
            onRecenter: _recenterMyLocation,
            bestZoneName: best?.zoneName ?? best?.zoneId,
            bestZoneWaitingLabel: best != null
                ? '${best.waitingPassengers} riders waiting'
                : null,
            bestZoneTierColor: tierColor,
            onBestZoneTap:
                best != null ? () => _openZoneInsights(best) : null,
          ),
        ],
      ),
    );
  }
}
