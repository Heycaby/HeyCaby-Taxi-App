import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../utils/driver_tariff_profile_slots.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../services/sound_service.dart';
import 'driver_rate_profile_quick_switch.dart';

/// Reusable rate profile chips + rate line; used in earnings modal and Driver Hub.
class DriverRateProfileSection extends ConsumerStatefulWidget {
  const DriverRateProfileSection({
    super.key,
    required this.colors,
    required this.typo,
    required this.profiles,
    required this.activeProfile,
    required this.driverId,
    required this.isLoading,
    required this.onProfileSelected,
    required this.onCreateFirst,
    required this.onEditTariffs,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final List<DriverRateProfile> profiles;
  final DriverRateProfile? activeProfile;
  final String? driverId;
  final bool isLoading;
  final VoidCallback onProfileSelected;
  final VoidCallback onCreateFirst;
  final VoidCallback onEditTariffs;

  @override
  ConsumerState<DriverRateProfileSection> createState() =>
      _DriverRateProfileSectionState();
}

class _DriverRateProfileSectionState
    extends ConsumerState<DriverRateProfileSection> {
  bool _saving = false;
  String? _selectedProfileIdOverride;

  DriverRateProfile? _findById(String id) {
    for (final p in widget.profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> _onChipTap(String profileId) async {
    HapticService.selectionClick();
    unawaited(SoundService().playTariffSwitch());
    setState(() => _selectedProfileIdOverride = profileId);
    if (widget.driverId == null) return;
    if (widget.activeProfile?.id == profileId) {
      return;
    }
    final ok = await ref
        .read(driverDataServiceProvider)
        .switchRateProfile(widget.driverId!, profileId);
    if (!mounted) return;
    if (ok) {
      widget.onProfileSelected();
    }
  }

  String _tariffName(String profileName) {
    final lower = profileName.toLowerCase();
    if (lower.contains(DriverStrings.tariffSuffix)) return profileName;
    return '$profileName ${DriverStrings.tariffSuffix}';
  }

  @override
  Widget build(BuildContext context) {
    final displayedActiveProfile = _selectedProfileIdOverride == null
        ? widget.activeProfile
        : (_findById(_selectedProfileIdOverride!) ?? widget.activeProfile);
    final standardProfile =
        findTariffProfileBySlot(widget.profiles, DriverTariffProfileSlot.standard);
    final morningProfile =
        findTariffProfileBySlot(widget.profiles, DriverTariffProfileSlot.morning);
    final eveningProfile =
        findTariffProfileBySlot(widget.profiles, DriverTariffProfileSlot.evening);
    final weekendProfile =
        findTariffProfileBySlot(widget.profiles, DriverTariffProfileSlot.weekend);
    final lateNightProfile = findTariffProfileBySlot(
      widget.profiles,
      DriverTariffProfileSlot.lateNight,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: widget.colors.bgAlt.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.colors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: widget.colors.text.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: widget.colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.tune_rounded,
                  size: 15,
                  color: widget.colors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DriverStrings.activeRateProfile,
                style: widget.typo.labelSmall.copyWith(
                  color: widget.colors.textSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 20,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.colors.accent,
                  ),
                ),
              ),
            )
          else if (widget.profiles.isEmpty)
            GestureDetector(
              onTap: widget.onCreateFirst,
              child: Text(
                DriverStrings.setUpRates,
                style: widget.typo.bodySmall.copyWith(
                  color: widget.colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.colors.border.withValues(alpha: 0.7),
                ),
              ),
              child: Text(
                displayedActiveProfile == null
                    ? DriverStrings.notSet
                    : _tariffName(displayedActiveProfile.profileName),
                style: widget.typo.bodyLarge.copyWith(
                  color: widget.colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (displayedActiveProfile != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.colors.border.withValues(alpha: 0.75),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DriverStrings.activeTariffPricing,
                    style: widget.typo.labelSmall.copyWith(
                      color: widget.colors.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _PricePill(
                          label: DriverStrings.rateStart,
                          value:
                              '€${displayedActiveProfile.baseFare.toStringAsFixed(2)}',
                          colors: widget.colors,
                          typo: widget.typo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PricePill(
                          label: DriverStrings.ratePerKm,
                          value:
                              '€${displayedActiveProfile.perKmRate.toStringAsFixed(2)}',
                          colors: widget.colors,
                          typo: widget.typo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _PricePill(
                          label: DriverStrings.ratePerMin,
                          value:
                              '€${displayedActiveProfile.perMinRate.toStringAsFixed(2)}',
                          colors: widget.colors,
                          typo: widget.typo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PricePill(
                          label: DriverStrings.waitPerMin,
                          value:
                              '€${displayedActiveProfile.waitingRate.toStringAsFixed(2)}',
                          colors: widget.colors,
                          typo: widget.typo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (!widget.isLoading && widget.profiles.isNotEmpty)
            const SizedBox(height: 6),
          if (!widget.isLoading && widget.profiles.isNotEmpty)
            DriverRateProfileQuickSwitch(
              colors: widget.colors,
              typo: widget.typo,
              activeProfile: displayedActiveProfile,
              standardProfile: standardProfile,
              morningProfile: morningProfile,
              eveningProfile: eveningProfile,
              weekendProfile: weekendProfile,
              lateNightProfile: lateNightProfile,
              isSaving: _saving,
              onTapProfile: (profile) => _onChipTap(profile.id),
              onCreatePresets: () async {
                if (widget.driverId == null) return;
                setState(() => _saving = true);
                final ok = await ref
                    .read(driverDataServiceProvider)
                    .ensureTariffPresetProfiles(widget.driverId!);
                if (!mounted) return;
                setState(() => _saving = false);
                if (ok) widget.onProfileSelected();
              },
            ),
        ],
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
  });

  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: typo.labelSmall.copyWith(color: colors.textSoft),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: typo.bodyMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}
