import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import '../ui/driver_card.dart';
import '../ui/driver_chip.dart';
import '../ui/driver_map_fab.dart';

/// Shared scaffold for demand & performance screens.
class DriverPerformanceFlowScaffold extends StatelessWidget {
  const DriverPerformanceFlowScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.body,
    this.centerTitle = true,
    this.bottomBar,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final Widget body;
  final bool centerTitle;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: DriverAppBar(
        title: title,
        colors: colors,
        typography: typography,
        centerTitle: centerTitle,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.text),
          onPressed: onBack,
        ),
      ),
      body: body,
      bottomNavigationBar: bottomBar,
    );
  }
}

/// Accent info strip used on scorecard (shield, review flag).
class DriverPerformanceInfoBanner extends StatelessWidget {
  const DriverPerformanceInfoBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.colors,
    required this.typography,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String body;
  final DriverColors colors;
  final DriverTypography typography;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(width: DriverSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typography.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sub-score progress row (1–5 scale).
class DriverPerformanceSubScoreRow extends StatelessWidget {
  const DriverPerformanceSubScoreRow({
    super.key,
    required this.label,
    required this.value,
    required this.colors,
    required this.typography,
  });

  final String label;
  final double value;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 5.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: DriverSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: typography.bodyMedium.copyWith(color: colors.text),
                ),
              ),
              Text(
                v.toStringAsFixed(1),
                style: typography.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (v / 5.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Passenger comment with report/dismiss menu.
class DriverPerformanceCommentCard extends StatelessWidget {
  const DriverPerformanceCommentCard({
    super.key,
    required this.comment,
    required this.colors,
    required this.typography,
    required this.onReport,
    required this.onDismiss,
    required this.reportLabel,
    required this.dismissLabel,
  });

  final String comment;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onReport;
  final VoidCallback onDismiss;
  final String reportLabel;
  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      margin: const EdgeInsets.only(bottom: DriverSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, color: colors.textMuted, size: 20),
          const SizedBox(width: DriverSpacing.sm),
          Expanded(
            child: Text(
              comment,
              style: typography.bodyMedium.copyWith(color: colors.text),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: colors.textMuted, size: 20),
            padding: EdgeInsets.zero,
            onSelected: (v) {
              if (v == 'report') onReport();
              if (v == 'dismiss') onDismiss();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'report', child: Text(reportLabel)),
              PopupMenuItem(value: 'dismiss', child: Text(dismissLabel)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Best-zone card on the demand radar map overlay.
class DriverDemandBestZoneCard extends StatelessWidget {
  const DriverDemandBestZoneCard({
    super.key,
    required this.zoneName,
    required this.waitingLabel,
    required this.colors,
    required this.typography,
    required this.tierColor,
    required this.onTap,
  });

  final String zoneName;
  final String waitingLabel;
  final DriverColors colors;
  final DriverTypography typography;
  final Color tierColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: DriverCard(
          colors: colors,
          padding: const EdgeInsets.all(DriverSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DriverSpacing.md),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: tierColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zoneName,
                      style: typography.titleSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      waitingLabel,
                      style: typography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Map overlay chrome: top bar + optional best zone + recenter FAB.
class DriverDemandRadarOverlay extends StatelessWidget {
  const DriverDemandRadarOverlay({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.onRefresh,
    required this.onRecenter,
    this.bestZoneName,
    this.bestZoneWaitingLabel,
    this.bestZoneTierColor,
    this.onBestZoneTap,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onRecenter;
  final String? bestZoneName;
  final String? bestZoneWaitingLabel;
  final Color? bestZoneTierColor;
  final VoidCallback? onBestZoneTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: Icon(Icons.arrow_back_rounded, color: colors.text),
                ),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: typography.titleLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  icon:
                      Icon(Icons.refresh_rounded, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: DriverSpacing.screenEdge,
          bottom: 180,
          child: DriverMapFab(
            icon: Icons.my_location_rounded,
            colors: colors,
            onTap: onRecenter,
          ),
        ),
        if (bestZoneName != null &&
            bestZoneWaitingLabel != null &&
            bestZoneTierColor != null &&
            onBestZoneTap != null)
          Positioned(
            left: DriverSpacing.screenEdge,
            right: DriverSpacing.screenEdge,
            bottom: DriverSpacing.screenEdge,
            child: DriverDemandBestZoneCard(
              zoneName: bestZoneName!,
              waitingLabel: bestZoneWaitingLabel!,
              tierColor: bestZoneTierColor!,
              colors: colors,
              typography: typography,
              onTap: onBestZoneTap!,
            ),
          ),
      ],
    );
  }
}

/// Tariff preset suggestion banner.
class DriverTariffPresetBanner extends StatelessWidget {
  const DriverTariffPresetBanner({
    super.key,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.busyLabel,
    required this.busy,
    required this.colors,
    required this.typography,
    required this.onApply,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final String busyLabel;
  final bool busy;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(DriverSpacing.md),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: colors.primary),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typography.titleSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.sm),
                    Text(
                      body,
                      style: typography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DriverSpacing.lg),
          FilledButton.icon(
            onPressed: busy ? null : onApply,
            icon: busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(busy ? busyLabel : buttonLabel),
          ),
        ],
      ),
    );
  }
}

/// Badge chip for scorecard achievements.
class DriverPerformanceBadgeChip extends StatelessWidget {
  const DriverPerformanceBadgeChip({
    super.key,
    required this.label,
    required this.colors,
    required this.typography,
  });

  final String label;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverChip(
      label: label,
      selected: true,
      colors: colors,
      typography: typography,
    );
  }
}
