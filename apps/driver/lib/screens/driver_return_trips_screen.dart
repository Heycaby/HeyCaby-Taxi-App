import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';

final _returnDiscountPctProvider = StateProvider<double>((_) => 0);

class DriverReturnTripsScreen extends ConsumerStatefulWidget {
  const DriverReturnTripsScreen({super.key});

  @override
  ConsumerState<DriverReturnTripsScreen> createState() => _DriverReturnTripsScreenState();
}

class _DriverReturnTripsScreenState extends ConsumerState<DriverReturnTripsScreen> {
  RealtimeChannel? _channel;
  Timer? _debounce;
  bool _initializedFromProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _channel = HeyCabySupabase.client
          .channel('return_market')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ride_requests',
            callback: (_) {
              ref.invalidate(driverReturnTripsProvider);
              ref.invalidate(filteredReturnTripsProvider);
            },
          )
          .subscribe();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_channel != null) {
      HeyCabySupabase.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);

    final tripsAsync = ref.watch(filteredReturnTripsProvider);
    final trips = tripsAsync.valueOrNull ?? const <DriverReturnTrip>[];

    final activeProfile = ref.watch(activeRateProfileProvider).valueOrNull;
    final initialPct = (activeProfile?.returnDiscountPct ?? 0).clamp(0, 40).toDouble();
    final currentPct = ref.watch(_returnDiscountPctProvider);

    // Initialize slider once when profile loads (even if 0).
    if (activeProfile != null && !_initializedFromProfile) {
      _initializedFromProfile = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_returnDiscountPctProvider.notifier).state = initialPct;
      });
    }

    final first = trips.isNotEmpty ? trips.first : null;
    final subtitle = first == null
        ? ''
        : '${first.pickupZoneName ?? '—'} → ${first.destinationZoneName ?? first.destinationCity ?? '—'}'
            '${first.distanceKm != null ? ' route, ${first.distanceKm!.toStringAsFixed(0)} km' : ''}';

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DriverStrings.returnTrips,
              style: typo.headingLarge.copyWith(color: colors.text, fontWeight: FontWeight.bold, fontSize: 22),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 13),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _DiscountCard(
              colors: colors,
              typo: typo,
              valuePct: currentPct,
              onChanged: (v) => _onDiscountChanged(activeProfile: activeProfile, v: v),
              computedFareText: _computedFareText(trips: trips, discountPct: currentPct),
              chanceLabel: _matchChanceLabel(discountPct: currentPct),
              chanceColor: _matchChanceColor(colors: colors, discountPct: currentPct),
            ),
            const SizedBox(height: 16),
            if (tripsAsync.isLoading)
              Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent))
            else if (trips.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Center(
                  child: Text(
                    'Geen retourritten beschikbaar.',
                    style: typo.bodyLarge.copyWith(color: colors.textSoft),
                  ),
                ),
              )
            else
              ...trips.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReturnTripCard(
                      trip: t,
                      colors: colors,
                      typo: typo,
                      discountPct: currentPct,
                      onAccept: t.rideRequestId == null
                          ? null
                          : () => context.push('/driver/ride/new/${t.rideRequestId}'),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  void _onDiscountChanged({required DriverRateProfile? activeProfile, required double v}) {
    final snapped = (v / 5).round() * 5.0;
    ref.read(_returnDiscountPctProvider.notifier).state = snapped;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      if (activeProfile == null) return;
      await ref.read(driverDataServiceProvider).updateReturnDiscountPct(
            rateProfileId: activeProfile.id,
            returnDiscountPct: snapped,
          );
      ref.invalidate(driverRateProfilesProvider);
      ref.invalidate(activeRateProfileProvider);
    });
  }

  String _computedFareText({required List<DriverReturnTrip> trips, required double discountPct}) {
    final fare = trips.isNotEmpty ? trips.first.offeredFare : null;
    if (fare == null) return '€—';
    final discounted = fare * (1 - (discountPct / 100));
    return '€${discounted.toStringAsFixed(2)}';
  }

  String _matchChanceLabel({required double discountPct}) {
    if (discountPct <= 10) return 'low';
    if (discountPct <= 25) return 'medium';
    return 'high';
  }

  Color _matchChanceColor({required HeyCabyColorTokens colors, required double discountPct}) {
    if (discountPct <= 10) return colors.error;
    if (discountPct <= 25) return colors.warning;
    return colors.success;
  }
}

class _DiscountCard extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final double valuePct;
  final ValueChanged<double> onChanged;
  final String computedFareText;
  final String chanceLabel;
  final Color chanceColor;

  const _DiscountCard({
    required this.colors,
    required this.typo,
    required this.valuePct,
    required this.onChanged,
    required this.computedFareText,
    required this.chanceLabel,
    required this.chanceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.yourReturnDiscount,
            style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600, fontSize: 17),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 0,
                  max: 40,
                  divisions: 8,
                  value: valuePct.clamp(0, 40),
                  activeColor: colors.accent,
                  inactiveColor: colors.border,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${valuePct.toStringAsFixed(0)}%',
                style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DriverStrings.returnDiscountSharedCosts}: $computedFareText',
                  style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: chanceColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: chanceColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  '${DriverStrings.matchChance}: $chanceLabel',
                  style: typo.bodySmall.copyWith(color: chanceColor, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReturnTripCard extends StatelessWidget {
  final DriverReturnTrip trip;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final double discountPct;
  final VoidCallback? onAccept;

  const _ReturnTripCard({
    required this.trip,
    required this.colors,
    required this.typo,
    required this.discountPct,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final from = trip.pickupZoneName ?? '—';
    final to = trip.destinationZoneName ?? trip.destinationCity ?? '—';
    final offered = trip.offeredFare;
    final discounted = offered == null ? null : offered * (1 - (discountPct / 100));
    final distance = trip.distanceKm;
    final duration = trip.estimatedDurationMin;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle)),
                  Container(width: 2, height: 28, color: colors.border),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: colors.textMid, shape: BoxShape.circle)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(from, style: typo.bodyMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(to, style: typo.bodyMedium.copyWith(color: colors.text, fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ),
              if (offered != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('€${offered.toStringAsFixed(2)}', style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 13)),
                    if (discounted != null)
                      Text(
                        '€${discounted.toStringAsFixed(2)}',
                        style: typo.titleMedium.copyWith(color: colors.text, fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (distance != null)
                Text('${distance.toStringAsFixed(1)} km', style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 13)),
              if (distance != null && duration != null) const SizedBox(width: 12),
              if (duration != null)
                Text('${duration.toStringAsFixed(0)} min', style: typo.bodySmall.copyWith(color: colors.textSoft, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              child: Text(
                DriverStrings.accept,
                style: typo.labelLarge.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

