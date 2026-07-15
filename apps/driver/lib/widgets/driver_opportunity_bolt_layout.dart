import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../utils/driver_ride_coord_utils.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import 'driver_ride_flow_common.dart';
import 'driver_ride_map_pins_overlay.dart';
import 'driver_ride_premium_style.dart';

/// Bolt-style incoming ride decision: map-first, fare hero, one Accept CTA.
class DriverOpportunityBoltLayout extends StatelessWidget {
  const DriverOpportunityBoltLayout({
    super.key,
    required this.colors,
    required this.typography,
    required this.offer,
    required this.countdownSeconds,
    required this.totalCountdownSeconds,
    required this.showCountdown,
    required this.isAccepting,
    required this.isDeclining,
    required this.onAccept,
    required this.onDecline,
    this.renderMap = true,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverOpportunityOfferData offer;
  final int countdownSeconds;
  final int totalCountdownSeconds;
  final bool showCountdown;
  final bool isAccepting;
  final bool isDeclining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool renderMap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _OpportunityMapLayer(
            colors: colors,
            offer: offer,
            renderMap: renderMap,
          ),
          Positioned(
            left: DriverSpacing.screenEdge,
            right: DriverSpacing.screenEdge,
            bottom: 0,
            child: _OpportunityDecisionSheet(
              colors: colors,
              typography: typography,
              offer: offer,
              countdownSeconds: countdownSeconds,
              totalCountdownSeconds: totalCountdownSeconds,
              showCountdown: showCountdown,
              isAccepting: isAccepting,
              isDeclining: isDeclining,
              onAccept: onAccept,
              onSkip: onDecline,
            ),
          ),
        ],
      ),
    );
  }
}

/// One map-anchored decision surface: information scrolls, actions stay fixed.
class _OpportunityDecisionSheet extends StatelessWidget {
  const _OpportunityDecisionSheet({
    required this.colors,
    required this.typography,
    required this.offer,
    required this.countdownSeconds,
    required this.totalCountdownSeconds,
    required this.showCountdown,
    required this.isAccepting,
    required this.isDeclining,
    required this.onAccept,
    required this.onSkip,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverOpportunityOfferData offer;
  final int countdownSeconds;
  final int totalCountdownSeconds;
  final bool showCountdown;
  final bool isAccepting;
  final bool isDeclining;
  final VoidCallback onAccept;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final maxContentHeight = MediaQuery.sizeOf(context).height * 0.48;
    return DriverRidePremiumStyle.glassSurface(
      colors: colors,
      borderRadius: DriverRadius.sheetTop,
      blurSigma: 28,
      tintOpacity: 0.9,
      borderColor: colors.primary.withValues(alpha: 0.28),
      boxShadow: DriverShadows.floating(colors),
      padding: EdgeInsets.fromLTRB(
        DriverSpacing.lg,
        DriverSpacing.sm,
        DriverSpacing.lg,
        DriverSpacing.md + safeBottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DriverRidePremiumStyle.sheetHandle(colors),
          const SizedBox(height: DriverSpacing.md),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxContentHeight),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _OpportunityDecisionCard(
                colors: colors,
                typography: typography,
                offer: offer,
                countdownSeconds: countdownSeconds,
                totalCountdownSeconds: totalCountdownSeconds,
                showCountdown: showCountdown,
                embedded: true,
              ),
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          Divider(height: 1, color: colors.border.withValues(alpha: 0.65)),
          const SizedBox(height: DriverSpacing.md),
          _OpportunityAcceptSkipDock(
            colors: colors,
            typography: typography,
            isAccepting: isAccepting,
            isDeclining: isDeclining,
            onAccept: onAccept,
            onSkip: onSkip,
            embedded: true,
          ),
        ],
      ),
    );
  }
}

class DriverOpportunityOfferData {
  const DriverOpportunityOfferData({
    required this.riderLabel,
    required this.pickupAddress,
    required this.destinationAddress,
    this.fareHero,
    this.fareSubline,
    this.ratingLabel,
    this.paymentLabel,
    this.pickupMeta,
    this.tripMeta,
    this.pickupDistanceLabel,
    this.pickupEtaLabel,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.driverLat,
    this.driverLng,
    this.productBadges = const [],
    this.contextBadges = const [],
  });

