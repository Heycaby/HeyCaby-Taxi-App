import 'dart:async' show unawaited;
import 'dart:math' show max, min, pi, sin, cos, sqrt, atan2;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../../providers/booking_provider.dart';
import '../../providers/driver_tracking_provider.dart';
import '../../services/nearby_supply_service.dart';
import '../../utils/map_style_helper.dart';
import '../booking/trip_summary_map_pins.dart';

const _kNlMinLat = 50.75;
const _kNlMaxLat = 53.55;
const _kNlMinLng = 3.31;
const _kNlMaxLng = 7.23;

enum _ActiveRideMapPhase {
  enRoutePickup,
  atPickup,
  inTrip,
  completed,
}

_ActiveRideMapPhase _mapPhaseForStatus(String status) {
  switch (status) {
    case 'in_progress':
      return _ActiveRideMapPhase.inTrip;
    case 'completed':
      return _ActiveRideMapPhase.completed;
    case 'driver_arrived':
    case 'arrived':
      return _ActiveRideMapPhase.atPickup;
    default:
      return _ActiveRideMapPhase.enRoutePickup;
  }
}

bool activeRideCoordInNl(double lat, double lng) =>
    lat >= _kNlMinLat &&
    lat <= _kNlMaxLat &&
    lng >= _kNlMinLng &&
    lng <= _kNlMaxLng;

/// Map layer for active ride: route line, pickup/drop-off pins, driver marker.
class ActiveRideMapStack extends ConsumerStatefulWidget {
  const ActiveRideMapStack({
    super.key,
    required this.height,
    required this.cameraBottomPadding,
    required this.booking,
    required this.driverLocation,
    required this.status,
    this.etaMinutes,
  });

  final double height;
  final double cameraBottomPadding;
  final BookingState booking;
  final DriverLocation? driverLocation;
  final String status;
  final int? etaMinutes;

  @override
  ConsumerState<ActiveRideMapStack> createState() => _ActiveRideMapStackState();
}

