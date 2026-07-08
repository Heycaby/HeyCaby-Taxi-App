import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';
import 'package:intl/intl.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_status_badge.dart';
import '../widgets/driver_ride_detail_body.dart';

class DriverRideDetailScreen extends ConsumerWidget {
  const DriverRideDetailScreen({super.key, required this.rideId});

  final String rideId;

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/driver/my-rides');
  }

  DriverStatusTone _statusTone(String status) {
    final s = status.toLowerCase();
    if (s.contains('complete') || s.contains('paid')) {
      return DriverStatusTone.success;
    }
    if (s.contains('cancel')) {
      return DriverStatusTone.error;
    }
    return DriverStatusTone.neutral;
  }

  String _statusLabel(String status) {
    if (status.toLowerCase() == 'completed') {
      return DriverStrings.rideDetailFinished;
    }
    return status;
  }

  String _formatMoney(double? euro, String? currency) {
    final label = HeyCabyRideFare.formatEuroLabel(euro);
    if (label != null) return label;
    if (euro == null) return '—';
    final code = (currency ?? 'EUR').toUpperCase();
    return '$code ${euro.toStringAsFixed(2)}';
  }

  String _formatCents(int? cents, String? currency) {
    final label = HeyCabyRideFare.formatCentsLabel(cents);
    if (label != null) return label;
    if (cents == null) return '—';
    final code = (currency ?? 'EUR').toUpperCase();
    return '$code ${(cents / 100).toStringAsFixed(2)}';
  }

  String _paymentLabel(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '—';
    if (value.toLowerCase() == 'cash') return DriverStrings.cash;
    if (value.toLowerCase() == 'card') return DriverStrings.card;
    return value[0].toUpperCase() + value.substring(1);
  }

  String? _statsLabel(MyRideDetails ride) {
    final parts = <String>[];
    final km = ride.distanceKm;
    if (km != null && km > 0) {
      parts.add(DriverStrings.rideDetailDistanceKm(km.toStringAsFixed(1)));
    }
    final mins = ride.tripDurationMinutes;
    if (mins != null) {
      parts.add(DriverStrings.rideDetailDurationMin(mins.toString()));
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final detailAsync = ref.watch(myRideDetailsProvider(rideId));

    return detailAsync.when(
      data: (ride) {
        if (ride == null) {
          return DriverRideDetailBody(
            colors: colors,
            typography: typography,
            loading: false,
            errorMessage: null,
            notFound: true,
            dateLabel: '',
            statusLabel: '',
            statusTone: DriverStatusTone.neutral,
            pickupAddress: '',
            dropoffAddress: '',
            pickupTimeLabel: '',
            dropoffTimeLabel: '',
            statsLabel: null,
            fareLabel: '—',
            earningsLabel: '—',
            paymentMethodLabel: '—',
            platformFeeLabel: '—',
            showPlatformFee: false,
            canContactRider: false,
            rideRequestId: rideId,
            onBack: () => _handleBack(context),
          );
        }

        final locale = Localizations.localeOf(context).toString();
        final timeFmt = DateFormat.Hm(locale);
        final dateFmt = DateFormat('dd MMM yyyy, HH:mm', locale);

        final completed = ride.completedAt?.toLocal();
        final started = ride.startedAt?.toLocal() ?? ride.createdAt?.toLocal();
        final dateLabel = completed != null
            ? dateFmt.format(completed)
            : ride.createdAt != null
                ? dateFmt.format(ride.createdAt!.toLocal())
                : '—';

        final platformFee = ride.platformFeeCents ?? 0;

        return DriverRideDetailBody(
          colors: colors,
          typography: typography,
          loading: false,
          errorMessage: null,
          notFound: false,
          dateLabel: dateLabel,
          statusLabel: _statusLabel(ride.status),
          statusTone: _statusTone(ride.status),
          pickupAddress: ride.pickupAddress?.trim().isNotEmpty == true
              ? ride.pickupAddress!.trim()
              : '—',
          dropoffAddress: ride.destinationAddress?.trim().isNotEmpty == true
              ? ride.destinationAddress!.trim()
              : '—',
          pickupTimeLabel: started != null ? timeFmt.format(started) : '—',
          dropoffTimeLabel: completed != null ? timeFmt.format(completed) : '—',
          statsLabel: _statsLabel(ride),
          fareLabel: _formatMoney(ride.fare, ride.currency),
          earningsLabel:
              _formatCents(ride.resolvedEarningsCents, ride.currency),
          paymentMethodLabel: _paymentLabel(ride.paymentMethod),
          platformFeeLabel: _formatCents(platformFee, ride.currency),
          showPlatformFee: platformFee > 0,
          canContactRider: ride.canContactRider,
          rideRequestId: rideId,
          onBack: () => _handleBack(context),
          onContactRider: ride.canContactRider
              ? () => context.push('/driver/chat/$rideId')
              : null,
          onGetHelp: () => context.push('/driver/support'),
        );
      },
      loading: () => DriverRideDetailBody(
        colors: colors,
        typography: typography,
        loading: true,
        errorMessage: null,
        notFound: false,
        dateLabel: '',
        statusLabel: '',
        statusTone: DriverStatusTone.neutral,
        pickupAddress: '',
        dropoffAddress: '',
        pickupTimeLabel: '',
        dropoffTimeLabel: '',
        statsLabel: null,
        fareLabel: '—',
        earningsLabel: '—',
        paymentMethodLabel: '—',
        platformFeeLabel: '—',
        showPlatformFee: false,
        canContactRider: false,
        rideRequestId: rideId,
        onBack: () => _handleBack(context),
      ),
      error: (_, __) => DriverRideDetailBody(
        colors: colors,
        typography: typography,
        loading: false,
        errorMessage: DriverStrings.myRidesLoadFailed,
        notFound: false,
        dateLabel: '',
        statusLabel: '',
        statusTone: DriverStatusTone.neutral,
        pickupAddress: '',
        dropoffAddress: '',
        pickupTimeLabel: '',
        dropoffTimeLabel: '',
        statsLabel: null,
        fareLabel: '—',
        earningsLabel: '—',
        paymentMethodLabel: '—',
        platformFeeLabel: '—',
        showPlatformFee: false,
        canContactRider: false,
        rideRequestId: rideId,
        onBack: () => _handleBack(context),
      ),
    );
  }
}
