import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../widgets/ride_swap_feed_content.dart';

/// Full-screen Ride Swap feed (same content as former Community tab).
class RideSwapScreen extends ConsumerWidget {
  const RideSwapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.text, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          DriverStrings.rideSwap,
          style: typo.headingLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: EasyRefresh(
        onRefresh: () async {
          ref.invalidate(rideSwapFeedProvider);
          await ref.read(rideSwapFeedProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  DriverStrings.rideSwapScreenIntro,
                  style: typo.bodySmall.copyWith(color: colors.textSoft, height: 1.4),
                ),
              ),
            ),
            const RideSwapFeedContent(),
          ],
        ),
      ),
    );
  }
}
