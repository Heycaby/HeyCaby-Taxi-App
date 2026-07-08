import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_ride_flow_common.dart';
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _OpportunityMapLayer(
            colors: colors,
            offer: offer,
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  top: DriverSpacing.sm,
                  end: DriverSpacing.screenEdge,
                ),
                child: _DeclineMapButton(
                  colors: colors,
                  typography: typography,
                  loading: isDeclining,
                  onTap: isAccepting ? null : onDecline,
                ),
              ),
            ),
          ),
          if (offer.tripMeta != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 56,
              left: DriverSpacing.screenEdge,
              child: _MapTripChip(
                colors: colors,
                typography: typography,
                label: offer.tripMeta!,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DriverSpacing.screenEdge,
                  ),
                  child: _OpportunityDecisionCard(
                    colors: colors,
                    typography: typography,
                    offer: offer,
                    countdownSeconds: countdownSeconds,
                    totalCountdownSeconds: totalCountdownSeconds,
                    showCountdown: showCountdown,
                  ),
                ),
                const SizedBox(height: DriverSpacing.sm),
                DriverRideFlowBottomBar(
                  colors: colors,
                  typography: typography,
                  primaryLabel: DriverStrings.accept,
                  primaryIcon: Icons.check_rounded,
                  onPrimary: isAccepting ? null : onAccept,
                  primaryLoading: isAccepting,
                ),
                SizedBox(height: bottomInset > 0 ? 0 : DriverSpacing.xs),
              ],
            ),
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
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? driverLat;
  final double? driverLng;
  final List<String> productBadges;
  final List<({String label, bool warning, bool highlight})> contextBadges;

  factory DriverOpportunityOfferData.from(Map<String, dynamic> data) {
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
    if (bookingMode == 'terug' || data['return_mode_active'] == true) {
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
    final returnLabel = data['return_destination_label'] as String?;
    if (data['return_mode_active'] == true &&
        returnLabel != null &&
        returnLabel.isNotEmpty) {
      contextBadges.add((
        label: DriverStrings.incomingRideReturnFit(returnLabel),
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
  });

  final DriverColors colors;
  final DriverOpportunityOfferData offer;

  @override
  State<_OpportunityMapLayer> createState() => _OpportunityMapLayerState();
}

class _OpportunityMapLayerState extends State<_OpportunityMapLayer> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _lineManager;
  PointAnnotationManager? _pointManager;
  bool _initialized = false;

  DriverOpportunityOfferData get offer => widget.offer;
  DriverColors get colors => widget.colors;

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
  void didUpdateWidget(_OpportunityMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_initialized) _fitAndDraw();
  }

  Future<void> _fitAndDraw() async {
    if (_mapboxMap == null) return;
    final pLat = offer.pickupLat;
    final pLng = offer.pickupLng;
    final dLat = offer.destLat;
    final dLng = offer.destLng;
    if (!driverMapCoordIsValid(pLat, pLng)) return;

    final boundsPoints = <List<double>>[
      [pLng!, pLat!],
    ];
    if (driverMapCoordIsValid(dLat, dLng)) {
      boundsPoints.add([dLng!, dLat!]);
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
    final latPad = (maxLat - minLat) * 0.3 + 0.012;
    final lngPad = (maxLng - minLng) * 0.3 + 0.012;

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
    if (zoom != null && zoom < 9.5) {
      camera = CameraOptions(
        center: camera.center,
        zoom: 9.5,
        pitch: camera.pitch ?? 22,
        bearing: camera.bearing,
      );
    }
    await _mapboxMap!.setCamera(camera);

    final drvLat = offer.driverLat;
    final drvLng = offer.driverLng;
    final showDriverLeg = drvLat != null &&
        drvLng != null &&
        driverMapIncludeDriverLeg(
          driverLat: drvLat,
          driverLng: drvLng,
          pickupLat: pLat,
          pickupLng: pLng,
        );

    if (_lineManager != null) {
      await _lineManager!.deleteAll();
      if (showDriverLeg) {
        await _lineManager!.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: [
            Position(drvLng, drvLat),
            Position(pLng, pLat),
          ]),
          lineColor: colors.textMuted.withValues(alpha: 0.45).toARGB32(),
          lineWidth: 2.5,
        ));
      }
      if (driverMapCoordIsValid(dLat, dLng)) {
        await _lineManager!.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: [
            Position(pLng, pLat),
            Position(dLng!, dLat!),
          ]),
          lineColor: colors.primary.toARGB32(),
          lineWidth: 4,
        ));
      }
    }

    if (_pointManager != null) {
      await _pointManager!.deleteAll();
      if (showDriverLeg) {
        await _pointManager!.create(PointAnnotationOptions(
          geometry: Point(coordinates: Position(drvLng, drvLat)),
          iconColor: colors.textSecondary.toARGB32(),
          iconSize: 1.35,
        ));
      }
      await _pointManager!.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(pLng, pLat)),
        iconColor: colors.primary.toARGB32(),
        iconSize: 1.45,
      ));
      if (driverMapCoordIsValid(dLat, dLng)) {
        await _pointManager!.create(PointAnnotationOptions(
          geometry: Point(coordinates: Position(dLng!, dLat!)),
          iconColor: colors.error.toARGB32(),
          iconSize: 1.45,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeId = HeyCabyAppChrome.themeIdOf(context);
    final hasPickup = driverMapCoordIsValid(offer.pickupLat, offer.pickupLng);
    final fallbackCenter = hasPickup
        ? Point(
            coordinates: Position(offer.pickupLng!, offer.pickupLat!),
          )
        : Point(coordinates: Position(4.9041, 52.3676));
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          MapWidget(
            key: ValueKey('driver-opportunity-map-$themeId'),
            styleUri: mapboxStyleUriForTheme(themeId),
            cameraOptions: hasPickup
                ? null
                : CameraOptions(
                    center: fallbackCenter,
                    zoom: 13.5,
                    pitch: 22,
                  ),
            onMapCreated: hasPickup ? _onMapCreated : null,
          ),
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
        ],
      ),
    );
  }
}

