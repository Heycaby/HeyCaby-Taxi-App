import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';

class TodayRidesScreen extends ConsumerWidget {
  const TodayRidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final ridesAsync = ref.watch(todayRidesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          DriverStrings.todaysRides,
          style: typo.headingLarge.copyWith(color: colors.text),
        ),
        centerTitle: true,
      ),
      body: ridesAsync.when(
        data: (rides) {
          if (rides.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_taxi, size: 48, color: colors.textSoft),
                  const SizedBox(height: 12),
                  Text(
                    DriverStrings.geenRittenVandaag,
                    style: typo.bodyMedium.copyWith(color: colors.textSoft),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _RideRow(
              ride: rides[i],
              colors: colors,
              typo: typo,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            'Kon ritten niet laden',
            style: typo.bodyMedium.copyWith(color: colors.textSoft),
          ),
        ),
      ),
    );
  }
}

class _RideRow extends StatelessWidget {
  final TodayRide ride;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  const _RideRow({
    required this.ride,
    required this.colors,
    required this.typo,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = ride.completedAt != null
        ? DateFormat('HH:mm').format(ride.completedAt!.toLocal())
        : '';
    final fareStr = ride.fare != null
        ? '€${ride.fare!.toStringAsFixed(2)}'
        : '—';
    final pickup = _zoneName(ride.pickup);
    final dest = _zoneName(ride.destination);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$pickup → $dest',
              style: typo.bodyMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fareStr,
            style: typo.bodyMedium.copyWith(
              color: colors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: typo.bodySmall.copyWith(color: colors.textSoft),
          ),
        ],
      ),
    );
  }

  String _zoneName(String? addr) {
    if (addr == null || addr.isEmpty) return '—';
    final parts = addr.split(',');
    return parts.first.trim();
  }
}
