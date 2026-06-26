import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_chip.dart';
import 'driver_support_flow_common.dart';

/// **Raise Issue** — report problem fast.
class DriverRaiseIssueBody extends StatelessWidget {
  const DriverRaiseIssueBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.categories,
    required this.selectedCategory,
    required this.messageController,
    required this.sending,
    required this.onBack,
    required this.onCategorySelected,
    required this.onSend,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final List<String> categories;
  final String selectedCategory;
  final TextEditingController messageController;
  final bool sending;
  final VoidCallback onBack;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverSupportFlowScaffold(
      title: DriverStrings.nieuwBericht,
      colors: colors,
      typography: typography,
      centerTitle: true,
      onBack: onBack,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.md,
          DriverSpacing.screenEdge,
          bottomPad + DriverSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DriverStrings.messageCategory,
              style: typography.titleSmall.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ).driverFadeSlideIn(staggerIndex: 0),
            const SizedBox(height: DriverSpacing.sm),
            Wrap(
              spacing: DriverSpacing.sm,
              runSpacing: DriverSpacing.sm,
              children: categories.map((cat) {
                final selected = cat == selectedCategory;
                return DriverChip(
                  label: cat,
                  selected: selected,
                  colors: colors,
                  typography: typography,
                  onTap: () => onCategorySelected(cat),
                );
              }).toList(),
            ).driverFadeSlideIn(staggerIndex: 1),
            const SizedBox(height: DriverSpacing.xl),
            Expanded(
              child: TextField(
                controller: messageController,
                maxLines: null,
                maxLength: 500,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: typography.bodyMedium.copyWith(color: colors.text),
                decoration: InputDecoration(
                  hintText: DriverStrings.berichtTypen,
                  hintStyle: typography.bodyMedium.copyWith(
                    color: colors.textMuted,
                  ),
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
              ).driverFadeSlideIn(staggerIndex: 2),
            ),
            const SizedBox(height: DriverSpacing.lg),
            DriverButton(
              label: DriverStrings.versturen,
              onPressed: sending ? null : onSend,
              loading: sending,
              size: DriverButtonSize.lg,
              colors: colors,
              typography: typography,
            ).driverFadeSlideIn(staggerIndex: 3),
          ],
        ),
      ),
    );
  }
}
