import 'package:flutter/material.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kGrowCityLastCelebratedMilestoneKey =
    'heycaby_grow_city_last_celebrated_milestone';

/// Shows a one-time celebration dialog when the backend reports a new milestone.
class RiderGrowCityMilestoneCelebration extends StatefulWidget {
  const RiderGrowCityMilestoneCelebration({
    super.key,
    required this.stats,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.child,
  });

  final CommunityGrowthStats stats;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final Widget child;

  @override
  State<RiderGrowCityMilestoneCelebration> createState() =>
      _RiderGrowCityMilestoneCelebrationState();
}

class _RiderGrowCityMilestoneCelebrationState
    extends State<RiderGrowCityMilestoneCelebration> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCelebrate());
  }

  @override
  void didUpdateWidget(covariant RiderGrowCityMilestoneCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stats.latestAchievedMilestone !=
            widget.stats.latestAchievedMilestone ||
        oldWidget.stats.milestoneJustReached !=
            widget.stats.milestoneJustReached) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCelebrate());
    }
  }

  Future<void> _maybeCelebrate() async {
    final milestone = widget.stats.milestoneJustReached ??
        (widget.stats.latestAchievedMilestone > 0
            ? widget.stats.latestAchievedMilestone
            : null);
    if (milestone == null || milestone <= 0 || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getInt(_kGrowCityLastCelebratedMilestoneKey) ?? 0;
    if (milestone <= lastSeen || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          widget.l10n.growCityMilestoneCelebrationTitle,
          style: widget.typo.titleMedium.copyWith(
            color: widget.colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          widget.l10n.growCityMilestoneCelebrationBody(
            formatCommunityCount(milestone),
          ),
          style: widget.typo.bodyMedium.copyWith(
            color: widget.colors.textMid,
            height: 1.45,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(widget.l10n.growCityMilestoneCelebrationCta),
          ),
        ],
      ),
    );

    await prefs.setInt(_kGrowCityLastCelebratedMilestoneKey, milestone);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
