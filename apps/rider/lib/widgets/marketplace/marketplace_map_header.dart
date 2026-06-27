import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../providers/booking_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';
import '../../utils/map_style_helper.dart';

/// Default map center when GPS is unavailable (Rotterdam — HeyCaby home market).
const kMarketplaceDefaultLng = 4.4777;
const kMarketplaceDefaultLat = 51.9244;

/// Compact route preview map for the marketplace offer screen.
class MarketplaceMapHeader extends ConsumerStatefulWidget {
  const MarketplaceMapHeader({super.key, this.height = 220});

  final double height;

  @override
  ConsumerState<MarketplaceMapHeader> createState() =>
      _MarketplaceMapHeaderState();
}

class _MarketplaceMapHeaderState extends ConsumerState<MarketplaceMapHeader> {
  MapboxMap? _map;
  AddressResult? _userPlace;
  bool _locating = true;
  bool _hasValidNlLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserLocation());
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await Future.wait([
      map.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
      map.compass.updateSettings(CompassSettings(enabled: false)),
      map.attribution.updateSettings(AttributionSettings(enabled: false)),
      map.logo.updateSettings(LogoSettings(enabled: false)),
    ]);

    // Keep the map in the Netherlands — never show simulator fake cities abroad.
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
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    await _applyLocationPuck();
    await _fitCamera();
  }

  Future<void> _loadUserLocation() async {
    if (mounted) setState(() => _locating = true);

    var pos = ref.read(locationProvider).valueOrNull;
    if (pos == null ||
        !LocationService.isInNetherlands(pos.latitude, pos.longitude)) {
      pos = await LocationService.requestAndGetLocation();
      if (pos != null &&
          LocationService.isInNetherlands(pos.latitude, pos.longitude)) {
        ref.read(locationProvider.notifier).setPosition(pos);
      } else {
        pos = null;
      }
    }

    AddressResult? place;
    if (pos != null) {
      try {
        place = await ref.read(geocodingServiceProvider).reverseGeocode(
              lat: pos.latitude,
              lng: pos.longitude,
            );
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _userPlace = place;
      _hasValidNlLocation = pos != null;
      _locating = false;
    });

    await _applyLocationPuck();
    await _fitCamera(
      userLat: pos?.latitude,
      userLng: pos?.longitude,
    );
  }

  Future<void> _applyLocationPuck() async {
    final map = _map;
    if (map == null) return;
    await map.location.updateSettings(LocationComponentSettings(
      enabled: _hasValidNlLocation,
      pulsingEnabled: true,
      pulsingColor: 0xFF2E7D32,
      pulsingMaxRadius: 36.0,
      showAccuracyRing: true,
    ));
  }

  Future<void> _fitCamera({double? userLat, double? userLng}) async {
    final map = _map;
    if (map == null) return;
    final booking = ref.read(bookingProvider);
    final pickup = booking.pickup;
    final destination = booking.destination;

    if (pickup != null && destination != null) {
      await _fitRoute(pickup, destination);
      return;
    }

    if (userLat != null &&
        userLng != null &&
        LocationService.isInNetherlands(userLat, userLng)) {
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(userLng, userLat)),
          zoom: 15.5,
        ),
        MapAnimationOptions(duration: 500),
      );
      return;
    }

    final pos = ref.read(locationProvider).valueOrNull;
    if (pos != null &&
        LocationService.isInNetherlands(pos.latitude, pos.longitude)) {
      await map.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(pos.longitude, pos.latitude),
          ),
          zoom: 15.5,
        ),
        MapAnimationOptions(duration: 500),
      );
      return;
    }

    await map.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(kMarketplaceDefaultLng, kMarketplaceDefaultLat),
        ),
        zoom: 12.5,
      ),
    );
  }

  Future<void> _fitRoute(
    AddressResult pickup,
    AddressResult destination,
  ) async {
    final map = _map;
    if (map == null) return;

    final minLat = pickup.lat < destination.lat ? pickup.lat : destination.lat;
    final maxLat = pickup.lat > destination.lat ? pickup.lat : destination.lat;
    final minLng = pickup.lng < destination.lng ? pickup.lng : destination.lng;
    final maxLng = pickup.lng > destination.lng ? pickup.lng : destination.lng;
    final latPad = (maxLat - minLat) * 0.35;
    final lngPad = (maxLng - minLng) * 0.35;

    final camera = await map.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(
          coordinates: Position(minLng - lngPad, minLat - latPad),
        ),
        northeast: Point(
          coordinates: Position(maxLng + lngPad, maxLat + latPad),
        ),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 48, left: 24, bottom: 48, right: 24),
      null,
      null,
      null,
      null,
    );
    await map.setCamera(camera);

    final lineManager = await map.annotations.createPolylineAnnotationManager();
    await lineManager.deleteAll();
    await lineManager.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: [
            Position(pickup.lng, pickup.lat),
            Position(destination.lng, destination.lat),
          ],
        ),
        lineColor: 0xFF2E7D32,
        lineWidth: 4.0,
        lineOpacity: 0.85,
      ),
    );

    final pointManager = await map.annotations.createPointAnnotationManager();
    await pointManager.deleteAll();
    await pointManager.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(pickup.lng, pickup.lat)),
        iconColor: 0xFF43A047,
        iconSize: 1.2,
      ),
    );
    await pointManager.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(destination.lng, destination.lat),
        ),
        iconColor: 0xFFE53935,
        iconSize: 1.2,
      ),
    );
  }

  bool get _showYouAreHereCard {
    final booking = ref.read(bookingProvider);
    return booking.pickup == null && booking.destination == null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    ref.listen(bookingProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
    });

    ref.listen(locationProvider, (prev, next) {
      final pos = next.valueOrNull;
      if (pos == null ||
          !LocationService.isInNetherlands(pos.latitude, pos.longitude)) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() => _hasValidNlLocation = true);
        await _fitCamera(userLat: pos.latitude, userLng: pos.longitude);
      });
    });

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MapWidget(
            styleUri: mapStyleForTheme(ref.watch(themeProvider).id),
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(kMarketplaceDefaultLng, kMarketplaceDefaultLat),
              ),
              zoom: 12.5,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),
          if (_showYouAreHereCard)
            IgnorePointer(
              child: Align(
                alignment: const Alignment(0, 0.05),
                child: _YouAreHereCard(
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                  place: _userPlace,
                  locating: _locating,
                  hasValidLocation: _hasValidNlLocation,
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: colors.card.withValues(alpha: 0.94),
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _loadUserLocation,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.my_location, size: 18, color: colors.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YouAreHereCard extends StatelessWidget {
  const _YouAreHereCard({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.place,
    required this.locating,
    required this.hasValidLocation,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final AddressResult? place;
  final bool locating;
  final bool hasValidLocation;

  String _label() {
    if (locating) return l10n.marketplaceLocatingYou;
    if (!hasValidLocation) return l10n.marketplaceLocationNeeded;

    final area = place?.city?.trim();
    final street = place?.displayName.trim() ?? '';

    if (area != null && area.isNotEmpty) {
      return l10n.marketplaceYouAreHereIn(area);
    }
    if (street.isNotEmpty) {
      return l10n.marketplaceYouAreHereOn(street);
    }
    return l10n.marketplaceYouAreHere;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.accentL,
              shape: BoxShape.circle,
            ),
            child: locating
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accent,
                    ),
                  )
                : Icon(
                    hasValidLocation ? Icons.place_rounded : Icons.location_off,
                    color: colors.accent,
                    size: 16,
                  ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _label(),
              style: typo.labelLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
