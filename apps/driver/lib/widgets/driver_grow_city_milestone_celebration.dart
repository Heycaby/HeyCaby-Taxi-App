import 'package:flutter/material.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/driver_grow_city_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';

const _kGrowCityLastCelebratedMilestoneKey =
    'heycaby_grow_city_last_celebrated_milestone';

class DriverGrowCityMilestoneCelebration extends StatefulWidget {
  const DriverGrowCityMilestoneCelebration({
    super.key,
    required this.stats,
    required this.colors,
    required this.typography,
    required this.strings,
    required this.child,
  });

  final CommunityGrowthStats stats;
  final DriverColors colors;
  final DriverTypography typography;
  final DriverGrowCityStrings strings;
  final Widget child;

  @override
  State<DriverGrowCityMilestoneCelebration> createState() =>
      _DriverGrowCityMilestoneCelebrationState();
}

class _DriverGrowCityMilestoneCelebrationState
    extends State<DriverGrowCityMilestoneCelebration> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCelebrate());
  }

  @override
  void didUpdateWidget(covariant DriverGrowCityMilestoneCelebration oldWidget) {
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
          widget.strings.milestoneCelebrationTitle,
          style: widget.typography.titleMedium.copyWith(
            color: widget.colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          widget.strings.milestoneCelebrationBody(
            formatCommunityCount(milestone),
          ),
          style: widget.typography.bodyMedium.copyWith(
            color: widget.colors.textSecondary,
            height: 1.45,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(widget.strings.milestoneCelebrationCta),
          ),
        ],
      ),
    );

    await prefs.setInt(_kGrowCityLastCelebratedMilestoneKey, milestone);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
