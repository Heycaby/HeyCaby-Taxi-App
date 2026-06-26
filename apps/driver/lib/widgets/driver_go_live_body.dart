import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_work_flow_common.dart';

/// **Go Live** — choose online / break / offline status.
class DriverGoLiveBody extends StatelessWidget {
  const DriverGoLiveBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.onBack,
    required this.onGoOnline,
    required this.onBreak,
    required this.onOffline,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onGoOnline;
  final VoidCallback onBreak;
  final VoidCallback onOffline;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverWorkFlowScaffold(
      title: DriverStrings.goOnlineTitle,
      colors: colors,
      typography: typography,
      onBack: loading ? () {} : onBack,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            DriverSpacing.screenEdge,
            DriverSpacing.xl,
            DriverSpacing.screenEdge,
            bottomPad + DriverSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DriverStrings.goOnlineChangeStatus,
                style: typography.titleMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: DriverSpacing.xl),
              DriverGoLiveStatusCard(
                icon: Icons.check_circle_rounded,
                label: DriverStrings.goOnlineCardGoOnline,
                subtitle: DriverStrings.goOnlineCardGoOnlineSubtitle,
                accentColor: colors.primary,
                colors: colors,
                typography: typography,
                onTap: loading ? null : onGoOnline,
              ),
              const SizedBox(height: DriverSpacing.md),
              DriverGoLiveStatusCard(
                icon: Icons.free_breakfast_rounded,
                label: DriverStrings.goOnlineCardBreak,
                subtitle: DriverStrings.goOnlineCardBreakSubtitle,
                accentColor: colors.warning,
                colors: colors,
                typography: typography,
                onTap: loading ? null : onBreak,
              ),
              const SizedBox(height: DriverSpacing.md),
              DriverGoLiveStatusCard(
                icon: Icons.power_off_rounded,
                label: DriverStrings.goOnlineCardOffline,
                subtitle: DriverStrings.goOnlineCardOfflineSubtitle,
                accentColor: colors.error,
                colors: colors,
                typography: typography,
                onTap: loading ? null : onOffline,
              ),
              if (loading) ...[
                const SizedBox(height: DriverSpacing.xl),
                Center(
                  child: CircularProgressIndicator(color: colors.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
