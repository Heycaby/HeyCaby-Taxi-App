import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/driver_data_providers.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_ride_swap_body.dart';
import '../widgets/ride_swap_feed_content.dart';

/// Full-screen Ride Swap feed (same content as former Community tab).
class RideSwapScreen extends ConsumerWidget {
  const RideSwapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final themeColors = ref.watch(colorsProvider);
    final themeTypo = ref.watch(typographyProvider);

    return DriverRideSwapBody(
      colors: colors,
      typography: typography,
      onBack: () => context.pop(),
      onRefresh: () async {
        ref.invalidate(rideSwapFeedProvider);
        await ref.read(rideSwapFeedProvider.future);
      },
      onShowInfo: () => showRideSwapHowBottomSheet(
        context: context,
        ref: ref,
        colors: themeColors,
        typo: themeTypo,
      ),
      feed: const CustomScrollView(
        slivers: [
          RideSwapFeedContent(),
        ],
      ),
    );
  }
}
