import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../services/driver_data_service.dart';

/// Known driver tariff presets (standard + day-part slots).
enum DriverTariffProfileSlot {
  standard,
  morning,
  evening,
  weekend,
  lateNight,
  other,
}

extension DriverTariffProfileSlotX on DriverTariffProfileSlot {
  List<String> get matchTokens {
    switch (this) {
      case DriverTariffProfileSlot.standard:
        return const ['standard', 'standaard', 'default'];
      case DriverTariffProfileSlot.morning:
        return const ['morning', 'ochtend', 'day shift', 'dagdienst'];
      case DriverTariffProfileSlot.evening:
        return const ['evening', 'avond', 'eve', 'peak'];
      case DriverTariffProfileSlot.weekend:
        return const ['weekend', 'weekendtarief', 'sat', 'sun', 'zaterdag', 'zondag'];
      case DriverTariffProfileSlot.lateNight:
        return const [
          'late night',
          'latenight',
          'night',
          'nacht',
          'overnight',
          'midnight',
        ];
      case DriverTariffProfileSlot.other:
        return const [];
    }
  }

  int get presetSortOrder {
    switch (this) {
      case DriverTariffProfileSlot.standard:
        return 0;
      case DriverTariffProfileSlot.morning:
        return 10;
      case DriverTariffProfileSlot.evening:
        return 20;
      case DriverTariffProfileSlot.weekend:
        return 25;
      case DriverTariffProfileSlot.lateNight:
        return 30;
      case DriverTariffProfileSlot.other:
        return 100;
    }
  }

  String title() {
    switch (this) {
      case DriverTariffProfileSlot.standard:
        return DriverStrings.standardTariff;
      case DriverTariffProfileSlot.morning:
        return DriverStrings.morningTariff;
      case DriverTariffProfileSlot.evening:
        return DriverStrings.eveningTariff;
      case DriverTariffProfileSlot.weekend:
        return DriverStrings.weekendTariff;
      case DriverTariffProfileSlot.lateNight:
        return DriverStrings.lateNightTariff;
      case DriverTariffProfileSlot.other:
        return DriverStrings.tariffSuffix;
    }
  }

  String subtitle() {
    switch (this) {
      case DriverTariffProfileSlot.standard:
        return DriverStrings.defaultRates;
      case DriverTariffProfileSlot.morning:
        return DriverStrings.dayShift;
      case DriverTariffProfileSlot.evening:
        return DriverStrings.peakHours;
      case DriverTariffProfileSlot.weekend:
        return DriverStrings.weekendShift;
      case DriverTariffProfileSlot.lateNight:
        return DriverStrings.afterDark;
      case DriverTariffProfileSlot.other:
        return '';
    }
  }

  IconData get icon {
    switch (this) {
      case DriverTariffProfileSlot.standard:
        return Icons.local_taxi_rounded;
      case DriverTariffProfileSlot.morning:
        return Icons.wb_sunny_rounded;
      case DriverTariffProfileSlot.evening:
        return Icons.nights_stay_rounded;
      case DriverTariffProfileSlot.weekend:
        return Icons.weekend_rounded;
      case DriverTariffProfileSlot.lateNight:
        return Icons.dark_mode_rounded;
      case DriverTariffProfileSlot.other:
        return Icons.tune_rounded;
    }
  }
}

DriverTariffProfileSlot slotForProfileName(String profileName) {
  final n = profileName.toLowerCase().trim();
  const checkOrder = [
    DriverTariffProfileSlot.standard,
    DriverTariffProfileSlot.weekend,
    DriverTariffProfileSlot.lateNight,
    DriverTariffProfileSlot.evening,
    DriverTariffProfileSlot.morning,
  ];
  for (final slot in checkOrder) {
    for (final token in slot.matchTokens) {
      if (n.contains(token)) return slot;
    }
  }
  return DriverTariffProfileSlot.other;
}

DriverRateProfile? findTariffProfileBySlot(
  List<DriverRateProfile> profiles,
  DriverTariffProfileSlot slot,
) {
  if (slot == DriverTariffProfileSlot.other) return null;
  for (final p in profiles) {
    if (slotForProfileName(p.profileName) == slot) return p;
  }
  return null;
}

bool hasTariffPresetSlot(
  List<DriverRateProfile> profiles,
  DriverTariffProfileSlot slot,
) {
  return findTariffProfileBySlot(profiles, slot) != null;
}

List<DriverRateProfile> sortTariffProfiles(List<DriverRateProfile> profiles) {
  final copy = [...profiles];
  copy.sort((a, b) {
    final slotA = slotForProfileName(a.profileName);
    final slotB = slotForProfileName(b.profileName);
    final order = slotA.presetSortOrder.compareTo(slotB.presetSortOrder);
    if (order != 0) return order;
    final sortOrder = a.sortOrder.compareTo(b.sortOrder);
    if (sortOrder != 0) return sortOrder;
    return a.profileName.compareTo(b.profileName);
  });
  return copy;
}

String tariffProfileDisplayTitle(String profileName) {
  final slot = slotForProfileName(profileName);
  if (slot != DriverTariffProfileSlot.other) return slot.title();
  final lower = profileName.toLowerCase();
  if (lower.contains(DriverStrings.tariffSuffix)) return profileName;
  return '$profileName ${DriverStrings.tariffSuffix}';
}

String tariffProfileActiveHubSubtitle({
  required String profileName,
  required double perKmRate,
}) {
  var label = tariffProfileDisplayTitle(profileName);
  label = label
      .replaceAll(RegExp(r'\s+tariff$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+tarief$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+tarifa$', caseSensitive: false), '');
  return '$label · €${perKmRate.toStringAsFixed(2)}';
}

bool tariffPresetsIncomplete(List<DriverRateProfile> profiles) {
  return !hasTariffPresetSlot(profiles, DriverTariffProfileSlot.morning) ||
      !hasTariffPresetSlot(profiles, DriverTariffProfileSlot.evening) ||
      !hasTariffPresetSlot(profiles, DriverTariffProfileSlot.weekend) ||
      !hasTariffPresetSlot(profiles, DriverTariffProfileSlot.lateNight);
}
