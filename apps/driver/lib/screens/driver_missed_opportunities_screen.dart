import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_ride_line_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_app_bar.dart';
import '../utils/driver_ride_line_time.dart';

class DriverMissedOpportunitiesScreen extends ConsumerWidget {
  const DriverMissedOpportunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final driverColors = DriverColors.fromTheme(colors);
    final driverTypo = DriverTypography.fromTheme(typo);
    final missedAsync = ref.watch(driverMissedOpportunitiesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: DriverAppBar(
        title: DriverStrings.missedOpportunitiesTitle,
        colors: driverColors,
        typography: driverTypo,
      ),
      body: missedAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(DriverSpacing.lg),
                child: Text(
                  DriverStrings.missedOpportunitiesEmpty,
                  textAlign: TextAlign.center,
                  style: typo.bodyMedium.copyWith(color: colors.textSoft),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(DriverSpacing.screenEdge),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final item = items[i];
              final when = formatRideLineRelativeTime(item.missedAt);
              final fare = item.fareLabel ?? '—';
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.routeLabel,
                      style: typo.titleSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          fare,
                          style: typo.bodyMedium.copyWith(
                            color: colors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DriverStrings.missedOpportunityAgo(when),
                          style: typo.bodySmall.copyWith(color: colors.textSoft),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            DriverStrings.couldNotLoadRides,
            style: typo.bodyMedium.copyWith(color: colors.textSoft),
          ),
        ),
      ),
    );
  }
}
