import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import '../ui/driver_status_badge.dart';

/// Shared scaffold for work / growth surfaces.
class DriverWorkFlowScaffold extends StatelessWidget {
  const DriverWorkFlowScaffold({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.body,
    this.centerTitle = true,
    this.actions,
    this.showTitle = true,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final Widget body;
  final bool centerTitle;
  final List<Widget>? actions;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: showTitle
          ? DriverAppBar(
              title: title,
              colors: colors,
              typography: typography,
              centerTitle: centerTitle,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: colors.text),
                onPressed: onBack,
              ),
              actions: actions,
            )
          : AppBar(
              backgroundColor: colors.card,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: colors.text),
                onPressed: onBack,
              ),
            ),
      body: body,
    );
  }
}

/// Go-live status option card.
class DriverGoLiveStatusCard extends StatelessWidget {
  const DriverGoLiveStatusCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accentColor,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color accentColor;
  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DriverRadius.mdAll,
        child: DriverCard(
          colors: colors,
          padding: const EdgeInsets.all(DriverSpacing.xl),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DriverSpacing.md),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: DriverSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: typography.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: typography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Display model for ride swap feed rows.
class DriverRideSwapOfferItem {
  const DriverRideSwapOfferItem({
    required this.urgencyLabel,
    required this.expiresLabel,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.scheduleLabel,
    this.paymentLabel,
    required this.distanceLabel,
    this.urgencyTone = DriverStatusTone.warning,
  });

  final String urgencyLabel;
  final String expiresLabel;
  final String pickupAddress;
  final String destinationAddress;
  final String scheduleLabel;
  final String? paymentLabel;
  final String distanceLabel;
  final DriverStatusTone urgencyTone;
}

class DriverRideSwapOfferCard extends StatelessWidget {
  const DriverRideSwapOfferCard({
    super.key,
    required this.item,
    required this.colors,
    required this.typography,
    required this.claimLabel,
    required this.onClaim,
  });

  final DriverRideSwapOfferItem item;
  final DriverColors colors;
  final DriverTypography typography;
  final String claimLabel;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DriverStatusBadge(
            label: '${item.urgencyLabel} · ${item.expiresLabel}',
            colors: colors,
            typography: typography,
            tone: item.urgencyTone,
          ),
          const SizedBox(height: DriverSpacing.md),
          Text(
            item.pickupAddress,
            style: typography.bodyMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '→ ${item.destinationAddress}',
            style: typography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            item.scheduleLabel,
            style: typography.bodySmall.copyWith(color: colors.textMuted),
          ),
          if (item.paymentLabel != null)
            Text(
              item.paymentLabel!,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            item.distanceLabel,
            style: typography.bodySmall.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: DriverSpacing.md),
          DriverButton(
            label: claimLabel,
            colors: colors,
            typography: typography,
            onPressed: onClaim,
          ),
        ],
      ),
    );
  }
}

/// Public suggestion row.
class DriverSuggestionIdeaItem {
  const DriverSuggestionIdeaItem({
    required this.text,
    required this.statusLabel,
    required this.statusTone,
    required this.votesLabel,
  });

  final String text;
  final String statusLabel;
  final DriverStatusTone statusTone;
  final String votesLabel;
}

class DriverSuggestionIdeaCard extends StatelessWidget {
  const DriverSuggestionIdeaCard({
    super.key,
    required this.item,
    required this.colors,
    required this.typography,
  });

  final DriverSuggestionIdeaItem item;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.text,
            style: typography.bodyMedium.copyWith(color: colors.text),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Row(
            children: [
              DriverStatusBadge(
                label: item.statusLabel,
                colors: colors,
                typography: typography,
                tone: item.statusTone,
              ),
              const Spacer(),
              Text(
                item.votesLabel,
                style: typography.bodySmall.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Referral link card with selectable URL.
class DriverReferralLinkCard extends StatelessWidget {
  const DriverReferralLinkCard({
    super.key,
    required this.label,
    required this.shareUrl,
    required this.colors,
    required this.typography,
  });

  final String label;
  final String shareUrl;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return DriverCard(
      colors: colors,
      padding: const EdgeInsets.all(DriverSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: typography.labelMedium.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DriverSpacing.lg),
            decoration: BoxDecoration(
              color: colors.backgroundAlt,
              borderRadius: DriverRadius.smAll,
              border: Border.all(color: colors.border),
            ),
            child: SelectableText(
              shareUrl,
              style: typography.bodyLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
