import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_ride_line_provider.dart';
import '../providers/driver_state_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';

/// Persistent glanceable ride line — visible without opening the home sheet.
class DriverRideLineStrip extends ConsumerWidget {
  const DriverRideLineStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(driverStateProvider);
    final boardAsync = ref.watch(driverRideLineProvider);
    final colors = ref.watch(colorsProvider);
    final driverColors = DriverColors.fromTheme(colors);

    final show = driver.appState == DriverAppState.onlineAvailable ||
        driver.appState == DriverAppState.onBreak ||
        driver.activeRideId != null;
    if (!show) return const SizedBox.shrink();

    return boardAsync.when(
      data: (board) {
        if (!board.hasNow && !board.hasNext) return const SizedBox.shrink();

        final lines = <String>[];
        if (board.now != null) {
          final fare = board.now!.fareLabel;
          lines.add(
            '${DriverStrings.rideLineNowLabel}: ${board.now!.routeLabel}'
            '${fare != null ? ' · $fare' : ''}',
          );
        }
        if (board.next != null) {
          final fare = board.next!.fareLabel;
          lines.add(
            '${DriverStrings.rideLineNextLabel}: ${board.next!.routeLabel}'
            '${fare != null ? ' · $fare' : ''}',
          );
        }

        return Material(
          color: colors.card.withValues(alpha: 0.96),
          elevation: 6,
          child: InkWell(
            onTap: () {
              HapticService.selectionClick();
              context.go('/driver');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: DriverSpacing.screenEdge,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: driverColors.primary.withValues(alpha: 0.25)),
                  bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in lines)
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