class _DeclineMapButton extends StatelessWidget {
  const _DeclineMapButton({
    required this.colors,
    required this.typography,
    required this.loading,
    required this.onTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card.withValues(alpha: 0.92),
      elevation: 4,
      shadowColor: colors.text.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 16, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textSecondary,
                  ),
                )
              else
                Icon(Icons.close_rounded, size: 20, color: colors.text),
              const SizedBox(width: 6),
              Text(
                DriverStrings.incomingRideMapDecline,
                style: typography.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapTripChip extends StatelessWidget {
  const _MapTripChip({
    required this.colors,
    required this.typography,
    required this.label,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        boxShadow: DriverShadows.subtle(colors),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: typography.labelLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
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
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverOpportunityOfferData offer;
  final int countdownSeconds;
  final int totalCountdownSeconds;
  final bool showCountdown;

  @override
  Widget build(BuildContext context) {
    final progress = totalCountdownSeconds <= 0
        ? 0.0
        : (countdownSeconds / totalCountdownSeconds).clamp(0.0, 1.0);

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
      child: Column(
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
                  color:
                      countdownSeconds <= 8 ? colors.warning : colors.primary,
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
          Text(
            offer.fareHero ?? DriverStrings.incomingRideEstimatedEarnings,
            style: typography.displaySmall.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.05,
            ),
          ),
          if (offer.fareSubline != null) ...[
            const SizedBox(height: 4),
            Text(
              offer.fareSubline!,
              style: typography.bodyMedium.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: DriverSpacing.md),
          _BoltLegRow(
            colors: colors,
            typography: typography,
            dotColor: colors.primary,
            title: DriverStrings.incomingRidePickupDeadhead,
            meta: offer.pickupMeta ?? '—',
          ),
          const SizedBox(height: DriverSpacing.sm),
          _BoltLegRow(
            colors: colors,
            typography: typography,
            dotColor: colors.success,
            title: DriverStrings.incomingRideTripPaid,
            meta: offer.tripMeta ?? '—',
          ),
          const SizedBox(height: DriverSpacing.md),
          Row(
            children: [
              Text(
                offer.riderLabel,
                style: typography.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (offer.ratingLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  offer.ratingLabel!,
                  style: typography.labelLarge.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            offer.pickupAddress,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            offer.destinationAddress,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
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
      ),
    );
  }
}

enum _BadgeTone { product, highlight, warning, neutral }

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
