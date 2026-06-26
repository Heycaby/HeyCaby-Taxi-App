import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../services/driver_data_service.dart';

/// Demand tier for map + list styling (aligned with live `waiting_passengers`).
enum HotspotDemandTier {
  high,
  medium,
  low,
  quiet,
}

enum HotspotsViewMode { liveMap, list }

enum HotspotDemandFilter { all, high, medium, low }

HotspotDemandTier hotspotTierForDemand(int n) {
  if (n >= 20) return HotspotDemandTier.high;
  if (n >= 12) return HotspotDemandTier.medium;
  if (n >= 6) return HotspotDemandTier.low;
  return HotspotDemandTier.quiet;
}

Color hotspotTierFill(HeyCabyColorTokens colors, HotspotDemandTier t) {
  switch (t) {
    case HotspotDemandTier.high:
      return colors.error;
    case HotspotDemandTier.medium:
      return colors.warning;
    case HotspotDemandTier.low:
      return colors.accent;
    case HotspotDemandTier.quiet:
      return colors.success;
  }
}

int _argb(Color c, double opacity) {
  final o = opacity.clamp(0.0, 1.0);
  final a = (o * 255).round();
  final rgb = c.toARGB32() & 0xFFFFFF;
  return (a << 24) | rgb;
}

int hotspotHeatOuterArgb(HeyCabyColorTokens colors, HotspotDemandTier t) {
  return _argb(hotspotTierFill(colors, t), t == HotspotDemandTier.high ? 0.38 : 0.28);
}

int hotspotHeatInnerArgb(HeyCabyColorTokens colors, HotspotDemandTier t) {
  return _argb(hotspotTierFill(colors, t), t == HotspotDemandTier.high ? 0.92 : 0.82);
}

bool zonePassesHotspotFilter(ZoneDemand z, HotspotDemandFilter f) {
  final n = z.waitingPassengers;
  switch (f) {
    case HotspotDemandFilter.all:
      return true;
    case HotspotDemandFilter.high:
      return n >= 20;
    case HotspotDemandFilter.medium:
      return n >= 12 && n < 20;
    case HotspotDemandFilter.low:
      return n < 12;
  }
}

String hotspotSublineForZone(ZoneDemand z) {
  switch ((z.demandLevel ?? '').toLowerCase()) {
    case 'very_high':
      return DriverStrings.hotspotsSublineVeryBusy;
    case 'high':
      return DriverStrings.hotspotsSublineHighDemand;
    case 'medium':
      return DriverStrings.hotspotsSublineSteady;
    case 'low':
    case 'none':
      return DriverStrings.hotspotsSublineQuiet;
  }
  final n = z.waitingPassengers;
  if (n >= 20) return DriverStrings.hotspotsSublineVeryBusy;
  if (n >= 12) return DriverStrings.hotspotsSublineHighDemand;
  if (n >= 6) return DriverStrings.hotspotsSublineSteady;
  return DriverStrings.hotspotsSublineQuiet;
}

/// Maps `zone_demand_live.demand_level` when present.
String hotspotDemandLevelLine(ZoneDemand z) {
  switch ((z.demandLevel ?? '').toLowerCase()) {
    case 'very_high':
      return DriverStrings.hotspotsDemandVeryHigh;
    case 'high':
      return DriverStrings.hotspotsDemandHigh;
    case 'medium':
      return DriverStrings.hotspotsDemandMedium;
    case 'low':
      return DriverStrings.hotspotsDemandLow;
    case 'none':
      return DriverStrings.hotspotsDemandVeryLow;
    default:
      return hotspotDemandTierLabel(z);
  }
}

String hotspotDemandTierLabel(ZoneDemand z) {
  final n = z.waitingPassengers;
  if (n >= 20) return DriverStrings.hotspotsDemandVeryHigh;
  if (n >= 12) return DriverStrings.hotspotsDemandHigh;
  if (n >= 6) return DriverStrings.hotspotsDemandMedium;
  if (n >= 2) return DriverStrings.hotspotsDemandLow;
  return DriverStrings.hotspotsDemandVeryLow;
}
