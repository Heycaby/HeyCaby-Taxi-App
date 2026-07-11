import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import 'driver_hotspots_models.dart';

class HotspotsTopBar extends StatelessWidget {
  const HotspotsTopBar({
    super.key,
    required this.colors,
    required this.typo,
    required this.onBack,
    required this.onRefresh,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(AppIcons.arrowBack, color: colors.text),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          Expanded(
            child: Text(
              DriverStrings.hotspots,
              textAlign: TextAlign.center,
              style: typo.titleLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: Icon(LucideIcons.refreshCw, color: colors.textMid),
            tooltip: DriverStrings.hotspots,
          ),
        ],
      ),
    );
  }
}

class HotspotsViewModeToggle extends StatelessWidget {
  const HotspotsViewModeToggle({
    super.key,
    required this.mode,
    required this.colors,
    required this.typo,
    required this.onChanged,
  });

  final HotspotsViewMode mode;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final ValueChanged<HotspotsViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ModeChip(
                label: DriverStrings.hotspotsLiveMap,
                selected: mode == HotspotsViewMode.liveMap,
                colors: colors,
                typo: typo,
                onTap: () => onChanged(HotspotsViewMode.liveMap),
              ),
            ),
            Expanded(
              child: _ModeChip(
                label: DriverStrings.hotspotsListView,
                selected: mode == HotspotsViewMode.list,
                colors: colors,
                typo: typo,
                onTap: () => onChanged(HotspotsViewMode.list),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.card : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          HapticService.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? colors.accent : Colors.transparent,
              width: selected ? 1.5 : 0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: typo.labelLarge.copyWith(
                color: selected ? colors.accent : colors.textMid,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HotspotsFilterStrip extends StatelessWidget {
  const HotspotsFilterStrip({
    super.key,
    required this.filter,
    required this.colors,
    required this.typo,
    required this.onFilter,
    required this.onFiltersChip,
  });

  final HotspotDemandFilter filter;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final ValueChanged<HotspotDemandFilter> onFilter;
  final VoidCallback onFiltersChip;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _DemandPill(
            icon: LucideIcons.flame,
            label: DriverStrings.hotspotsFilterHigh,
            active: filter == HotspotDemandFilter.high,
            activeColor: colors.error,
            colors: colors,
            typo: typo,
            onTap: () {
              HapticService.selectionClick();
              onFilter(filter == HotspotDemandFilter.high
                  ? HotspotDemandFilter.all
                  : HotspotDemandFilter.high);
            },
          ),
          const SizedBox(width: 8),
          _DemandPill(
            icon: LucideIcons.circle,
            label: DriverStrings.hotspotsFilterMedium,
            active: filter == HotspotDemandFilter.medium,
            activeColor: colors.warning,
            colors: colors,
            typo: typo,
            onTap: () {
              HapticService.selectionClick();
              onFilter(filter == HotspotDemandFilter.medium
                  ? HotspotDemandFilter.all
                  : HotspotDemandFilter.medium);
            },
          ),
          const SizedBox(width: 8),
          _DemandPill(
            icon: LucideIcons.circle,
            label: DriverStrings.hotspotsFilterLow,
            active: filter == HotspotDemandFilter.low,
            activeColor: colors.success,
            colors: colors,
            typo: typo,
            onTap: () {
              HapticService.selectionClick();
              onFilter(filter == HotspotDemandFilter.low
                  ? HotspotDemandFilter.all
                  : HotspotDemandFilter.low);
            },
          ),
          const SizedBox(width: 8),
          _DemandPill(
            icon: AppIcons.tune,
            label: DriverStrings.hotspotsFilters,
            active: false,
            activeColor: colors.accent,
            colors: colors,
            typo: typo,
            onTap: () {
              HapticService.selectionClick();
              onFiltersChip();
            },
            useAccentWhenInactive: true,
          ),
        ],
      ),
    );
  }
}

class _DemandPill extends StatelessWidget {
  const _DemandPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.colors,
    required this.typo,
    required this.onTap,
    this.useAccentWhenInactive = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;
  final bool useAccentWhenInactive;

  @override
  Widget build(BuildContext context) {
    final border = active ? activeColor : colors.border;
    final fg = active
        ? activeColor
        : (useAccentWhenInactive ? colors.accent : colors.textMid);
    final bg = active ? activeColor.withValues(alpha: 0.12) : colors.card;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: border.withValues(alpha: active ? 0.65 : 1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: typo.labelLarge.copyWith(
                  color: active ? colors.text : colors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showHotspotsLearnSheet(
    BuildContext context, HeyCabyColorTokens colors, HeyCabyTypography typo) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DriverStrings.hotspotsLearnTitle,
              style: typo.titleMedium
                  .copyWith(color: colors.text, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              DriverStrings.hotspotsLearnBody,
              style:
                  typo.bodyMedium.copyWith(color: colors.textMid, height: 1.35),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(DriverStrings.hotspotsLearnClose),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
