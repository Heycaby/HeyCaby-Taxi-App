import 'package:flutter/material.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_card.dart';
import 'driver_trust_flow_common.dart';

/// **Liability Acknowledgment** — full indemnification document + consent.
class DriverLiabilityAcknowledgmentBody extends StatelessWidget {
  const DriverLiabilityAcknowledgmentBody({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.documentText,
    required this.waiverText,
    required this.checkboxText,
    required this.isDutch,
    required this.isChecked,
    required this.onBack,
    required this.onSelectEnglish,
    required this.onSelectDutch,
    required this.onToggleLanguage,
    required this.onCopy,
    required this.onCheckedChanged,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final String documentText;
  final String waiverText;
  final String checkboxText;
  final bool isDutch;
  final bool isChecked;
  final VoidCallback onBack;
  final VoidCallback onSelectEnglish;
  final VoidCallback onSelectDutch;
  final VoidCallback onToggleLanguage;
  final VoidCallback onCopy;
  final ValueChanged<bool> onCheckedChanged;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverTrustFlowScaffold(
      title: title,
      colors: colors,
      typography: typography,
      onBack: onBack,
      actions: driverLegalTrustAppBarActions(
        colors: colors,
        typography: typography,
        isDutch: isDutch,
        onToggleLanguage: onToggleLanguage,
        onCopy: onCopy,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.md,
          DriverSpacing.screenEdge,
          bottomPad + DriverSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DriverLegalLanguageToolbar(
              colors: colors,
              typography: typography,
              isDutch: isDutch,
              onSelectEnglish: onSelectEnglish,
              onSelectDutch: onSelectDutch,
              onCopy: onCopy,
            ),
            const SizedBox(height: DriverSpacing.lg),
            Text(
              documentText,
              style: typography.bodyMedium.copyWith(
                color: colors.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: DriverSpacing.xl),
            DriverCard(
              colors: colors,
              padding: const EdgeInsets.all(DriverSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waiverText,
                    style: typography.bodySmall.copyWith(
                      color: colors.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: DriverSpacing.lg),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onCheckedChanged(!isChecked),
                      borderRadius: BorderRadius.circular(DriverRadius.sm),
                      child: Container(
                        padding: const EdgeInsets.all(DriverSpacing.md),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? colors.success.withValues(alpha: 0.1)
                              : colors.backgroundAlt,
                          borderRadius: BorderRadius.circular(DriverRadius.sm),
                          border: Border.all(
                            color: isChecked ? colors.success : colors.border,
                            width: isChecked ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? colors.success
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isChecked
                                      ? colors.success
                                      : colors.textMuted,
                                  width: 2,
                                ),
                              ),
                              child: isChecked
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: colors.onPrimary,
                                      size: 18,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: DriverSpacing.md),
                            Expanded(
                              child: Text(
                                checkboxText,
                                style: typography.bodyMedium.copyWith(
                                  color: isChecked
                                      ? colors.text
                                      : colors.textSecondary,
                                  fontWeight: isChecked
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