  final String riderLabel;
  final String pickupAddress;
  final String destinationAddress;
  final String? fareHero;
  final String? fareSubline;
  final String? ratingLabel;
  final String? paymentLabel;
  final String? pickupMeta;
  final String? tripMeta;
  final String? pickupDistanceLabel;
  final String? pickupEtaLabel;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? driverLat;
  final double? driverLng;
  final List<String> productBadges;
  final List<({String label, bool warning, bool highlight})> contextBadges;

  factory DriverOpportunityOfferData.from(Map<String, dynamic> data) {
    enrichDriverRideRequestCoords(data);

    final riderName = _firstText(data, const [
          'pickup_contact_name',
          'rider_name',
          'customer_name',
          'passenger_name',
        ]) ??
        DriverStrings.rider;
    final pickup = _firstText(data, const [
          'pickup_address',
          'origin_address',
          'from_address',
        ]) ??
        '—';
    final destination = _firstText(data, const [
          'destination_address',
          'dropoff_address',
          'to_address',
        ]) ??
        '—';

    final pickupMinutes = _firstNum(data, const [
      'pickup_eta_min',
      'pickup_eta_minutes',
      'estimated_pickup_minutes',
      'driver_pickup_minutes',
    ]);
    final pickupDistance = _firstNum(data, const [
      'pickup_distance_km',
      'distance_to_pickup_km',
      'driver_distance_km',
    ]);
    final pickupLat = (data['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (data['pickup_lng'] as num?)?.toDouble();
    final destLat = (data['destination_lat'] as num?)?.toDouble();
    final destLng = (data['destination_lng'] as num?)?.toDouble();

    var tripDistance = _firstNum(data, const [
      'estimated_distance_km',
      'distance_km',
      'trip_distance_km',
    ]);
    if ((tripDistance == null || tripDistance <= 0) &&
        pickupLat != null &&
        pickupLng != null &&
        destLat != null &&
        destLng != null) {
      tripDistance = _haversineKm(pickupLat, pickupLng, destLat, destLng);
      tripDistance = (tripDistance * 10).round() / 10.0;
    }
    final tripMinutes = _sanitizedTripMinutes(
      _firstNum(data, const [
        'estimated_duration_min',
        'duration_min',
        'estimated_trip_duration_min',
        'trip_duration_min',
      ]),
      tripDistance,
    );
    final rating = _firstNum(data, const [
      'rider_rating',
      'rider_score',
      'rider_average_rating',
    ]);
    final demand = _firstNum(data, const [
      'surge_multiplier',
      'demand_multiplier',
      'price_multiplier',
    ]);

    final fareHero = _resolveFareHero(data, tripDistance, tripMinutes);
    final fareSubline = _resolveFareSubline(data);

    final productBadges = <String>[];
    final bookingMode = (data['booking_mode'] as String?)?.toLowerCase();
    final taxiTerugQualified = data['taxi_terug_qualified'] == true;
    final taxiTerugNextRide = data['taxi_terug_next_ride'] == true;
    if (bookingMode == 'terug' && taxiTerugQualified) {
      productBadges.add(DriverStrings.incomingRideTerugTaxiBadge);
    } else if (bookingMode == 'marketplace') {
      productBadges.add(DriverStrings.incomingRideMarketplaceBadge);
    }

    final contextBadges = <({String label, bool warning, bool highlight})>[];
    if (demand != null && demand > 1.01) {
      contextBadges.add((
        label:
            '${demand.toStringAsFixed(1)}× ${DriverStrings.incomingRideDemand}',
        warning: false,
        highlight: true,
      ));
    }
    if (data['out_of_radius'] == true) {
      contextBadges.add((
        label: DriverStrings.incomingRideOutOfRadius,
        warning: true,
        highlight: false,
      ));
    }
    final returnLabel = data['taxi_terug_destination_label'] as String?;
    if (taxiTerugQualified && returnLabel != null && returnLabel.isNotEmpty) {
      contextBadges.add((
        label: DriverStrings.incomingRideReturnFit(returnLabel),
        warning: false,
        highlight: true,
      ));
    }
    if (taxiTerugNextRide) {
      contextBadges.add((
        label: DriverStrings.incomingRideTerugNextRide,
        warning: false,
        highlight: true,
      ));
    }

    return DriverOpportunityOfferData(
      riderLabel: riderName,
      pickupAddress: pickup,
      destinationAddress: destination,
      fareHero: fareHero,
      fareSubline: fareSubline,
      ratingLabel: rating != null ? '${rating.toStringAsFixed(1)} ★' : null,
      paymentLabel: _paymentLabelFromData(data),
      pickupMeta: _joinMeta([
        _minutesLabel(pickupMinutes),
        _distanceLabel(pickupDistance),
      ]),
      tripMeta: _joinMeta([
        _minutesLabel(tripMinutes),
        _distanceLabel(tripDistance),
      ]),
      pickupDistanceLabel: _distanceLabel(pickupDistance),
      pickupEtaLabel: _minutesLabel(pickupMinutes),
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      driverLat: (data['driver_lat'] as num?)?.toDouble(),
      driverLng: (data['driver_lng'] as num?)?.toDouble(),
      productBadges: productBadges,
      contextBadges: contextBadges,
    );
  }

  static String? _resolveFareHero(
    Map<String, dynamic> data,
    double? tripDistance,
    double? tripMinutes,
  ) {
    final offered = _firstNum(data, const [
      'offered_fare',
      'marketplace_offered_fare',
      'estimated_fare',
      'quoted_fare',
      'fare',
      'price',
      'tariff_estimate_fare',
    ]);
    if (offered != null && offered > 0) {
      return '€${offered.toStringAsFixed(2)}';
    }
    if (tripDistance != null && tripDistance > 0) {
      return DriverStrings.incomingRideFareFromDistance(
        tripDistance.toStringAsFixed(1),
      );
    }
    return DriverStrings.incomingRideEstimatedEarnings;
  }

  static String? _resolveFareSubline(Map<String, dynamic> data) {
    final feeCents = (data['service_fee_cents'] as num?)?.toInt();
    final netCents = (data['estimated_driver_net_cents'] as num?)?.toInt();
    if (feeCents != null && feeCents > 0 && netCents != null) {
      return DriverStrings.incomingRideNetAfterServiceFee(
        '€${(netCents / 100).toStringAsFixed(2)}',
        '€${(feeCents / 100).toStringAsFixed(2)}',
      );
    }
    final source = data['fare_source'] as String?;
    final marketplace = (data['marketplace_offered_fare'] as num?)?.toDouble();
    if (marketplace != null && marketplace > 0) {
      return DriverStrings.incomingRideRiderOffered(
        '€${marketplace.toStringAsFixed(2)}',
      );
    }
    if (source == 'tariff_estimate') {
      return DriverStrings.incomingRideTariffEstimate;
    }
    if (source == 'rider_offer') {
      return DriverStrings.incomingRideRiderNamedPrice;
    }
    return DriverStrings.incomingRideReviewTrip;
  }

  static String? _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static double? _firstNum(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static String? _minutesLabel(double? value) {
    if (value == null) return null;
    return HeyCabyFormatters.formatDuration(value.round());
  }

  static double? _sanitizedTripMinutes(double? minutes, double? distanceKm) {
    if (minutes == null) return null;
    if (distanceKm == null || distanceKm <= 0) return minutes;
    final estimated = HeyCabyFormatters.estimateDrivingMinutes(distanceKm);
    if (minutes > estimated * 1.35) return estimated.toDouble();
    return minutes;
  }

  static String? _distanceLabel(double? value) {
    if (value == null) return null;
    return '${value.toStringAsFixed(1)} km';
  }

  static String? _joinMeta(List<String?> parts) {
    final visible = parts.whereType<String>().toList(growable: false);
    if (visible.isEmpty) return null;
    return visible.join(' · ');
  }

  static String? _paymentLabelFromData(Map<String, dynamic> data) {
    for (final key in const [
      'payment_methods',
      'accepted_payment_methods',
      'preferred_payment_methods',
    ]) {
      final value = data[key];
      if (value is List && value.isNotEmpty) {
        return _paymentLabel(value.first.toString());
      }
    }
    return _paymentLabel(_firstText(data, const [
      'payment_method',
      'preferred_payment_method',
      'payment_type',
    ]));
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0;
    double rad(double deg) => deg * math.pi / 180.0;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String? _paymentLabel(String? raw) {
    if (raw == null) return null;
    final normalized = raw.toLowerCase().replaceAll('_', ' ');
    if (normalized.contains('cash') || normalized.contains('contant')) {
      return DriverStrings.paymentCash;
    }
    if (normalized.contains('card') || normalized.contains('pin')) {
      return DriverStrings.paymentCard;
    }
    if (normalized.contains('invoice') || normalized.contains('factuur')) {
      return DriverStrings.paymentInvoice;
    }
    if (normalized.contains('tikkie')) return 'Tikkie';
    return raw;
  }
}

class _OpportunityMapLayer extends StatefulWidget {
  const _OpportunityMapLayer({
    required this.colors,
    required this.offer,
    required this.renderMap,
  });

  final DriverColors colors;
  final DriverOpportunityOfferData offer;
  final bool renderMap;

  @override
  State<_OpportunityMapLayer> createState() => _OpportunityMapLayerState();
}

class _OpportunityMapLayerState extends State<_OpportunityMapLayer> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _lineManager;
  PointAnnotationManager? _pointManager;
  bool _initialized = false;
  int _cameraTick = 0;

  DriverOpportunityOfferData get offer => widget.offer;
  DriverColors get colors => widget.colors;

  void _onCameraChange(CameraChangedEventData _) {
    if (!mounted) return;
    setState(() => _cameraTick++);
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    if (mounted) setState(() {});
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
    await _fitAndDraw();
    if (mounted) setState(() => _cameraTick++);
  }

  @override
  void didUpdateWidget(_OpportunityMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized) return;
    if (oldWidget.offer.pickupLat != widget.offer.pickupLat ||
        oldWidget.offer.pickupLng != widget.offer.pickupLng ||
        oldWidget.offer.destLat != widget.offer.destLat ||
        oldWidget.offer.destLng != widget.offer.destLng) {
      _fitAndDraw();
    }
  }

  Future<void> _fitAndDraw() async {
    if (_mapboxMap == null) return;
    final pLat = offer.pickupLat;
    final pLng = offer.pickupLng;
    final dLat = offer.destLat;
    final dLng = offer.destLng;
    final hasPickup = driverMapCoordIsValid(pLat, pLng);
    final hasDest = driverMapCoordIsValid(dLat, dLng);
    if (!hasPickup && !hasDest) return;

    final boundsPoints = <List<double>>[];
    if (hasPickup) boundsPoints.add([pLng!, pLat!]);
    if (hasDest) boundsPoints.add([dLng!, dLat!]);

    final drvLat = offer.driverLat;
    final drvLng = offer.driverLng;
    final showDriverLeg = hasPickup &&
        drvLat != null &&
        drvLng != null &&
        driverMapIncludeDriverLeg(
          driverLat: drvLat,
          driverLng: drvLng,
          pickupLat: pLat!,
          pickupLng: pLng!,
        );
    if (showDriverLeg) {
      boundsPoints.insert(0, [drvLng, drvLat]);
    }

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
    final latPad = (maxLat - minLat) * 0.22 + 0.018;
    final lngPad = (maxLng - minLng) * 0.22 + 0.018;

    var camera = await _mapboxMap!.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest:
            Point(coordinates: Position(minLng - lngPad, minLat - latPad)),
        northeast:
            Point(coordinates: Position(maxLng + lngPad, maxLat + latPad)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 72, left: 24, bottom: 340, right: 24),
      null,
      null,
      null,
      null,
    );
    final zoom = camera.zoom;
    if (zoom != null && zoom < 8.5) {
      camera = CameraOptions(
        center: camera.center,
        zoom: 8.5,
        pitch: camera.pitch ?? 22,
        bearing: camera.bearing,
      );
    }
    await _mapboxMap!.setCamera(camera);

    final routing = RoutingService(
      accessToken: const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
    );
    final driverLeg = showDriverLeg
        ? await routing.fetchRoute(
            fromLat: drvLat,
            fromLng: drvLng,
            toLat: pLat,
            toLng: pLng,
          )
        : null;
    final tripLeg = hasPickup && hasDest
        ? await routing.fetchRoute(
            fromLat: pLat!,
            fromLng: pLng!,
            toLat: dLat!,
            toLng: dLng!,
          )
        : null;
    if (!mounted) return;

    if (_lineManager != null) {
      await _lineManager!.deleteAll();
      if (showDriverLeg && driverLeg != null) {
        await _lineManager!.create(PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: driverLeg.coordinates
                .map((point) => Position(point[0], point[1]))
                .toList(growable: false),
          ),
          lineColor: colors.textMuted.withValues(alpha: 0.45).toARGB32(),
          lineWidth: 2.5,
        ));
      }
      if (hasPickup && hasDest && tripLeg != null) {
        await _lineManager!.create(PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: tripLeg.coordinates
                .map((point) => Position(point[0], point[1]))
                .toList(growable: false),
          ),
          lineColor: colors.primary.toARGB32(),
          lineWidth: 4,
        ));
      }
    }

    if (_pointManager != null) {
      await _pointManager!.deleteAll();
      if (hasPickup) {
        await _pointManager!.create(PointAnnotationOptions(
          geometry: Point(coordinates: Position(pLng!, pLat!)),
          iconImage: 'marker-15',
          iconSize: 2.0,
          iconColor: colors.success.toARGB32(),
        ));
      }
      if (hasDest) {
        await _pointManager!.create(PointAnnotationOptions(
          geometry: Point(coordinates: Position(dLng!, dLat!)),
          iconImage: 'marker-15',
          iconSize: 2.0,
          iconColor: colors.error.toARGB32(),
        ));
      }
    }

    if (mounted) setState(() => _cameraTick++);
  }

  bool get _hasMapData {
    return driverMapCoordIsValid(offer.pickupLat, offer.pickupLng) ||
        driverMapCoordIsValid(offer.destLat, offer.destLng);
  }

  @override
  Widget build(BuildContext context) {
    final themeId = HeyCabyAppChrome.themeIdOf(context);
    final hasPickup = driverMapCoordIsValid(offer.pickupLat, offer.pickupLng);
    final hasDest = driverMapCoordIsValid(offer.destLat, offer.destLng);
    final hasMapData = _hasMapData;
    final fallbackCenter = hasDest
        ? Point(coordinates: Position(offer.destLng!, offer.destLat!))
        : hasPickup
            ? Point(coordinates: Position(offer.pickupLng!, offer.pickupLat!))
            : Point(coordinates: Position(4.9041, 52.3676));
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.renderMap)
            MapWidgetOrPlaceholder(
              key: ValueKey(
                'driver-opportunity-map-$themeId-'
                '${offer.pickupLat}-${offer.destLat}',
              ),
              styleUri: mapboxStyleUriForTheme(themeId),
              cameraOptions: hasMapData
                  ? null
                  : CameraOptions(
                      center: fallbackCenter,
                      zoom: 13.5,
                      pitch: 22,
                    ),
              onMapCreated: hasMapData ? _onMapCreated : null,
              onCameraChangeListener: hasMapData ? _onCameraChange : null,
            )
          else
            ColoredBox(color: colors.backgroundAlt),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.background.withValues(alpha: 0.08),
                  colors.background.withValues(alpha: 0.02),
                  colors.background.withValues(alpha: 0.55),
                  colors.background.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.35, 0.72, 1.0],
              ),
            ),
          ),
          if (widget.renderMap && hasMapData)
            DriverRideMapPinsOverlay(
              mapboxMap: _mapboxMap,
              pickupLat: offer.pickupLat,
              pickupLng: offer.pickupLng,
              destinationLat: offer.destLat,
              destinationLng: offer.destLng,
              driverLat: offer.driverLat,
              driverLng: offer.driverLng,
              pickupColor: colors.success,
              dropoffColor: colors.error,
              cameraTick: _cameraTick,
              pinSize: 44,
            ),
        ],
      ),
    );
  }
}

