import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_trust_flow_common.dart';

/// One section in terms / privacy scroll content.
class DriverLegalTrustSection {
  const DriverLegalTrustSection({
    required this.title,
    required this.body,
    this.onSupportTap,
  });

  final String title;
  final String body;
  final VoidCallback? onSupportTap;
}

/// **Legal Trust** — terms & privacy document reader.
class DriverLegalTrustBody extends StatelessWidget {
  const DriverLegalTrustBody({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.sections,
    required this.isDutch,
    required this.onBack,
    required this.onSelectEnglish,
    required this.onSelectDutch,
    required this.onToggleLanguage,
    required this.onCopy,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final List<DriverLegalTrustSection> sections;
  final bool isDutch;
  final VoidCallback onBack;
  final VoidCallback onSelectEnglish;
  final VoidCallback onSelectDutch;
  final VoidCallback onToggleLanguage;
  final VoidCallback onCopy;

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
            for (final section in sections)
              DriverLegalSectionCard(
                title: section.title,
                body: section.body,
                colors: colors,
                typography: typography,
                onSupportTap: section.onSupportTap,
              ),
          ],
        ),
      ),
    );
  }
}
