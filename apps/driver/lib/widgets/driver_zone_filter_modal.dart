import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_map_providers.dart';

/// Zone view settings modal. Demand zones vs Clear map. Design: Bolt-style.
class DriverZoneFilterModal extends StatelessWidget {
  const DriverZoneFilterModal({
    super.key,
    required this.currentView,
    required this.colors,
    required this.typo,
    required this.onSelect,
    required this.onClose,
  });

  final MapView currentView;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final void Function(MapView) onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DriverStrings.zoneView,
                style: typo.headingLarge.copyWith(color: colors.text),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colors.textSoft),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ZoneOptionCard(
                  title: DriverStrings.demandZones,
                  description: DriverStrings.demandZonesDesc,
                  isSelected: currentView == MapView.demandZones,
                  colors: colors,
                  typo: typo,
                  onTap: () => onSelect(MapView.demandZones),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ZoneOptionCard(
                  title: DriverStrings.clearMap,
                  description: DriverStrings.clearMapDesc,
                  isSelected: currentView == MapView.clearMap,
                  colors: colors,
                  typo: typo,
                  onTap: () => onSelect(MapView.clearMap),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  const _ZoneOptionCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.accent : colors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typo.titleMedium.copyWith(color: colors.text),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: typo.bodySmall.copyWith(color: colors.textSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
