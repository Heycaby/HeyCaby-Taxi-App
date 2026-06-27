import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../constants/driver_progressive_verification.dart';
import '../l10n/driver_strings.dart';
import '../models/driver_runtime_models.dart';
import '../providers/driver_runtime_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../utils/driver_readiness_routes.dart';

/// Home banner for onboarding V2 progressive verification milestones.
class DriverProgressiveVerificationBanner extends ConsumerWidget {
  const DriverProgressiveVerificationBanner({super.key});

  String _milestoneHint(DriverReadinessState readiness) {
    if (readiness.completedRides >= 50) {
      return DriverStrings.progressiveVerificationMilestone50Hint;
    }
    return DriverStrings.progressiveVerificationMilestone10Hint;
  }

  void _openDocs(BuildContext context, DriverReadinessState readiness) {
    HapticService.selectionClick();
    final missing = readiness.missingItems;
    if (missing.isNotEmpty) {
      final route = flutterRouteForReadinessItem(missing.first);
      if (route != null) {
        context.push(route);
        return;
      }
    }
    context.push('/driver/documents');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(driverRuntimeSnapshotProvider);
    if (configAsync.valueOrNull?.config.driverOnboardingV2 != true) {
      return const SizedBox.shrink();
    }

    final readiness = configAsync.valueOrNull?.readiness;
    if (readiness == null) {
      return const SizedBox.shrink();
    }

    // Passive onboarding: no KVK/chauffeur/Veriff messaging before 10 completed rides.
    if (readiness.completedRides < kDriverProgressiveVerificationStartsAt) {
      return const SizedBox.shrink();
    }

    if (!readiness.hasUpcomingMilestone && readiness.canGoOnline) {
      return const SizedBox.shrink();
    }

    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final rides = readiness.completedRides;
    final milestone = readiness.nextMilestoneAt;
    final blockingMissing = readiness.missingItems;
    if (blockingMissing.isEmpty && readiness.canGoOnline) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: DriverSpacing.md),
      child: Material(
        color: colors.surface,
        borderRadius: DriverRadius.mdAll,
        child: InkWell(
          borderRadius: DriverRadius.mdAll,
          onTap: () => _openDocs(context, readiness),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DriverSpacing.md),
            decoration: BoxDecoration(
              borderRadius: DriverRadius.mdAll,
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DriverStrings.progressiveVerificationProgress(rides, milestone),
                  style: typography.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _milestoneHint(readiness),
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (!readiness.canGoOnline) ...[
                  const SizedBox(height: 8),
                  Text(
                    readiness.statusMessage ?? '',
                    style: typography.bodySmall.copyWith(color: colors.warning),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  DriverStrings.progressiveVerificationCompleteDocs,
                  style: typography.labelLarge.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
