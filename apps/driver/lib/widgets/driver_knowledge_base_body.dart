import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_entry_flow_common.dart';

/// **Knowledge Base** — help articles shell (WebView slot).
class DriverKnowledgeBaseBody extends StatelessWidget {
  const DriverKnowledgeBaseBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.content,
    required this.onBack,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final Widget content;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DriverEntryFlowScaffold(
      title: DriverStrings.helpArticles,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DriverSpacing.screenEdge,
            DriverSpacing.sm,
            DriverSpacing.screenEdge,
            DriverSpacing.md,
          ),
          child: content,
        ),
      ),
    );
  }
}