class _ActiveRideMapStackState extends ConsumerState<ActiveRideMapStack>
    with SingleTickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _lineManager;
  bool _styleReady = false;
  int _cameraTick = 0;
  List<Position>? _liveLegGeometry;
  double? _liveLegAnchorLat;
  double? _liveLegAnchorLng;
  String? _liveLegKey;

  late final AnimationController _driverPulseController;

  @override
  void initState() {
    super.initState();
    _driverPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _driverPulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ActiveRideMapStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final driverMoved = oldWidget.driverLocation?.lat != widget.driverLocation?.lat ||
        oldWidget.driverLocation?.lng != widget.driverLocation?.lng;
    final statusChanged = oldWidget.status != widget.status;
    final bookingChanged = oldWidget.booking.pickup?.lat != widget.booking.pickup?.lat ||
        oldWidget.booking.pickup?.lng != widget.booking.pickup?.lng ||
        oldWidget.booking.destination?.lat != widget.booking.destination?.lat ||
        oldWidget.booking.destination?.lng != widget.booking.destination?.lng;
    if (!driverMoved && !statusChanged && !bookingChanged) return;

    if (statusChanged || bookingChanged) {
      _liveLegGeometry = null;
      _liveLegAnchorLat = null;
      _liveLegAnchorLng = null;
      _liveLegKey = null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (statusChanged || bookingChanged) {
        unawaited(_refreshRouteAndCamera(fullCamera: true));
      } else if (driverMoved) {
        unawaited(_onDriverMoved());
      }
    });
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    await Future.wait([
      map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
      map.compass.updateSettings(CompassSettings(enabled: false)),
      map.attribution.updateSettings(AttributionSettings(enabled: false)),
      map.logo.updateSettings(LogoSettings(enabled: false)),
      map.location.updateSettings(LocationComponentSettings(enabled: false)),
    ]);
    await map.setBounds(
      CameraBoundsOptions(
        bounds: CoordinateBounds(
          southwest: Point(coordinates: Position(_kNlMinLng, _kNlMinLat)),
          northeast: Point(coordinates: Position(_kNlMaxLng, _kNlMaxLat)),
          infiniteBounds: false,
        ),
        minZoom: 7.5,
        maxZoom: 18.0,
      ),
    );
    await _refreshRouteAndCamera();
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    _styleReady = true;
    _lineManager = null;
    await _refreshRouteAndCamera();
  }

  void _onCameraChange(CameraChangedEventData _) {
    if (mounted) setState(() => _cameraTick++);
  }

  Future<void> _ensureLineManager() async {
    final map = _mapboxMap;
    if (map == null) return;
    _lineManager ??= await map.annotations.createPolylineAnnotationManager();
  }

  Future<void> _refreshRouteAndCamera({bool fullCamera = true}) async {
    if (!_styleReady || _mapboxMap == null) return;
    final pickup = widget.booking.pickup;
    if (pickup == null) return;

    await _ensureLineManager();
    await _drawRouteLines();
    if (fullCamera) {
      await _fitCamera();
    }
    if (mounted) setState(() => _cameraTick++);
  }

  Future<void> _onDriverMoved() async {
    if (!_styleReady || _mapboxMap == null) return;
    await _ensureLineManager();
    await _drawRouteLines();
    final driver = widget.driverLocation;
    if (driver == null) return;
    final phase = _mapPhaseForStatus(widget.status);
    if (phase == _ActiveRideMapPhase.inTrip ||
        phase == _ActiveRideMapPhase.enRoutePickup) {
      await _followDriver(driver);
    } else if (phase == _ActiveRideMapPhase.completed ||
        phase == _ActiveRideMapPhase.atPickup) {
      await _fitCamera();
    }
    if (mounted) setState(() => _cameraTick++);
  }

  Future<void> _followDriver(DriverLocation driver) async {
    final map = _mapboxMap;
    if (map == null || !activeRideCoordInNl(driver.lat, driver.lng)) return;
    await map.easeTo(
      CameraOptions(
        center: Point(coordinates: Position(driver.lng, driver.lat)),
        zoom: 14.2,
        padding: MbxEdgeInsets(
          top: 120,
          left: 48,
          bottom: widget.cameraBottomPadding,
          right: 48,
        ),
      ),
      MapAnimationOptions(duration: 650),
    );
  }

  Future<void> _drawRouteLines() async {
    final manager = _lineManager;
    if (manager == null) return;

    final pickup = widget.booking.pickup;
    final destination = widget.booking.destination;
    final driver = widget.driverLocation;
    if (pickup == null) return;

    await manager.deleteAll();
    final colors = ref.read(colorsProvider);
    final phase = _mapPhaseForStatus(widget.status);

    if (phase == _ActiveRideMapPhase.completed ||
        phase == _ActiveRideMapPhase.atPickup) {
      return;
    }

    if (phase == _ActiveRideMapPhase.inTrip &&
        driver != null &&
        destination != null &&
        activeRideCoordInNl(driver.lat, driver.lng) &&
        activeRideCoordInNl(destination.lat, destination.lng)) {
      final geometry = await _liveLegGeometryFor(
        fromLat: driver.lat,
        fromLng: driver.lng,
        toLat: destination.lat,
        toLng: destination.lng,
        legKey: 'trip:${destination.lat},${destination.lng}',
      );
      if (geometry.length >= 2) {
        await manager.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: geometry),
            lineColor: colors.success.toARGB32(),
            lineWidth: 5.5,
            lineOpacity: 0.92,
          ),
        );
      }
      return;
    }

    if (phase == _ActiveRideMapPhase.enRoutePickup &&
        driver != null &&
        activeRideCoordInNl(driver.lat, driver.lng)) {
      final geometry = await _liveLegGeometryFor(
        fromLat: driver.lat,
        fromLng: driver.lng,
        toLat: pickup.lat,
        toLng: pickup.lng,
        legKey: 'pickup:${pickup.lat},${pickup.lng}',
      );
      if (geometry.length >= 2) {
        await manager.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: geometry),
            lineColor: colors.warning.toARGB32(),
            lineWidth: 4.5,
            lineOpacity: 0.85,
          ),
        );
      }
    }
  }

  Future<List<Position>> _liveLegGeometryFor({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required String legKey,
  }) async {
    final movedKm = _liveLegAnchorLat == null
        ? double.infinity
        : _haversineKm(_liveLegAnchorLat!, _liveLegAnchorLng!, fromLat, fromLng);
    if (_liveLegGeometry != null &&
        _liveLegKey == legKey &&
        movedKm < 0.2) {
      return _liveLegGeometry!;
    }

    final routingService = RoutingService(
      accessToken: const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
    );
    final route = await routingService.fetchRoute(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
    );

    final geometry = route != null && route.coordinates.length >= 2
        ? route.coordinates.map((c) => Position(c[0], c[1])).toList()
        : <Position>[
            Position(fromLng, fromLat),
            Position(toLng, toLat),
          ];

    _liveLegGeometry = geometry;
    _liveLegAnchorLat = fromLat;
    _liveLegAnchorLng = fromLng;
    _liveLegKey = legKey;

    return geometry;
  }

  Future<void> _fitCamera() async {
    final map = _mapboxMap;
    final pickup = widget.booking.pickup;
    final destination = widget.booking.destination;
    if (map == null || pickup == null) return;

    final driver = widget.driverLocation;
    final phase = _mapPhaseForStatus(widget.status);
    final coords = <({double lat, double lng})>[];

    if (phase == _ActiveRideMapPhase.completed ||
        phase == _ActiveRideMapPhase.atPickup) {
      if (driver != null && activeRideCoordInNl(driver.lat, driver.lng)) {
        coords.add((lat: driver.lat, lng: driver.lng));
      }
      if (destination != null &&
          activeRideCoordInNl(destination.lat, destination.lng)) {
        coords.add((lat: destination.lat, lng: destination.lng));
      } else if (phase == _ActiveRideMapPhase.atPickup) {
        coords.add((lat: pickup.lat, lng: pickup.lng));
      }
    } else if (phase == _ActiveRideMapPhase.inTrip) {
      if (driver != null && activeRideCoordInNl(driver.lat, driver.lng)) {
        coords.add((lat: driver.lat, lng: driver.lng));
      }
      if (destination != null &&
          activeRideCoordInNl(destination.lat, destination.lng)) {
        coords.add((lat: destination.lat, lng: destination.lng));
      }
    } else {
      if (driver != null && activeRideCoordInNl(driver.lat, driver.lng)) {
        coords.add((lat: driver.lat, lng: driver.lng));
      }
      coords.add((lat: pickup.lat, lng: pickup.lng));
    }

    if (coords.length == 1) {
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pickup.lng, pickup.lat)),
          zoom: 14.8,
          padding: MbxEdgeInsets(
            top: 120,
            left: 64,
            bottom: widget.cameraBottomPadding,
            right: 64,
          ),
        ),
        MapAnimationOptions(duration: 450),
      );
      return;
    }

    var minLat = coords.first.lat;
    var maxLat = coords.first.lat;
    var minLng = coords.first.lng;
    var maxLng = coords.first.lng;
    for (final c in coords) {
      minLat = min(minLat, c.lat);
      maxLat = max(maxLat, c.lat);
      minLng = min(minLng, c.lng);
      maxLng = max(maxLng, c.lng);
    }

    final latSpan = max(maxLat - minLat, 0.008);
    final lngSpan = max(maxLng - minLng, 0.008);
    final phaseSpanKm = switch (phase) {
      _ActiveRideMapPhase.completed || _ActiveRideMapPhase.atPickup => 2.0,
      _ActiveRideMapPhase.inTrip => destination != null && driver != null
          ? _haversineKm(
              driver.lat,
              driver.lng,
              destination.lat,
              destination.lng,
            )
          : 8.0,
      _ActiveRideMapPhase.enRoutePickup => driver != null
          ? _haversineKm(driver.lat, driver.lng, pickup.lat, pickup.lng)
          : 5.0,
    };

    final westPad = max(lngSpan * 0.18, 0.014);
    final eastPad = max(lngSpan * 0.18, 0.014);
    final northPad = max(latSpan * 0.24, 0.018);
    final southPad = max(latSpan * 0.30, 0.022);

    final camera = await map.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(
          coordinates: Position(minLng - westPad, minLat - southPad),
        ),
        northeast: Point(
          coordinates: Position(maxLng + eastPad, maxLat + northPad),
        ),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(
        top: 120,
        left: 64,
        bottom: widget.cameraBottomPadding,
        right: 64,
      ),
      null,
      null,
      null,
      null,
    );

    final boundsZoom = camera.zoom ?? _minZoomForTripKm(phaseSpanKm);
    final zoomCap = phase == _ActiveRideMapPhase.completed ||
            phase == _ActiveRideMapPhase.atPickup
        ? 16.0
        : 15.5;
    final zoom = (boundsZoom - 0.35).clamp(7.5, zoomCap);

    await map.flyTo(
      CameraOptions(
        center: camera.center,
        zoom: zoom,
        bearing: camera.bearing,
        pitch: camera.pitch,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  double _minZoomForTripKm(double km) {
    if (km < 2) return 14.4;
    if (km < 8) return 13.2;
    if (km < 25) return 11.8;
    if (km < 60) return 10.8;
    if (km < 120) return 9.8;
    return 9.0;
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return (earthRadius * c * 10).round() / 10;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  CameraOptions _initialCamera() {
    final pickup = widget.booking.pickup;
    final destination = widget.booking.destination;
    if (pickup != null &&
        destination != null &&
        activeRideCoordInNl(pickup.lat, pickup.lng) &&
        activeRideCoordInNl(destination.lat, destination.lng)) {
      return CameraOptions(
        center: Point(
          coordinates: Position(
            (pickup.lng + destination.lng) / 2,
            (pickup.lat + destination.lat) / 2,
          ),
        ),
        zoom: _minZoomForTripKm(
          _haversineKm(pickup.lat, pickup.lng, destination.lat, destination.lng),
        ),
      );
    }
    if (pickup != null && activeRideCoordInNl(pickup.lat, pickup.lng)) {
      return CameraOptions(
        center: Point(coordinates: Position(pickup.lng, pickup.lat)),
        zoom: 14.5,
      );
    }
    return CameraOptions(
      center: Point(coordinates: Position(4.4777, 51.9244)),
      zoom: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final pickup = widget.booking.pickup;
    final destination = widget.booking.destination;
    final driver = widget.driverLocation;
    final phase = _mapPhaseForStatus(widget.status);
    final topPad = MediaQuery.paddingOf(context).top;

    final showPickupPin = phase == _ActiveRideMapPhase.enRoutePickup ||
        phase == _ActiveRideMapPhase.atPickup;
    final showDestinationPin = phase == _ActiveRideMapPhase.inTrip ||
        phase == _ActiveRideMapPhase.completed;

    double? chipDistanceKm;
    int? chipDurationMin;
    String? chipHeadline;
    if (phase == _ActiveRideMapPhase.completed ||
        phase == _ActiveRideMapPhase.atPickup) {
      chipHeadline = l10n.tripComplete;
    } else if (driver != null) {
      if (phase == _ActiveRideMapPhase.inTrip && destination != null) {
        chipDistanceKm = NearbySupplyService.distanceKm(
          driver.lat,
          driver.lng,
          destination.lat,
          destination.lng,
        );
        chipDurationMin = widget.etaMinutes ??
            ((chipDistanceKm / 28.0) * 60.0).ceil().clamp(1, 90);
      } else if (phase == _ActiveRideMapPhase.enRoutePickup && pickup != null) {
        chipDistanceKm = NearbySupplyService.distanceKm(
          driver.lat,
          driver.lng,
          pickup.lat,
          pickup.lng,
        );
        chipDurationMin = widget.etaMinutes ??
            ((chipDistanceKm / 28.0) * 60.0).ceil().clamp(1, 90);
      }
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MapWidget(
            styleUri: mapStyleForTheme(ref.watch(themeProvider).id),
            cameraOptions: _initialCamera(),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onCameraChangeListener: _onCameraChange,
          ),
          TripSummaryMapPinsOverlay(
            mapboxMap: _mapboxMap,
            pickupLat: showPickupPin ? pickup?.lat : null,
            pickupLng: showPickupPin ? pickup?.lng : null,
            destinationLat: showDestinationPin ? destination?.lat : null,
            destinationLng: showDestinationPin ? destination?.lng : null,
            pickupColor: colors.warning,
            dropoffColor: colors.success,
            cameraTick: _cameraTick,
            pinSize: 52,
          ),
          ActiveRideDriverMapMarker(
            mapboxMap: _mapboxMap,
            lat: driver?.lat,
            lng: driver?.lng,
            heading: driver?.heading,
            color: colors.text,
            pulse: _driverPulseController,
            cameraTick: _cameraTick,
          ),
          if (chipHeadline != null || (chipDistanceKm != null && chipDurationMin != null))
            Positioned(
              top: topPad + 10,
              left: 16,
              right: 16,
              child: Center(
                child: _ActiveRideMapMetricsChip(
                  colors: colors,
                  typo: typo,
                  distanceKm: chipDistanceKm,
                  durationMin: chipDurationMin,
                  headline: chipHeadline,
                  etaLabel: chipHeadline == null
                      ? _etaLabel(
                          l10n,
                          phase == _ActiveRideMapPhase.inTrip,
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _etaLabel(AppLocalizations l10n, bool inTrip) {
    final eta = widget.etaMinutes;
    if (eta == null) return null;
    return inTrip
        ? l10n.activeRideArrivingIn(eta.toString())
        : l10n.activeRidePickupIn(eta.toString());
  }
}

class _ActiveRideMapMetricsChip extends StatelessWidget {
  const _ActiveRideMapMetricsChip({
    required this.colors,
    required this.typo,
    this.distanceKm,
    this.durationMin,
    this.headline,
    this.etaLabel,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final double? distanceKm;
  final int? durationMin;
  final String? headline;
  final String? etaLabel;

  @override
  Widget build(BuildContext context) {
    final tripLabel = headline ??
        (distanceKm != null && durationMin != null
            ? '${distanceKm!.toStringAsFixed(1)} km · $durationMin min'
            : null);
    if (tripLabel == null) return const SizedBox.shrink();

    return Material(
      color: colors.card.withValues(alpha: 0.96),
      elevation: 6,
      shadowColor: colors.text.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tripLabel,
              style: typo.labelLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (etaLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                etaLabel!,
                style: typo.labelSmall.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated driver car marker projected on the map.
class ActiveRideDriverMapMarker extends StatefulWidget {
  const ActiveRideDriverMapMarker({
    super.key,
    required this.mapboxMap,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.color,
    required this.pulse,
    required this.cameraTick,
  });

  final MapboxMap? mapboxMap;
  final double? lat;
  final double? lng;
  final double? heading;
  final Color color;
  final Animation<double> pulse;
  final int cameraTick;

  @override
  State<ActiveRideDriverMapMarker> createState() =>
      _ActiveRideDriverMapMarkerState();
}

class _ActiveRideDriverMapMarkerState extends State<ActiveRideDriverMapMarker> {
  Offset? _position;

  @override
  void didUpdateWidget(covariant ActiveRideDriverMapMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraTick != widget.cameraTick ||
        oldWidget.lat != widget.lat ||
        oldWidget.lng != widget.lng) {
      _refresh();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final map = widget.mapboxMap;
    final lat = widget.lat;
    final lng = widget.lng;
    if (map == null || lat == null || lng == null) return;
    if (!activeRideCoordInNl(lat, lng)) return;
    try {
      final px = await map.pixelForCoordinate(
        Point(coordinates: Position(lng, lat)),
      );
      if (!mounted) return;
      setState(() => _position = Offset(px.x, px.y));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pos = _position;
    if (pos == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: pos.dx - 22,
            top: pos.dy - 22,
            child: AnimatedBuilder(
              animation: widget.pulse,
              builder: (context, child) {
                final scale = 1.0 + widget.pulse.value * 0.08;
                return Transform.rotate(
                  angle: (widget.heading ?? 0) * pi / 180,
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_taxi_rounded,
                  color: widget.color,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
