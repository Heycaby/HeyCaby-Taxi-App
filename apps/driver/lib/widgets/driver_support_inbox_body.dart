import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_card.dart';
import '../ui/driver_empty_state.dart';
import '../ui/driver_skeleton.dart';
import '../ui/driver_status_badge.dart';
import 'driver_support_flow_common.dart';

/// Inbox row display model.
class DriverSupportInboxItem {
  const DriverSupportInboxItem({
    required this.category,
    required this.statusLabel,
    required this.statusTone,
    required this.preview,
    this.timeLabel,
  });

  final String category;
  final String statusLabel;
  final DriverStatusTone statusTone;
  final String preview;
  final String? timeLabel;
}

/// **Support Inbox** — open tickets visible.
class DriverSupportInboxBody extends StatelessWidget {
  const DriverSupportInboxBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.items,
    required this.onBack,
    required this.onItemTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final List<DriverSupportInboxItem> items;
  final VoidCallback onBack;
  final ValueChanged<int> onItemTap;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverSupportFlowScaffold(
      title: DriverStrings.berichten,
      colors: colors,
      typography: typography,
      centerTitle: true,
      onBack: onBack,
      body: loading
          ? Center(
              child: DriverSkeleton(colors: colors, width: 200, height: 24),
            )
          : items.isEmpty
              ? DriverEmptyState(
                  icon: Icons.inbox_outlined,
                  title: DriverStrings.geenBerichten,
                  colors: colors,
                  typography: typography,
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    DriverSpacing.screenEdge,
                    DriverSpacing.md,
                    DriverSpacing.screenEdge,
                    bottomPad + DriverSpacing.lg,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: DriverSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return DriverCard(
                      colors: colors,
                      child: DriverSupportTicketRow(
                        category: item.category,
                        statusLabel: item.statusLabel,
                        statusTone: item.statusTone,
                        preview: item.preview,
                        timeLabel: item.timeLabel,
                        colors: colors,
                        typography: typography,
                        onTap: () => onItemTap(index),
                      ),
                    ).driverFadeSlideIn(staggerIndex: index);
                  },
                ),
    );
  }
}
