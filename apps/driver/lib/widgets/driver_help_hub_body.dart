import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_settings_row.dart';
import '../ui/driver_skeleton.dart';
import '../ui/driver_status_badge.dart';
import 'driver_settings_flow_common.dart';
import 'driver_support_flow_common.dart';

/// Display row for recent tickets on the Help Hub.
class DriverHelpHubTicketPreview {
  const DriverHelpHubTicketPreview({
    required this.category,
    required this.statusLabel,
    required this.statusTone,
  });

  final String category;
  final String statusLabel;
  final DriverStatusTone statusTone;
}

/// **Help Hub** — find help in one tap.
class DriverHelpHubBody extends StatelessWidget {
  const DriverHelpHubBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.ticketsLoading,
    required this.tickets,
    required this.onBack,
    required this.onViewAllTickets,
    required this.onTicketTap,
    required this.onNewMessage,
    required this.onChatWithLee,
    required this.onViewThreads,
    required this.onViewFaq,
    this.onShiftHandoverAudit,
    this.onFleetAllowlist,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool ticketsLoading;
  final List<DriverHelpHubTicketPreview> tickets;
  final VoidCallback onBack;
  final VoidCallback onViewAllTickets;
  final ValueChanged<int> onTicketTap;
  final VoidCallback onNewMessage;
  final VoidCallback onChatWithLee;
  final VoidCallback onViewThreads;
  final VoidCallback onViewFaq;
  final VoidCallback? onShiftHandoverAudit;
  final VoidCallback? onFleetAllowlist;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverSupportFlowScaffold(
      title: DriverStrings.ondersteuning,
      colors: colors,
      typography: typography,
      centerTitle: true,
      onBack: onBack,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          DriverSpacing.screenEdge,
          DriverSpacing.md,
          DriverSpacing.screenEdge,
          bottomPad + DriverSpacing.xxl,
        ),
        children: [
          DriverSettingsHeader(
            title: DriverStrings.ondersteuning,
            subtitle: DriverStrings.chatWithSupportHelper,
            colors: colors,
            typography: typography,
          ).driverFadeSlideIn(staggerIndex: 0),
          DriverSupportSectionCard(
            title: DriverStrings.recenteRitten,
            colors: colors,
            typography: typography,
            trailingLabel: '${DriverStrings.alleZien} →',
            onTrailingTap: onViewAllTickets,
            child: ticketsLoading
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DriverSpacing.lg,
                    ),
                    child: DriverSkeleton(colors: colors, height: 56),
                  )
                : tickets.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: DriverSpacing.md,
                        ),
                        child: Text(
                          DriverStrings.geenBerichten,
                          style: typography.bodySmall.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < tickets.length; i++) ...[
                            DriverSupportTicketRow(
                              category: tickets[i].category,
                              statusLabel: tickets[i].statusLabel,
                              statusTone: tickets[i].statusTone,
                              colors: colors,
                              typography: typography,
                              onTap: () => onTicketTap(i),
                            ),
                            if (i < tickets.length - 1)
                              Divider(
                                color: colors.border.withValues(alpha: 0.5),
                              ),
                          ],
                        ],
                      ),
          ).driverFadeSlideIn(staggerIndex: 1),
          const SizedBox(height: DriverSpacing.lg),
          DriverSettingsSectionLabel(
            label: 'Contact',
            colors: colors,
            typography: typography,
          ),
          DriverSettingsGroupCard(
            colors: colors,
            children: [
              Padding(
                padding: const EdgeInsets.all(DriverSpacing.md),
                child: DriverSupportFeaturedRow(
                  icon: Icons.support_agent_rounded,
                  title: DriverStrings.chatWithLee,
                  subtitle: DriverStrings.leeSupportAssistant,
                  badgeLabel: 'AI',
                  colors: colors,
                  typography: typography,
                  onTap: onChatWithLee,
                ),
              ),
              DriverSupportNavRow(
                icon: Icons.add_comment_outlined,
                title: DriverStrings.nieuwBericht,
                colors: colors,
                typography: typography,
                onTap: onNewMessage,
              ),
              DriverSupportNavRow(
                icon: Icons.chat_outlined,
                title: DriverStrings.berichten,
                colors: colors,
                typography: typography,
                onTap: onViewThreads,
              ),
              DriverSupportNavRow(
                icon: Icons.help_outline_rounded,
                title: DriverStrings.helpArtikelen,
                colors: colors,
                typography: typography,
                onTap: onViewFaq,
                showDivider:
                    onShiftHandoverAudit != null || onFleetAllowlist != null,
              ),
              if (onShiftHandoverAudit != null)
                DriverSupportNavRow(
                  icon: Icons.shield_outlined,
                  title: DriverStrings.shiftHandoverAuditNavTitle,
                  colors: colors,
                  typography: typography,
                  onTap: onShiftHandoverAudit!,
                  showDivider: onFleetAllowlist != null,
                ),
              if (onFleetAllowlist != null)
                DriverSupportNavRow(
                  icon: Icons.people_outline_rounded,
                  title: DriverStrings.fleetAllowlistNavTitle,
                  colors: colors,
                  typography: typography,
                  onTap: onFleetAllowlist!,
                  showDivider: false,
                ),
            ],
          ).driverFadeSlideIn(staggerIndex: 2),
        ],
      ),
    );
  }
}
