import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../services/driver_data_service.dart';
import 'driver_rate_profile_controls.dart';

class DriverRateProfileQuickSwitch extends StatelessWidget {
  const DriverRateProfileQuickSwitch({
    super.key,
    required this.colors,
    required this.typo,
    required this.activeProfile,
    required this.standardProfile,
    required this.morningProfile,
    required this.eveningProfile,
    required this.weekendProfile,
    required this.lateNightProfile,
    required this.isSaving,
    required this.onTapProfile,
    required this.onCreatePresets,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final DriverRateProfile? activeProfile;
  final DriverRateProfile? standardProfile;
  final DriverRateProfile? morningProfile;
  final DriverRateProfile? eveningProfile;
  final DriverRateProfile? weekendProfile;
  final DriverRateProfile? lateNightProfile;
  final bool isSaving;
  final void Function(DriverRateProfile profile) onTapProfile;
  final Future<void> Function() onCreatePresets;

  @override
  Widget build(BuildContext context) {
    final hasMissingPreset = morningProfile == null ||
        eveningProfile == null ||
        weekendProfile == null ||
        lateNightProfile == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          DriverStrings.tariffQuickSwitch,
          style: typo.labelSmall.copyWith(
            color: colors.textSoft,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 156,
              child: DriverTariffModeChip(
                title: DriverStrings.standardTariff,
                subtitle: DriverStrings.defaultRates,
                selected: activeProfile?.id == standardProfile?.id,
                enabled: standardProfile != null,
                colors: colors,
                typo: typo,
                onTap: standardProfile == null
                    ? null
                    : () => onTapProfile(standardProfile!),
              ),
            ),
            SizedBox(
              width: 156,
              child: DriverTariffModeChip(
                title: DriverStrings.morningTariff,
                subtitle: DriverStrings.dayShift,
                selected: activeProfile?.id == morningProfile?.id,
                enabled: morningProfile != null,
                colors: colors,
                typo: typo,
                onTap: morningProfile == null
                    ? null
                    : () => onTapProfile(morningProfile!),
              ),
            ),
            SizedBox(
              width: 156,
              child: DriverTariffModeChip(
                title: DriverStrings.eveningTariff,
                subtitle: DriverStrings.peakHours,
                selected: activeProfile?.id == eveningProfile?.id,
                enabled: eveningProfile != null,
                colors: colors,
                typo: typo,
                onTap: eveningProfile == null
                    ? null
                    : () => onTapProfile(eveningProfile!),
              ),
            ),
            SizedBox(
              width: 156,
              child: DriverTariffModeChip(
                title: DriverStrings.weekendTariff,
                subtitle: DriverStrings.weekendShift,
                selected: activeProfile?.id == weekendProfile?.id,
                enabled: weekendProfile != null,
                colors: colors,
                typo: typo,
                onTap: weekendProfile == null
                    ? null
                    : () => onTapProfile(weekendProfile!),
              ),
            ),
            SizedBox(
              width: 156,
              child: DriverTariffModeChip(
                title: DriverStrings.lateNightTariff,
                subtitle: DriverStrings.afterDark,
                selected: activeProfile?.id == lateNightProfile?.id,
                enabled: lateNightProfile != null,
                colors: colors,
                typo: typo,
                onTap: lateNightProfile == null
                    ? null
                    : () => onTapProfile(lateNightProfile!),
              ),
            ),
          ],
        ),
        if (hasMissingPreset) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: isSaving ? null : onCreatePresets,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                isSaving
                    ? DriverStrings.creatingDayPartProfiles
                    : DriverStrings.createDayPartProfiles,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