/// Accept + Skip pinned together — Accept is the dominant CTA.
class _OpportunityAcceptSkipDock extends StatelessWidget {
  const _OpportunityAcceptSkipDock({
    required this.colors,
    required this.typography,
    required this.isAccepting,
    required this.isDeclining,
    required this.onAccept,
    required this.onSkip,
    this.embedded = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool isAccepting;
  final bool isDeclining;
  final VoidCallback onAccept;
  final VoidCallback onSkip;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final busy = isAccepting || isDeclining;

    final actions = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: DriverRadius.smAll,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: DriverButton(
              label: DriverStrings.accept,
              icon: Icons.check_rounded,
              onPressed: busy ? null : onAccept,
              loading: isAccepting,
              variant: DriverButtonVariant.primary,
              size: DriverButtonSize.lg,
              colors: colors,
              typography: typography,
            ),
          ),
        ),
        const SizedBox(width: DriverSpacing.sm),
        Expanded(
          flex: 2,
          child: DriverButton(
            label: DriverStrings.skip,
            onPressed: busy ? null : onSkip,
            loading: isDeclining,
            variant: DriverButtonVariant.outline,
            size: DriverButtonSize.lg,
            colors: colors,
            typography: typography,
          ),
        ),
      ],
    );
    if (embedded) return actions;

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
          actions,
        ],
      ),
    );
  }
}

