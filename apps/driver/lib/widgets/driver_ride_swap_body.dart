import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_empty_state.dart';
import 'driver_work_flow_common.dart';

/// **Ride Swap** — marketplace feed shell.
class DriverRideSwapBody extends StatelessWidget {
  const DriverRideSwapBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.onBack,
    required this.onRefresh,
    required this.onShowInfo,
    required this.feed,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  final VoidCallback onShowInfo;
  final Widget feed;

  @override
  Widget build(BuildContext context) {
    return DriverWorkFlowScaffold(
      title: DriverStrings.rideSwap,
      colors: colors,
      typography: typography,
      onBack: onBack,
      actions: [
        IconButton(
          tooltip: DriverStrings.rideSwapHowTitle,
          icon: Icon(Icons.info_outline_rounded, color: colors.text),
          onPressed: onShowInfo,
        ),
      ],
      body: EasyRefresh(
        onRefresh: onRefresh,
        child: feed,
      ),
    );
  }
}

/// Static preview list for goldens (no provider feed).
class DriverRideSwapFeedPreview extends StatelessWidget {
  const DriverRideSwapFeedPreview({
    super.key,
    required this.colors,
    required this.typography,
    required this.items,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final List<DriverRideSwapOfferItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(DriverSpacing.screenEdge),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          DriverEmptyState(
            colors: colors,
            typography: typography,
            icon: Icons.swap_horiz_rounded,
            title: DriverStrings.swapFeedEmpty,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        DriverSpacing.screenEdge,
        DriverSpacing.sm,
        DriverSpacing.screenEdge,
        DriverSpacing.xl,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: DriverSpacing.md),
      itemBuilder: (_, index) => DriverRideSwapOfferCard(
        item: items[index],
        colors: colors,
        typography: typography,
        claimLabel: DriverStrings.swapConfirmCta,
        onClaim: () {},
      ),
    );
  }
}
