import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../services/driver_data_service.dart';
import 'driver_rate_profile_controls.dart';

class DriverRateProfilePricingEditor extends StatelessWidget {
  const DriverRateProfilePricingEditor({
    super.key,
    required this.colors,
    required this.typo,
    required this.profile,
    required this.baseCtrl,
    required this.perKmCtrl,
    required this.perMinCtrl,
    required this.waitCtrl,
    required this.isSaving,
    required this.onSave,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final DriverRateProfile profile;
  final TextEditingController baseCtrl;
  final TextEditingController perKmCtrl;
  final TextEditingController perMinCtrl;
  final TextEditingController waitCtrl;
  final bool isSaving;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          DriverStrings.pricingEditorActiveProfile,
          style: typo.labelSmall.copyWith(
            color: colors.textSoft,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DriverRateEditableField(
                label: DriverStrings.pricingBase,
                prefix: '€',
                controller: baseCtrl,
                colors: colors,
                typo: typo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DriverRateEditableField(
                label: DriverStrings.pricingPerKm,
                prefix: '€',
                controller: perKmCtrl,
                colors: colors,
                typo: typo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DriverRateEditableField(
                label: DriverStrings.pricingPerMin,
                prefix: '€',
                controller: perMinCtrl,
                colors: colors,
                typo: typo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DriverRateEditableField(
                label: DriverStrings.pricingWaitPerMin,
                prefix: '€',
                suffix: '/min',
                controller: waitCtrl,
                colors: colors,
                typo: typo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          profile.ratesLine,
          style: typo.bodySmall.copyWith(
            color: colors.textSoft,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: const Icon(Icons.save_outlined, size: 16),
            label: Text(
              isSaving
                  ? DriverStrings.pricingSaving
                  : DriverStrings.pricingSaveRates,
            ),
          ),
        ),
      ],
    );
  }
}
