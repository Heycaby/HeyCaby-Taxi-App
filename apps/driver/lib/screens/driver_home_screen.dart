import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_location_provider.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_map_providers.dart';
import '../services/driver_data_service.dart' show ZoneDemand;
import '../widgets/driver_home_sheet.dart';
import '../widgets/driver_hub_sheet.dart';
import '../widgets/driver_map_floating.dart';
import '../widgets/feature_tour_modal.dart';
import '../widgets/founding_driver_welcome_dialog.dart';

const _zoneLabelsSourceId = 'zone-labels';
const _zoneLabelsLayerId = 'zone-labels-layer';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleManager;
  final _sheetController = DraggableScrollableController();
  Timer? _zonePollTimer;
  Timer? _pulseTimer;
  int _pulsePhase = 0;
  List<ZoneDemand> _lastZones = [];
  bool _lastShowZones = false;
  String? _lastCurrentZoneId;
  bool _congratsScheduled = false;
  bool _tourScheduled = false;
  bool _foundingWelcomeScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverLocationProvider.notifier).refresh();
      ref.invalidate(zoneDemandProvider);
      unawaited(_maybeShowFoundingDriverWelcome());
      _maybeShowFeatureTour();
      _maybeShowCongratulationsModal();
    });
  }

  Future<void> _maybeShowFoundingDriverWelcome() async {
    if (!mounted || _foundingWelcomeScheduled) return;
    final pending = ref.read(foundingDriverPostClaimProvider);
    if (pending == null || !pending.isFoundingDriver) return;
    _foundingWelcomeScheduled = true;
    await showFoundingDriverWelcomeDialog(context, ref, pending);
  }

  Future<void> _maybeShowFeatureTour() async {
    if (_tourScheduled) return;
    _tourScheduled = true;
    final profile = await ref.read(driverProfileProvider.future);
    if (!mounted) { _tourScheduled = false; return; }
    if (profile?.onboardingFeatureTourShown == true) { _tourScheduled = false; return; }

    final driverId = await ref.read(driverIdProvider.future);
    if (!mounted) { _tourScheduled = false; return; }

    await showFeatureTourModal(context);

    // Mark shown regardless of skip or completion
    if (driverId != null) {
      await ref.read(driverDataServiceProvider).markFeatureTourShown(driverId);
      ref.invalidate(driverProfileProvider);
    }
    _tourScheduled = false;
  }

  Future<void> _maybeShowCongratulationsModal() async {
    if (_congratsScheduled) return;
    _congratsScheduled = true;
    final profile = await ref.read(driverProfileProvider.future);
    if (!mounted) {
      _congratsScheduled = false;
      return;
    }
    if (profile?.profileStatus != 'verified') {
      _congratsScheduled = false;
      return;
    }
    if (profile?.congratulationsModalShown != false) {
      _congratsScheduled = false;
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colors = ref.read(colorsProvider);
        final typo = ref.read(typographyProvider);
        final name = ref.read(driverDisplayNameProvider);
        return AlertDialog(
          backgroundColor: colors.card,
          title: Text(
            DriverStrings.congratsTitleWithName(name),
            style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w800),
          ),
          content: Text(
            DriverStrings.congratsBody,
            style: typo.bodyMedium.copyWith(color: colors.textMid),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref.read(driverDataServiceProvider).dismissCongratulationsModal();
                ref.invalidate(driverProfileProvider);
              },
              child: Text(DriverStrings.congratsStart),
            ),
          ],
        );
      },
    );
    _congratsScheduled = false;
  }

  @override
  void dispose() {
    _zonePollTimer?.cancel();
    _pulseTimer?.cancel();
    super.dispose();
  }

  void _showDriverHub() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const Padding(
        padding: EdgeInsets.only(top: 48),
        child: DriverHubSheet(),
      ),
    );
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    _circleManager = await map.annotations.createCircleAnnotationManager();
    await Future.wait([
      map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
      map.compass.updateSettings(CompassSettings(enabled: false)),
      map.attribution.updateSettings(AttributionSettings(enabled: false)),
      map.logo.updateSettings(LogoSettings(enabled: false)),
    ]);
    await _mapboxMap!.setBounds(
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
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFFE6A800,
      pulsingMaxRadius: 40.0,
      showAccuracyRing: true,
      accuracyRingColor: 0x22E6A800,
    ));
    await _flyToUser();
    _zonePollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(zoneDemandProvider);
      ref.invalidate(currentZoneIdProvider);
    });
  }

  Future<void> _updateZoneCircles(
    List<ZoneDemand> zones,
    bool showZones, {
    String? currentZoneId,
  }) async {
    _lastZones = zones;
    _lastShowZones = showZones;
    _lastCurrentZoneId = currentZoneId;
    if (_circleManager == null || _mapboxMap == null) return;
    await _circleManager!.deleteAll();
    if (!showZones || zones.isEmpty) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
      await _updateZoneLabels(_mapboxMap!, []);
      return;
    }
    final hasHighDemand = zones.any((z) => z.waitingPassengers >= 20);
    if (hasHighDemand && _pulseTimer == null) {
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (!mounted) return;
        setState(() => _pulsePhase = (_pulsePhase + 1) % 2);
        _updateZoneCircles(_lastZones, _lastShowZones, currentZoneId: _lastCurrentZoneId);
      });
    } else if (!hasHighDemand) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
    }
    const gold = 0xFFE6A800;
    final options = <CircleAnnotationOptions>[];
    for (final z in zones) {
      if (z.centerLat == null || z.centerLng == null) continue;
      final n = z.waitingPassengers;
      final opacity = n >= 20 ? 0.7 : n >= 10 ? 0.55 : n >= 4 ? 0.3 : 0.12;
      var radiusPx = ((z.radiusM ?? 500) / 8).clamp(15.0, 80.0);
      if (n >= 20) {
        radiusPx *= _pulsePhase == 0 ? 1.0 : 1.08;
      }
      final isCurrentZone = currentZoneId != null && z.zoneId == currentZoneId;
      options.add(CircleAnnotationOptions(
        geometry: Point(coordinates: Position(z.centerLng!, z.centerLat!)),
        circleColor: (gold & 0xFFFFFF) | ((opacity * 255).round() << 24),
        circleRadius: radiusPx,
        circleStrokeColor: isCurrentZone ? gold : 0,
        circleStrokeWidth: isCurrentZone ? 3.0 : 0,
      ));
    }
    if (options.isNotEmpty) await _circleManager!.createMulti(options);
    await _updateZoneLabels(_mapboxMap!, showZones ? zones : []);
  }

  Future<void> _updateZoneLabels(MapboxMap map, List<ZoneDemand> zones) async {
    try {
      final features = <Map<String, dynamic>>[];
      for (final z in zones) {
        if (z.centerLat == null || z.centerLng == null || z.waitingPassengers < 4) continue;
        final label = z.waitingPassengers >= 10
            ? '${z.zoneName ?? z.zoneId}\n${z.waitingPassengers} waiting'
            : (z.zoneName ?? z.zoneId);
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [z.centerLng, z.centerLat],
          },
          'properties': {'label': label},
        });
      }
      final geoJson = jsonEncode({
        'type': 'FeatureCollection',
        'features': features,
      });
      final exists = await map.style.styleSourceExists(_zoneLabelsSourceId);
      if (exists) {
        await map.style.setStyleSourceProperty(_zoneLabelsSourceId, 'data', geoJson);
      } else if (features.isNotEmpty) {
        await map.style.addSource(GeoJsonSource(id: _zoneLabelsSourceId, data: geoJson));
        await map.style.addLayer(SymbolLayer(
          id: _zoneLabelsLayerId,
          sourceId: _zoneLabelsSourceId,
          textFieldExpression: ['get', 'label'],
          textSize: 11.0,
          textColor: 0xFF1A1A1A,
          textHaloColor: 0xFFFFFFFF,
          textHaloWidth: 1.5,
        ));
      }
    } catch (_) {}
  }

  Future<void> _flyToUser() async {
    final pos = ref.read(driverLocationProvider).valueOrNull;
    if (pos == null || _mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.42;
    final zones = ref.watch(zoneDemandProvider).valueOrNull ?? [];
    final mapView = ref.watch(mapViewProvider);
    final currentZoneId = ref.watch(currentZoneIdProvider).valueOrNull;
    final themeId = ref.watch(themeProvider).id;

    void updateZones() {
      _updateZoneCircles(
        zones,
        mapView == MapView.demandZones,
        currentZoneId: currentZoneId,
      );
    }

    ref.listen(zoneDemandProvider, (_, next) {
      next.whenData((z) => _updateZoneCircles(z, mapView == MapView.demandZones, currentZoneId: currentZoneId));
    });
    ref.listen(mapViewProvider, (_, next) {
      _updateZoneCircles(zones, next == MapView.demandZones, currentZoneId: currentZoneId);
    });
    ref.listen(currentZoneIdProvider, (_, __) => updateZones());
    ref.listen(driverProfileProvider, (prev, next) {
      next.whenData((profile) {
        if (profile?.profileStatus != 'verified') return;
        if (profile?.congratulationsModalShown != false) return;
        _congratsScheduled = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeShowCongratulationsModal();
        });
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (zones.isNotEmpty && mapView == MapView.demandZones) {
        updateZones();
      }
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MapWidget(
            key: ValueKey('driver-home-map-$themeId'),
            styleUri: mapboxStyleUriForTheme(themeId),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(4.9041, 52.3676)),
              zoom: 15.0,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),
          Positioned.fill(
            child: DriverMapFloating(
              sheetHeight: sheetHeight,
              onRecenter: _flyToUser,
              onGoOnline: () {},
              onDriverHub: _showDriverHub,
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.55,
            minChildSize: 0.25,
            maxChildSize: 0.80,
            snap: true,
            snapSizes: const [0.25, 0.55, 0.80],
            builder: (context, controller) => DriverHomeSheet(
              controller: controller,
              colors: colors,
              typo: typo,
            ),
          ),
        ],
      ),
    );
  }
}
