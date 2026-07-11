import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

class DriverRateEditableField extends StatelessWidget {
  const DriverRateEditableField({
    super.key,
    required this.label,
    required this.controller,
    required this.colors,
    required this.typo,
    this.prefix,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: typo.labelSmall
                  .copyWith(color: colors.textSoft, fontSize: 11),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: typo.bodyMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
                prefixText: prefix,
                suffixText: suffix,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverRateChip extends StatelessWidget {
  const DriverRateChip({
    super.key,
    required this.label,
    required this.selected,
    required this.colors,
    required this.typo,
    this.onTap,
  });

  final String label;
  final bool selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.accent),
        ),
        child: Text(
          label,
          style: typo.bodySmall.copyWith(
            color: selected ? colors.text : colors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class DriverRateProfileDropdown extends StatelessWidget {
  const DriverRateProfileDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.selectedLabel,
    required this.selectedIsActive,
    required this.colors,
    required this.typo,
    required this.onChanged,
  });

  final String? value;
  final List<DropdownMenuItem<String>> items;
  final String selectedLabel;
  final bool selectedIsActive;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border.withValues(alpha: 0.85)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colors.textSoft,
            ),
            dropdownColor: colors.card,
            borderRadius: BorderRadius.circular(14),
            style: typo.bodyMedium.copyWith(color: colors.text),
            onChanged: onChanged,
            items: items,
            selectedItemBuilder: (context) {
              return items.map((item) {
                return Row(
                  children: [
                    Icon(Icons.stars_rounded, size: 16, color: colors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typo.bodyMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selectedIsActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          DriverStrings.active,
                          style: typo.labelSmall.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

class DriverTariffModeChip extends StatelessWidget {
  const DriverTariffModeChip({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? colors.accent.withValues(alpha: 0.2)
        : colors.card.withValues(alpha: enabled ? 0.96 : 0.55);
    final borderColor =
        selected ? colors.accent : colors.border.withValues(alpha: 0.85);
    final titleColor = enabled
        ? (selected ? colors.accent : colors.text)
        : colors.textSoft.withValues(alpha: 0.8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                      spreadRadius: -6,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selected) ...[
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: colors.accent),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.labelLarge.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                enabled ? subtitle : DriverStrings.notSet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.bodySmall.copyWith(
                  color: colors.textSoft,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverEditTariffsCard extends StatelessWidget {
  const DriverEditTariffsCard({
    super.key,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border.withValues(alpha: 0.85)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.edit_note_rounded,
                    color: colors.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DriverStrings.editTariffs,
                      style: typo.bodyMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DriverStrings.editTariffsHint,
                      style: typo.bodySmall.copyWith(color: colors.textSoft),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textSoft),
            ],
          ),
        ),
      ),
    );
  }
}
