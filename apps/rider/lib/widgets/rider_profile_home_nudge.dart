import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/rider_profile_completeness_provider.dart';

/// Subtle home-sheet reminder when profile is below 100% (name + email).
class RiderProfileHomeNudge extends ConsumerStatefulWidget {
  const RiderProfileHomeNudge({super.key});

  @override
  ConsumerState<RiderProfileHomeNudge> createState() =>
      _RiderProfileHomeNudgeState();
}

class _RiderProfileHomeNudgeState extends ConsumerState<RiderProfileHomeNudge> {
  bool _dismissed = false;

  String _body(AppLocalizations l10n, RiderProfileCompleteness c) {
    if (!c.hasName && !c.hasEmail) return l10n.riderProfileHomeNudgeBoth;
    if (!c.hasName) return l10n.riderProfileHomeNudgeNameOnly;
    return l10n.riderProfileHomeNudgeEmailOnly;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);
    final c = ref.watch(riderProfileCompletenessProvider);

    if (c.isComplete || _dismissed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
      child: Material(
        color: colors.accentL,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => context.push('/account'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.person_outline, color: colors.accent, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.riderProfileHomeNudgeTitle,
                        style: typo.labelLarge.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _body(l10n, c),
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSoft, size: 20),
                  onPressed: () => setState(() => _dismissed = true),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
