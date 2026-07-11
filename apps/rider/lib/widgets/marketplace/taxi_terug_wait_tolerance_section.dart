import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/booking_provider.dart';

class TaxiTerugWaitToleranceSection extends ConsumerWidget {
  const TaxiTerugWaitToleranceSection({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  static const _options = [15, 30, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(bookingProvider).taxiTerugMaxWaitMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.taxiTerugWaitToleranceTitle,
          style: typo.titleSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.taxiTerugWaitToleranceBody,
          style: typo.bodySmall.copyWith(
            color: colors.textMid,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _options.map((minutes) {
            final isSelected = selected == minutes;
            return ChoiceChip(
              label: Text(l10n.taxiTerugWaitMinutes(minutes)),
              selected: isSelected,
              onSelected: (_) {
                HapticService.selectionClick();
                ref
                    .read(bookingProvider.notifier)
                    .setTaxiTerugMaxWaitMinutes(minutes);
              },
              selectedColor: colors.accent.withValues(alpha: 0.18),
              labelStyle: typo.labelMedium.copyWith(
                color: isSelected ? colors.accent : colors.text,
                fontWeight: FontWeight.w800,
              ),
              side: BorderSide(
                color: isSelected
                    ? colors.accent.withValues(alpha: 0.5)
                    : colors.border.withValues(alpha: 0.55),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
