import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_button.dart';
import '../ui/driver_card.dart';
import 'driver_work_flow_common.dart';

/// **Referral Share** — tell-a-friend invite surface.
class DriverReferralShareBody extends StatelessWidget {
  const DriverReferralShareBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.loading,
    required this.errorMessage,
    required this.headline,
    required this.bullet,
    required this.showLinkUnavailable,
    required this.linkUnavailableTitle,
    required this.linkUnavailableHint,
    required this.inviteLinkLabel,
    required this.shareUrl,
    required this.shareLabel,
    required this.copyLabel,
    required this.onBack,
    required this.onShare,
    required this.onCopy,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final bool loading;
  final String? errorMessage;
  final String headline;
  final String bullet;
  final bool showLinkUnavailable;
  final String linkUnavailableTitle;
  final String linkUnavailableHint;
  final String inviteLinkLabel;
  final String shareUrl;
  final String shareLabel;
  final String copyLabel;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverWorkFlowScaffold(
      title: '',
      showTitle: false,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(DriverSpacing.xl),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: typography.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    DriverSpacing.screenEdge,
                    DriverSpacing.xl,
                    DriverSpacing.screenEdge,
                    bottomPad + DriverSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(DriverSpacing.xl),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_add_rounded,
                            color: colors.primary,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: DriverSpacing.xl),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: typography.titleLarge.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: DriverSpacing.md),
                      Text(
                        bullet,
                        textAlign: TextAlign.center,
                        style: typography.bodyMedium.copyWith(
                          color: colors.textMuted,
                          height: 1.5,
                        ),
                      ),
                      if (showLinkUnavailable) ...[
                        const SizedBox(height: DriverSpacing.xl),
                        DriverCard(
                          colors: colors,
                          padding: const EdgeInsets.all(DriverSpacing.lg),
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: colors.warning,
                                size: 24,
                              ),
                              const SizedBox(height: DriverSpacing.sm),
                              Text(
                                linkUnavailableTitle,
                                textAlign: TextAlign.center,
                                style: typography.bodyMedium.copyWith(
                                  color: colors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: DriverSpacing.xs),
                              Text(
                                linkUnavailableHint,
                                textAlign: TextAlign.center,
                                style: typography.bodySmall.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: DriverSpacing.xl),
                      DriverReferralLinkCard(
                        label: inviteLinkLabel,
                        shareUrl: shareUrl,
                        colors: colors,
                        typography: typography,
                      ),
                      const SizedBox(height: DriverSpacing.xl),
                      DriverButton(
                        label: shareLabel,
                        colors: colors,
                        typography: typography,
                        icon: Icons.ios_share_rounded,
                        onPressed: onShare,
                        size: DriverButtonSize.lg,
                      ),
                      const SizedBox(height: DriverSpacing.md),
                      DriverButton(
                        label: copyLabel,
                        colors: colors,
                        typography: typography,
                        variant: DriverButtonVariant.outline,
                        icon: Icons.link_rounded,
                        onPressed: onCopy,
                        size: DriverButtonSize.lg,
                      ),
                    ],
                  ),
                ),
    );
  }
}
