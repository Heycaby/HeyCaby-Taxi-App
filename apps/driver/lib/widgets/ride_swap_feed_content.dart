import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_location_provider.dart';
import '../services/ride_swap_service.dart';

/// Localized “Hoe Ritwissel werkt” block: swap screen header, empty-info sheet, home help.
class RideSwapHowIntroSection extends StatelessWidget {
  const RideSwapHowIntroSection({
    super.key,
    required this.colors,
    required this.typo,
    this.includePullHint = false,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final bool includePullHint;

  static final List<String> _bulletKeys = [
    DriverStrings.rideSwapBulletViewSwaps,
    DriverStrings.rideSwapBulletCheckDetails,
    DriverStrings.rideSwapBulletTakeRide,
    DriverStrings.rideSwapBulletSupportColleague,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DriverStrings.rideSwapHowTitle,
          style: typo.titleSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DriverStrings.rideSwapHowParagraph1,
          style: typo.bodySmall.copyWith(color: colors.text, height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(
          DriverStrings.rideSwapHowParagraph2,
          style: typo.bodySmall.copyWith(color: colors.text, height: 1.4),
        ),
        const SizedBox(height: 14),
        Text(
          DriverStrings.rideSwapWhatYouCanDoHeading,
          style: typo.bodyMedium.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final line in _bulletKeys) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: typo.bodySmall.copyWith(color: colors.text),
                ),
                Expanded(
                  child: Text(
                    line,
                    style: typo.bodySmall.copyWith(
                      color: colors.text,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (includePullHint) ...[
          const SizedBox(height: 8),
          Text(
            DriverStrings.rideSwapPullToRefreshHint,
            style:
                typo.bodySmall.copyWith(color: colors.textSoft, height: 1.35),
          ),
        ],
      ],
    );
  }
}

/// Shared “Hoe Ritwissel werkt” bottom sheet (empty-feed auto prompt, in-screen info button, etc.).
Future<void> showRideSwapHowBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typo,
}) async {
  final initialHide =
      await ref.read(driverDataServiceProvider).isRideSwapIntroDismissed();
  if (!context.mounted) return;
  var dontShowAgain = initialHide;

  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RideSwapHowIntroSection(
                colors: colors,
                typo: typo,
                includePullHint: false,
              ),
              const SizedBox(height: 12),
              Text(
                DriverStrings.rideSwapInfoModalFooter,
                style: typo.bodySmall
                    .copyWith(color: colors.textSoft, height: 1.35),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: dontShowAgain,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  DriverStrings.rideSwapDontShowAgain,
                  style: typo.bodySmall.copyWith(color: colors.text),
                ),
                onChanged: (v) =>
                    setSheetState(() => dontShowAgain = v ?? false),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (dontShowAgain != initialHide) {
                      await ref
                          .read(driverDataServiceProvider)
                          .setRideSwapIntroDismissed(dontShowAgain);
                      ref.invalidate(rideSwapIntroDismissedProvider);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(DriverStrings.rideSwapGotIt),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Full-width list for Community → Ride Swap tab (open `ride_swaps` feed).
class RideSwapFeedContent extends ConsumerStatefulWidget {
  const RideSwapFeedContent({super.key});

  @override
  ConsumerState<RideSwapFeedContent> createState() =>
      _RideSwapFeedContentState();
}

bool _jsonBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  if (v is num) return v != 0;
  return false;
}

String _claimErrorMessage(Map<String, dynamic>? res) {
  final err = res?['error']?.toString() ?? '';
  switch (err) {
    case 'not_compliant':
      return DriverStrings.swapErrorNotCompliant;
    case 'expired':
      return DriverStrings.swapErrorExpired;
    case 'not_available':
      return DriverStrings.swapErrorNotAvailable;
    case 'own_swap':
      return DriverStrings.swapErrorOwnSwap;
    default:
      return err.isNotEmpty ? err : 'Mislukt';
  }
}

class _RideSwapFeedContentState extends ConsumerState<RideSwapFeedContent> {
  RealtimeChannel? _channel;
  bool _hasShownEmptyInfoModal = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    try {
      _channel = HeyCabySupabase.client.channel('public:ride_swaps');
      _channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ride_swaps',
            callback: (_) {
              if (mounted) ref.invalidate(rideSwapFeedProvider);
            },
          )
          .subscribe();
    } catch (_) {
      // Realtime optional if replication is off.
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  String _urgencyLabel(String u) {
    switch (u.toLowerCase()) {
      case 'emergency':
        return DriverStrings.swapUrgencyEmergency;
      case 'urgent':
        return DriverStrings.swapUrgencyUrgent;
      case 'moderate':
        return DriverStrings.swapUrgencyModerate;
      default:
        return DriverStrings.swapUrgencyStandard;
    }
  }

  Color _urgencyColor(HeyCabyColorTokens colors, String u) {
    switch (u.toLowerCase()) {
      case 'emergency':
        return colors.error;
      case 'urgent':
        return colors.warning;
      case 'moderate':
        return colors.warning;
      default:
        return colors.success;
    }
  }

  Future<void> _claim(RideSwapListing swap) async {
    final driverId = await ref.read(driverIdProvider.future);
    if (driverId == null || !mounted) return;
    final typo = ref.read(typographyProvider);

    final pickup = swap.pickupAt ?? DateTime.now();
    final dur = swap.estimatedDurationMin ?? 30;
    final check = await ref.read(rideSwapServiceProvider).canDriverTakeSwap(
          driverId: driverId,
          pickupAt: pickup,
          estimatedDurationMin: dur,
        );
    if (!mounted) return;
    final can = _jsonBool(check?['can_take']);
    final conflict = check?['reason']?.toString() == 'schedule_conflict' ||
        check?['reason']?.toString().contains('conflict') == true;
    if (!can || conflict) {
      final addr = check?['conflicting_address']?.toString() ??
          check?['conflictingAddress']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addr != null && addr.isNotEmpty
                ? '${DriverStrings.swapScheduleConflict}\n$addr'
                : DriverStrings.swapScheduleConflict,
          ),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(DriverStrings.swapConfirmTitle, style: typo.titleMedium),
        content: Text(DriverStrings.swapConfirmBody, style: typo.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(DriverStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(DriverStrings.swapConfirmCta),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final res = await ref.read(rideSwapServiceProvider).claimRideSwap(
          claimerId: driverId,
          swapId: swap.id,
        );
    if (!mounted) return;
    if (res?['success'] == true) {
      ref.invalidate(rideSwapFeedProvider);
      ref.invalidate(scheduledRidesByTabProvider('confirmed'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.swapClaimSuccess)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_claimErrorMessage(res))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final themeId = HeyCabyAppChrome.themeIdOf(context);
    final async = ref.watch(rideSwapFeedProvider);
    final pos = ref.watch(driverLocationProvider).valueOrNull;
    final introPref = ref.watch(rideSwapIntroDismissedProvider);
    final hideEmptyInfoModal = introPref.valueOrNull ?? false;
    final prefLoaded = introPref.hasValue;

    return async.when(
      data: (list) {
        if (list.isEmpty) {
          if (prefLoaded && !hideEmptyInfoModal && !_hasShownEmptyInfoModal) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _hasShownEmptyInfoModal || hideEmptyInfoModal) {
                return;
              }
              _hasShownEmptyInfoModal = true;
              showRideSwapHowBottomSheet(
                context: context,
                ref: ref,
                colors: colors,
                typo: typo,
              );
            });
          }
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swap_horiz_rounded,
                      size: 42, color: colors.textSoft),
                  const SizedBox(height: 12),
                  Text(
                    DriverStrings.swapFeedEmpty,
                    style: typo.bodyMedium.copyWith(color: colors.textSoft),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => showRideSwapHowBottomSheet(
                      context: context,
                      ref: ref,
                      colors: colors,
                      typo: typo,
                    ),
                    icon: const Icon(Icons.info_outline_rounded),
                    label: Text(DriverStrings.rideSwapHowButton),
                  ),
                ],
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final swap = list[i];
              final dist = distanceKmToPickup(
                pos?.latitude,
                pos?.longitude,
                swap.pickupLat,
                swap.pickupLng,
              );
              final distStr = dist.isFinite ? dist.toStringAsFixed(1) : '—';
              final expires = swap.swapExpiresAt;
              final minsToExpire = expires != null
                  ? expires.difference(DateTime.now()).inMinutes
                  : 0;
              final pickupStr = swap.pickupAt != null
                  ? DateFormat('HH:mm').format(swap.pickupAt!)
                  : '—';
              final pay = (swap.paymentMethods ?? []).join(' / ');
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _urgencyColor(colors, swap.urgency)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_urgencyLabel(swap.urgency)} · ${DriverStrings.swapExpiresIn} ${minsToExpire.clamp(0, 9999)} min',
                              style: typo.labelSmall.copyWith(
                                color: _urgencyColor(colors, swap.urgency),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '📍 ${swap.pickupAddress ?? '—'}',
                        style: typo.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '→ ${swap.destinationAddress ?? '—'}',
                        style: typo.bodySmall.copyWith(color: colors.textMid),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '🕐 Ophalen $pickupStr · ${swap.estimatedDistanceKm?.toStringAsFixed(1) ?? '—'} km · ${swap.estimatedDurationMin ?? '—'} min',
                        style: typo.bodySmall.copyWith(color: colors.textSoft),
                      ),
                      if (pay.isNotEmpty)
                        Text('💵 $pay',
                            style: typo.bodySmall
                                .copyWith(color: colors.textSoft)),
                      const SizedBox(height: 8),
                      Text(
                        '📍 ${DriverStrings.swapDistanceToPickup} $distStr ${DriverStrings.swapKmFromPickup}',
                        style: typo.bodySmall.copyWith(
                            color: colors.accent, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(DriverStrings.rideSwap,
                                        style: typo.titleMedium),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                              '${swap.pickupAddress ?? ''}\n→ ${swap.destinationAddress ?? ''}'),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${DriverStrings.swapDetailPickupPrefix} ${swap.pickupAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(swap.pickupAt!) : '—'}',
                                            style: typo.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text(DriverStrings.cancel),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Text(DriverStrings.swapViewDetails),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _claim(swap),
                              child: Text(DriverStrings.swapClaim),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: list.length,
          ),
        );
      },
      loading: () => _RideSwapSkeleton(colors: colors, themeId: themeId),
      error: (_, __) => SliverFillRemaining(
        child: Center(
            child:
                Text(DriverStrings.swapFeedLoadFailed, style: typo.bodyMedium)),
      ),
    );
  }
}

class _RideSwapSkeleton extends StatelessWidget {
  const _RideSwapSkeleton({
    required this.colors,
    required this.themeId,
  });

  final HeyCabyColorTokens colors;
  final String themeId;

  @override
  Widget build(BuildContext context) {
    Widget bar({
      required double width,
      required double height,
    }) {
      return _Bar(colors: colors, width: width, height: height);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, index) => Padding(
          padding: EdgeInsets.fromLTRB(16, index == 0 ? 0 : 4, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(width: 150, height: 20),
                const SizedBox(height: 12),
                bar(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                bar(width: 220, height: 14),
                const SizedBox(height: 10),
                bar(width: 240, height: 12),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: bar(width: double.infinity, height: 40)),
                    const SizedBox(width: 8),
                    Expanded(child: bar(width: double.infinity, height: 40)),
                  ],
                ),
              ],
            ),
          ),
        ),
        childCount: 3,
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.colors,
    required this.width,
    required this.height,
  });

  final HeyCabyColorTokens colors;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
