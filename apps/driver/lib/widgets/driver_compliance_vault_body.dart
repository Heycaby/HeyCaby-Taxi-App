import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_card.dart';
import '../ui/driver_settings_row.dart';
import '../ui/driver_status_badge.dart';
import 'driver_settings_flow_common.dart';

/// Checklist row for compliance golden / vault header preview.
class DriverComplianceChecklistItem {
  const DriverComplianceChecklistItem({
    required this.title,
    required this.complete,
  });

  final String title;
  final bool complete;
}

/// **Compliance Vault** — header + checklist summary (forms stay in screen).
class DriverComplianceVaultBody extends StatelessWidget {
  const DriverComplianceVaultBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.checklistTitle,
    required this.checklistHint,
    required this.items,
    required this.onBack,
    required this.onRefreshChecklist,
    required this.content,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String checklistTitle;
  final String checklistHint;
  final List<DriverComplianceChecklistItem> items;
  final VoidCallback onBack;
  final VoidCallback onRefreshChecklist;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return DriverSettingsFlowScaffold(
      title: DriverStrings.complianceAndDocuments,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DriverSettingsHeader(
              title: DriverStrings.complianceAndDocuments,
              subtitle: DriverStrings.complianceSubtitleV2,
              colors: colors,
              typography: typography,
            ),
          ),
          if (items.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: DriverSpacing.screenEdge,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DriverSettingsSectionLabel(
                      label: checklistTitle,
                      colors: colors,
                      typography: typography,
                    ),
                    Text(
                      checklistHint,
                      style: typography.bodySmall.copyWith(
                        color: colors.textMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.md),
                    DriverCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        colors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    DriverStrings.complianceRequiredNowLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typography.labelSmall.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: DriverSpacing.sm),
                              Text(
                                DriverStrings.profileCompletionProgress(
                                  items.where((item) => item.complete).length,
                                  items.length,
                                ),
                                style: typography.labelSmall.copyWith(
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DriverSpacing.md),
                          for (final item in items) ...[
                            Row(
                              children: [
                                Icon(
                                  item.complete
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: item.complete
                                      ? colors.primary
                                      : colors.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: DriverSpacing.md),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: typography.bodyMedium.copyWith(
                                      color: colors.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DriverStatusBadge(
                                  label: item.complete
                                      ? DriverStrings.statusVerified
                                      : DriverStrings.statusRequired,
                                  colors: colors,
                                  typography: typography,
                                  tone: item.complete
                                      ? DriverStatusTone.success
                                      : DriverStatusTone.warning,
                                ),
                              ],
                            ),
                            if (item != items.last)
                              const SizedBox(height: DriverSpacing.md),
                          ],
                          const SizedBox(height: DriverSpacing.md),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: onRefreshChecklist,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                  DriverStrings.goOnlineChecklistRefresh),
                            ),
                          ),
                        ],
                      ),
                    ).driverFadeSlideIn(staggerIndex: 0),
                    const SizedBox(height: DriverSpacing.xl),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.screenEdge,
            ),
            sliver: SliverToBoxAdapter(child: content),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 88,
            ),
          ),
        ],
      ),
    );
  }
}
