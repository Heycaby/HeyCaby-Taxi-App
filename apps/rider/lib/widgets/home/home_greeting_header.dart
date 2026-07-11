import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/rider_profile_completeness_provider.dart';
import '../../providers/rider_profile_display_provider.dart';

/// Time-of-day greeting + rider name + optional profile completion chip.
class HomeGreetingHeader extends ConsumerWidget {
  const HomeGreetingHeader({super.key});

  String _greeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.homeGreetingMorning;
    if (hour < 17) return l10n.homeGreetingAfternoon;
    return l10n.homeGreetingEvening;
  }

  /// Light halo so greeting/name stay readable on the map (any tile brightness).
  static List<Shadow> _mapTextShadow(HeyCabyColorTokens colors) => [
        Shadow(
          color: colors.card.withValues(alpha: 0.92),
          blurRadius: 8,
        ),
        Shadow(
          color: colors.card.withValues(alpha: 0.65),
          blurRadius: 16,
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final completeness = ref.watch(riderProfileCompletenessProvider);
    final profile = ref.watch(riderProfileDisplayProvider);
    final name =
        profile.displayName.isNotEmpty ? profile.displayName : l10n.rider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _greeting(l10n),
          style: typo.bodyMedium.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w600,
            shadows: _mapTextShadow(colors),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: typo.headingLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
            fontSize: 28,
            height: 1.1,
            letterSpacing: -0.5,
            shadows: _mapTextShadow(colors),
          ),
        ),
        if (!completeness.isComplete) ...[
          const SizedBox(height: 10),
          _ProfileCompletionChip(
            colors: colors,
            typo: typo,
            l10n: l10n,
            percent: completeness.percent,
            onTap: () => context.push('/account'),
          ),
        ],
      ],
    );
  }
}

class _ProfileCompletionChip extends StatelessWidget {
  const _ProfileCompletionChip({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.percent,
    required this.onTap,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final int percent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: typo.labelLarge.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.homeCompleteProfile,
                style: typo.labelLarge.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textSoft, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
