import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_location_provider.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_map_providers.dart';
import '../services/driver_data_service.dart' show ZoneDemand;
import 'driver_hotspots_models.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../ui/driver_map_fab.dart';
import '../utils/driver_account_deletion.dart';
import '../utils/driver_logout.dart';
import '../widgets/driver_home_sheet.dart';
import '../widgets/driver_hub_sheet.dart';
import '../widgets/driver_map_floating.dart';

const _zoneLabelsSourceId = 'zone-labels';
const _zoneLabelsLayerId = 'zone-labels-layer';
const _homeSheetInitialFraction = 0.38;

int _mapboxColor(HeyCabyColorTokens colors) {
  final c = colors.accent;
  return (((c.a * 255.0).round() & 0xff) << 24) |
      (((c.r * 255.0).round() & 0xff) << 16) |
      (((c.g * 255.0).round() & 0xff) << 8) |
      ((c.b * 255.0).round() & 0xff);
}

/// **Money Dashboard** — map hero, online state, earnings, and today's progress at a glance.
///
/// See [`SCREEN_OWNERSHIP.md`](../../docs/SCREEN_OWNERSHIP.md).
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  MapView mapView = MapView.demandZones;
  final List<Zone> zones = [];
  bool _legalSectionExpanded = false;
  final _sheetController = DraggableScrollableController();
  Timer? _zonePollTimer;
  Timer? _pulseTimer;
  int _pulsePhase = 0;
  List<ZoneDemand> _lastZones = [];
  bool _lastShowZones = false;
  String? _lastCurrentZoneId;
  bool _congratsScheduled = false;
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverLocationProvider.notifier).refresh();
      ref.invalidate(zoneDemandProvider);
      _maybeShowCongratulationsModal();
    });
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
          title: Text(
            DriverStrings.congratsTitleWithName(name),
            style: typo.titleMedium
                .copyWith(color: colors.text, fontWeight: FontWeight.w800),
          ),
          content: Text(
            DriverStrings.congratsBody,
            style: typo.bodyMedium.copyWith(color: colors.textMid),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref
                    .read(driverDataServiceProvider)
                    .dismissCongratulationsModal();
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
    final accent = _mapboxColor(ref.read(colorsProvider));
    await _mapboxMap!.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: accent,
      pulsingMaxRadius: 40.0,
      showAccuracyRing: true,
      accuracyRingColor: accent & 0x22FFFFFF,
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
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
        if (!mounted) return;
        setState(() => _pulsePhase = (_pulsePhase + 1) % 3);
        _updateZoneCircles(_lastZones, _lastShowZones,
            currentZoneId: _lastCurrentZoneId);
      });
    } else if (!hasHighDemand) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
    }
    final themeColors = ref.read(colorsProvider);
    final zoneAccent = _mapboxColor(themeColors);
    final cardArgb = themeColors.card.toARGB32();
    final options = <CircleAnnotationOptions>[];
    for (final z in zones) {
      if (z.centerLat == null || z.centerLng == null) continue;
      final n = z.waitingPassengers;
      final tier = hotspotTierForDemand(n);
      final outerColor = hotspotHeatOuterArgb(themeColors, tier);
      final innerColor = hotspotHeatInnerArgb(themeColors, tier);
      var outerR = ((z.radiusM ?? 500) / 7).clamp(20.0, 82.0);
      var innerR = (outerR * 0.42).clamp(12.0, 34.0);
      if (n >= 20) {
        final pulseScale = _pulsePhase == 0
            ? 0.96
            : _pulsePhase == 1
                ? 1.0
                : 1.06;
        outerR *= pulseScale;
        innerR *= pulseScale;
      }
      final isCurrentZone = currentZoneId != null && z.zoneId == currentZoneId;
      // Outer halo circle
      options.add(CircleAnnotationOptions(
        geometry: Point(coordinates: Position(z.centerLng!, z.centerLat!)),
        circleColor: outerColor,
        circleRadius: outerR,
      ));
      // Inner core circle
      options.add(CircleAnnotationOptions(
        geometry: Point(coordinates: Position(z.centerLng!, z.centerLat!)),
        circleColor: innerColor,
        circleRadius: innerR,
        circleStrokeColor: isCurrentZone ? zoneAccent : cardArgb,
        circleStrokeWidth: isCurrentZone ? 3.0 : 1.5,
      ));
    }
    if (options.isNotEmpty) await _circleManager!.createMulti(options);
    await _updateZoneLabels(_mapboxMap!, showZones ? zones : []);
  }

  Future<void> _updateZoneLabels(MapboxMap map, List<ZoneDemand> zones) async {
    try {
      final features = <Map<String, dynamic>>[];
      for (final z in zones) {
        if (z.centerLat == null ||
            z.centerLng == null ||
            z.waitingPassengers < 4) {
          continue;
        }
        final zoneLabel = z.zoneName ?? z.zoneId;
        final label = z.waitingPassengers >= 4
            ? '$zoneLabel\n${DriverStrings.mapDemandWaiting(z.waitingPassengers)}'
            : zoneLabel;
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
        await map.style
            .setStyleSourceProperty(_zoneLabelsSourceId, 'data', geoJson);
      } else if (features.isNotEmpty) {
        await map.style
            .addSource(GeoJsonSource(id: _zoneLabelsSourceId, data: geoJson));
        final tc = ref.read(colorsProvider);
        final haloColor =
            ThemeData.estimateBrightnessForColor(tc.card) == Brightness.dark
                ? tc.bg
                : tc.card;
        await map.style.addLayer(SymbolLayer(
          id: _zoneLabelsLayerId,
          sourceId: _zoneLabelsSourceId,
          textFieldExpression: ['get', 'label'],
          textSize: 13.0,
          textColor: tc.text.toARGB32(),
          textHaloColor: haloColor.withValues(alpha: 0.94).toARGB32(),
          textHaloWidth: 2.0,
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
    final driverColors = DriverColors.fromTheme(colors);
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * _homeSheetInitialFraction;
    final zones = ref.watch(zoneDemandProvider).valueOrNull ?? [];
    final mapView = ref.watch(mapViewProvider);
    final currentZoneId = ref.watch(currentZoneIdProvider).valueOrNull;
    final themeId = HeyCabyAppChrome.themeIdOf(context);

    void updateZones() {
      _updateZoneCircles(
        zones,
        mapView == MapView.demandZones,
        currentZoneId: currentZoneId,
      );
    }

    ref.listen(zoneDemandProvider, (_, next) {
      next.whenData((z) => _updateZoneCircles(z, mapView == MapView.demandZones,
          currentZoneId: currentZoneId));
    });
    ref.listen(mapViewProvider, (_, next) {
      _updateZoneCircles(zones, next == MapView.demandZones,
          currentZoneId: currentZoneId);
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
      key: _scaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: _DriverDrawerHeader(
                  colors: colors,
                  typo: typo,
                  profile: ref.watch(driverProfileProvider).valueOrNull,
                  billingStatus:
                      ref.watch(driverBillingStatusProvider).valueOrNull,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                  children: [
                    _DrawerSectionLabel(
                      title: DriverStrings.drawerSectionMain,
                      colors: colors,
                      typo: typo,
                    ),
                    _DrawerActionTile(
                      icon: Icons.group_add_rounded,
                      title: DriverStrings.congratsInvite,
                      colors: colors,
                      typo: typo,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/driver/tell-friend');
                      },
                    ),
                    _DrawerActionTile(
                      icon: Icons.folder_open_rounded,
                      title: DriverStrings.documents,
                      colors: colors,
                      typo: typo,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/driver/documents');
                      },
                    ),
                    _DrawerActionTile(
                      icon: Icons.support_agent_rounded,
                      title: DriverStrings.support,
                      colors: colors,
                      typo: typo,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/driver/support');
                      },
                    ),
                    _DrawerActionTile(
                      icon: Icons.receipt_long,
                      title: DriverStrings.billing,
                      colors: colors,
                      typo: typo,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/driver/billing');
                      },
                    ),
                    _DrawerActionTile(
                      icon: Icons.help_center_rounded,
                      title: DriverStrings.faq,
                      colors: colors,
                      typo: typo,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/driver/faq');
                      },
                    ),
                    const SizedBox(height: 14),
                    _DrawerSectionLabel(
                      title: DriverStrings.drawerSectionLegal,
                      colors: colors,
                      typo: typo,
                      isExpandable: true,
                      isExpanded: _legalSectionExpanded,
                      onTap: () {
                        setState(() {
                          _legalSectionExpanded = !_legalSectionExpanded;
                        });
                      },
                    ),
                    if (_legalSectionExpanded) ...[
                      _DrawerActionTile(
                        icon: Icons.privacy_tip_outlined,
                        title: DriverStrings.privacyPolicy,
                        colors: colors,
                        typo: typo,
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/driver/privacy');
                        },
                      ),
                      _DrawerActionTile(
                        icon: Icons.gavel_rounded,
                        title: DriverStrings.termsOfService,
                        colors: colors,
                        typo: typo,
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/driver/terms');
                        },
                      ),
                      _DrawerActionTile(
                        icon: Icons.verified_user_outlined,
                        title: DriverStrings.indemnification,
                        colors: colors,
                        typo: typo,
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/driver/indemnification');
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    _DrawerSectionLabel(
                      title: DriverStrings.account,
                      colors: colors,
                      typo: typo,
                    ),
                    _DrawerActionTile(
                      icon: Icons.delete_forever_rounded,
                      title: DriverStrings.deleteAccount,
                      colors: colors,
                      typo: typo,
                      destructive: true,
                      onTap: () async {
                        Navigator.pop(context);
                        await performDriverAccountDeletion(context, ref);
                      },
                    ),
                    _DrawerActionTile(
                      icon: Icons.logout_rounded,
                      title: DriverStrings.logout,
                      colors: colors,
                      typo: typo,
                      destructive: true,
                      onTap: () async {
                        Navigator.pop(context);
                        await performDriverLogout(context, ref);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
          Positioned(
            top: MediaQuery.of(context).padding.top + DriverSpacing.sm,
            left: DriverSpacing.md,
            child: DriverMapFab(
              icon: Icons.menu_rounded,
              colors: driverColors,
              tooltip: DriverStrings.menu,
              semanticLabel: DriverStrings.menu,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _homeSheetInitialFraction,
            minChildSize: 0.22,
            maxChildSize: 0.72,
            snap: true,
            snapSizes: const [0.22, _homeSheetInitialFraction, 0.72],
            builder: (context, controller) => DriverHomeSheet(
              controller: controller,
              colors: colors,
              typo: typo,
              onOpenDriverHub: _showDriverHub,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverDrawerHeader extends StatelessWidget {
  const _DriverDrawerHeader({
    required this.colors,
    required this.typo,
    required this.profile,
    required this.billingStatus,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final dynamic profile;
  final Map<String, dynamic>? billingStatus;

  String _ledgerDrawerSubtitle(Map<String, dynamic>? s) {
    if (s == null) return DriverStrings.billingDash;
    final outstanding = s['outstanding_cents'];
    if (outstanding is num) {
      if (outstanding <= 0) return DriverStrings.platformBalanceCurrent;
      return '${DriverStrings.platformBalanceOutstanding}: €${(outstanding / 100).toStringAsFixed(2)}';
    }
    return DriverStrings.platformBalanceCurrent;
  }

  @override
  Widget build(BuildContext context) {
    final String rawName = (profile?.fullName as String? ?? '').trim();
    final String profilePhotoUrl =
        (profile?.profilePhotoUrl as String? ?? '').trim();
    final String displayName =
        rawName.isEmpty ? DriverStrings.drawerDefaultName : rawName;
    final String memberLabel = DriverStrings.drawerMember;
    final bool? paymentRequired = billingStatus == null
        ? null
        : (billingStatus?['payment_required'] == true);
    final bool hasLiveStatus = paymentRequired != null;
    final bool activePass = hasLiveStatus && paymentRequired == false;
    final String paymentTitle = !hasLiveStatus
        ? DriverStrings.drawerBillingStatusUnavailable
        : activePass
            ? DriverStrings.platformBalanceTitle
            : DriverStrings.platformBalanceRequestsPaused;
    final String paymentSubtitle = !hasLiveStatus
        ? DriverStrings.drawerBillingWaitingLiveStatus
        : _ledgerDrawerSubtitle(billingStatus);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withValues(alpha: 0.16),
            colors.card.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: profilePhotoUrl.isNotEmpty
                    ? Image.network(
                        profilePhotoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          color: colors.accent,
                          size: 30,
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.accent,
                              ),
                            ),
                          );
                        },
                      )
                    : Icon(Icons.person_rounded,
                        color: colors.accent, size: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      memberLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.bodySmall.copyWith(
                        color: colors.textSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                DriverStrings.driverRating,
                style: typo.labelSmall.copyWith(
                  color: colors.textSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Row(
                children: List.generate(
                  5,
                  (_) => Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: colors.warning,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: activePass
                  ? colors.success.withValues(alpha: 0.12)
                  : colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: activePass
                    ? colors.success.withValues(alpha: 0.38)
                    : colors.warning.withValues(alpha: 0.38),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  activePass
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: activePass ? colors.success : colors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paymentTitle,
                        style: typo.bodySmall.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        paymentSubtitle,
                        style: typo.bodySmall.copyWith(
                          color: colors.textSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel({
    required this.title,
    required this.colors,
    required this.typo,
    this.isExpandable = false,
    this.isExpanded = false,
    this.onTap,
  });

  final String title;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool isExpandable;
  final bool isExpanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        decoration: isExpandable
            ? BoxDecoration(
                color: colors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
              )
            : null,
        child: Row(
          children: [
            Text(
              title,
              style: isExpandable
                  ? typo.labelMedium.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    )
                  : typo.labelSmall.copyWith(
                      color: colors.textSoft,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
            ),
            if (isExpandable) ...[
              const Spacer(),
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: colors.accent,
                size: 24,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawerActionTile extends StatelessWidget {
  const _DrawerActionTile({
    required this.icon,
    required this.title,
    required this.colors,
    required this.typo,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tone = destructive ? colors.error : colors.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border.withValues(alpha: 0.8)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: tone),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: typo.bodyMedium.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