class _OpportunityDecisionCard extends StatelessWidget {
  const _OpportunityDecisionCard({
    required this.colors,
    required this.typography,
    required this.offer,
    required this.countdownSeconds,
    required this.totalCountdownSeconds,
    required this.showCountdown,
    this.embedded = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverOpportunityOfferData offer;
  final int countdownSeconds;
  final int totalCountdownSeconds;
  final bool showCountdown;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final progress = totalCountdownSeconds <= 0
        ? 0.0
        : (countdownSeconds / totalCountdownSeconds).clamp(0.0, 1.0);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCountdown) ...[
          Row(
            children: [
              Text(
                DriverStrings.opportunityIncomingBadge,
                style: typography.labelMedium.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.timer_rounded,
                size: 18,
                color: countdownSeconds <= 8 ? colors.warning : colors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '${countdownSeconds}s',
                style: typography.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: progress,
              backgroundColor: colors.backgroundAlt,
              valueColor: AlwaysStoppedAnimation<Color>(
                countdownSeconds <= 8 ? colors.warning : colors.primary,
              ),
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
        ],
        if (offer.productBadges.isNotEmpty || offer.contextBadges.isNotEmpty)
          Wrap(
            spacing: DriverSpacing.sm,
            runSpacing: DriverSpacing.sm,
            children: [
              for (final badge in offer.productBadges)
                _BadgeChip(
                  colors: colors,
                  typography: typography,
                  label: badge,
                  tone: _BadgeTone.product,
                ),
              for (final badge in offer.contextBadges)
                _BadgeChip(
                  colors: colors,
                  typography: typography,
                  label: badge.label,
                  tone: badge.warning
                      ? _BadgeTone.warning
                      : badge.highlight
                          ? _BadgeTone.highlight
                          : _BadgeTone.neutral,
                ),
              if (offer.paymentLabel != null)
                _BadgeChip(
                  colors: colors,
                  typography: typography,
                  label: offer.paymentLabel!,
                  tone: _BadgeTone.neutral,
                ),
            ],
          ),
        if (offer.productBadges.isNotEmpty || offer.contextBadges.isNotEmpty)
          const SizedBox(height: DriverSpacing.md),
        _OpportunityFareDeadheadHero(
          colors: colors,
          typography: typography,
          fareHero:
              offer.fareHero ?? DriverStrings.incomingRideEstimatedEarnings,
          fareSubline: offer.fareSubline,
          pickupDistanceLabel: offer.pickupDistanceLabel,
          pickupEtaLabel: offer.pickupEtaLabel,
        ),
        const SizedBox(height: DriverSpacing.md),
        _OpportunityPassengerHero(
          colors: colors,
          typography: typography,
          riderLabel: offer.riderLabel,
          ratingLabel: offer.ratingLabel,
        ),
        const SizedBox(height: DriverSpacing.lg),
        _OpportunityAddressHero(
          colors: colors,
          typography: typography,
          pickupAddress: offer.pickupAddress,
          destinationAddress: offer.destinationAddress,
        ),
        if (offer.tripMeta != null) ...[
          const SizedBox(height: DriverSpacing.md),
          _BoltLegRow(
            colors: colors,
            typography: typography,
            dotColor: colors.success,
            title: DriverStrings.incomingRideTripPaid,
            meta: offer.tripMeta!,
          ),
        ],
        const SizedBox(height: DriverSpacing.sm),
        Text(
          DriverStrings.incomingRideDeclineSafe,
          textAlign: TextAlign.center,
          style: typography.bodySmall.copyWith(
            color: colors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    if (embedded) return content;

    return DriverRidePremiumStyle.glassSurface(
      colors: colors,
      borderRadius: DriverRadius.lgAll,
      blurSigma: 24,
      tintOpacity: 0.88,
      borderColor: colors.primary.withValues(alpha: 0.35),
      boxShadow: DriverShadows.floating(colors),
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.lg,
        DriverSpacing.md,
        DriverSpacing.lg,
        DriverSpacing.lg,
      ),
      child: content,
    );
  }
}

enum _BadgeTone { product, highlight, warning, neutral }

/// Passenger identity — quick scan before addresses.
class _OpportunityPassengerHero extends StatelessWidget {
  const _OpportunityPassengerHero({
    required this.colors,
    required this.typography,
    required this.riderLabel,
    this.ratingLabel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String riderLabel;
  final String? ratingLabel;

  String get _initial {
    final trimmed = riderLabel.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            colors.primary.withValues(alpha: 0.14),
            colors.primaryLight.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
              border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _initial,
              style: typography.titleLarge.copyWith(
                fontWeight: FontWeight.w900,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DriverStrings.rider.toUpperCase(),
                  style: typography.labelSmall.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  riderLabel,
                  style: typography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (ratingLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.border.withValues(alpha: 0.6)),
              ),
              child: Text(
                ratingLabel!,
                style: typography.labelLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fare (left) + distance/ETA to pickup (right) — scannable in under 2 seconds.
class _OpportunityFareDeadheadHero extends StatelessWidget {
  const _OpportunityFareDeadheadHero({
    required this.colors,
    required this.typography,
    required this.fareHero,
    this.fareSubline,
    this.pickupDistanceLabel,
    this.pickupEtaLabel,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String fareHero;
  final String? fareSubline;
  final String? pickupDistanceLabel;
  final String? pickupEtaLabel;

  @override
  Widget build(BuildContext context) {
    final hasDeadhead = pickupDistanceLabel != null || pickupEtaLabel != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fareHero,
                style: typography.displaySmall.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1.02,
                ),
              ),
              if (fareSubline != null) ...[
                const SizedBox(height: 4),
                Text(
                  fareSubline!,
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasDeadhead) ...[
          const SizedBox(width: DriverSpacing.md),
          Container(
            constraints: const BoxConstraints(minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.primaryLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (pickupDistanceLabel != null)
                  Text(
                    pickupDistanceLabel!,
                    style: typography.titleLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                    textAlign: TextAlign.right,
                  ),
                if (pickupEtaLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    pickupEtaLabel!,
                    style: typography.labelLarge.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  DriverStrings.incomingRidePickupDeadhead,
                  style: typography.labelSmall.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Pickup + drop-off with route rail — primary scan target for drivers.
class _OpportunityAddressHero extends StatelessWidget {
  const _OpportunityAddressHero({
    required this.colors,
    required this.typography,
    required this.pickupAddress,
    required this.destinationAddress,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String pickupAddress;
  final String destinationAddress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: colors.backgroundAlt.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.65)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                _RouteDot(color: colors.primary, size: 12),
                Expanded(
                  child: Container(
                    width: 2.5,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: colors.border,
                  ),
                ),
                _RouteDot(color: colors.text, size: 12),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DriverStrings.incomingRidePickup.toUpperCase(),
                    style: typography.labelSmall.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pickupAddress,
                    style: typography.titleMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    DriverStrings.incomingRideDropoff.toUpperCase(),
                    style: typography.labelSmall.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destinationAddress,
                    style: typography.titleMedium.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.colors,
    required this.typography,
    required this.label,
    required this.tone,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color text;
    switch (tone) {
      case _BadgeTone.product:
        bg = colors.primaryLight;
        border = colors.primary.withValues(alpha: 0.35);
        text = colors.text;
      case _BadgeTone.highlight:
        bg = colors.success.withValues(alpha: 0.12);
        border = colors.success.withValues(alpha: 0.28);
        text = colors.text;
      case _BadgeTone.warning:
        bg = colors.warning.withValues(alpha: 0.14);
        border = colors.warning.withValues(alpha: 0.35);
        text = colors.text;
      case _BadgeTone.neutral:
        bg = colors.backgroundAlt;
        border = colors.border;
        text = colors.text;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: typography.labelMedium.copyWith(
          color: text,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BoltLegRow extends StatelessWidget {
  const _BoltLegRow({
    required this.colors,
    required this.typography,
    required this.dotColor,
    required this.title,
    required this.meta,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final Color dotColor;
  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.backgroundAlt.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: typography.labelLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.textSecondary,
              ),
            ),
          ),
          Text(
            meta,
            style: typography.titleMedium.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
