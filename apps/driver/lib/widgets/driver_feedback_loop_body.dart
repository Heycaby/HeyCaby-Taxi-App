import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import 'driver_ride_bolt_layout.dart';
import 'driver_ride_flow_common.dart';

/// **Feedback Loop** — Bolt-style post-ride rider rating.
class DriverFeedbackLoopBody extends StatelessWidget {
  const DriverFeedbackLoopBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.stars,
    required this.commentController,
    required this.maxCommentLength,
    required this.loading,
    required this.onStarSelected,
    required this.onSubmit,
    required this.onSkip,
    required this.onClose,
    this.headline,
    this.commentHint,
    this.submitLabel,
    this.skipLabel,
    this.riderName,
    this.destinationAddress,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final int stars;
  final TextEditingController commentController;
  final int maxCommentLength;
  final bool loading;
  final ValueChanged<int> onStarSelected;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;
  final VoidCallback onClose;
  final String? headline;
  final String? commentHint;
  final String? submitLabel;
  final String? skipLabel;
  final String? riderName;
  final String? destinationAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;

  @override
  Widget build(BuildContext context) {
    final effectiveHeadline = headline ?? DriverStrings.rateRiderHeadline;
    final effectiveCommentHint =
        commentHint ?? DriverStrings.rateRiderCommentHint;
    final effectiveSubmitLabel = submitLabel ?? DriverStrings.rateRiderSubmit;
    final effectiveSkipLabel = skipLabel ?? DriverStrings.rateRiderSkip;

    return DriverRideBoltScaffold(
      colors: colors,
      typography: typography,
      phase: DriverRideBoltPhase.completed,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      driverLat: destLat,
      driverLng: destLng,
      onClose: onClose,
      infoCard: DriverRideBoltInfoCard(
        colors: colors,
        typography: typography,
        heroPrimary: effectiveHeadline,
        heroSecondary: null,
        focusAddress: destinationAddress ?? '',
        riderName: riderName,
        successTone: true,
        extra: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                final filled = stars >= star;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onStarSelected(star);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DriverSpacing.xs,
                    ),
                    child: AnimatedScale(
                      scale: filled ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 44,
                        color: filled ? colors.primary : colors.border,
                      ),
                    ),
                  ),
                );
              }),
            ).driverFadeSlideIn(staggerIndex: 0),
            const SizedBox(height: DriverSpacing.lg),
            ListenableBuilder(
              listenable: commentController,
              builder: (context, _) {
                final commentLength = commentController.text.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: commentController,
                      maxLength: maxCommentLength,
                      maxLines: 3,
                      style: typography.bodyMedium.copyWith(color: colors.text),
                      decoration: InputDecoration(
                        hintText: effectiveCommentHint,
                        hintStyle: typography.bodyMedium.copyWith(
                          color: colors.textMuted,
                        ),
                        filled: true,
                        fillColor: colors.backgroundAlt.withValues(alpha: 0.7),
                        counterText: '',
                        contentPadding: const EdgeInsets.all(DriverSpacing.lg),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DriverRadius.md),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DriverRadius.md),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DriverRadius.md),
                          borderSide: BorderSide(
                            color: colors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: DriverSpacing.sm),
                    Text(
                      '$commentLength/$maxCommentLength',
                      style: typography.labelSmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomBar: DriverRideFlowBottomBar(
        colors: colors,
        typography: typography,
        primaryLabel: effectiveSubmitLabel,
        primaryIcon: Icons.check_rounded,
        onPrimary: loading ? null : onSubmit,
        primaryLoading: loading,
        tertiaryLabel: effectiveSkipLabel,
        onTertiary: loading ? null : onSkip,
      ),
    );
  }
}
