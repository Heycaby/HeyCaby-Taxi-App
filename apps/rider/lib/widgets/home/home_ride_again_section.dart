import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../providers/booking_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../screens/location_required_screen.dart';
import '../../services/booking_pickup_from_location.dart';
import '../email_modal.dart';

/// Surfaces the rider's top trusted driver for one-tap rebooking.
class HomeRideAgainSection extends ConsumerWidget {
  const HomeRideAgainSection({
    super.key,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  Future<void> _bookAgain(
    BuildContext context,
    WidgetRef ref,
    FavoriteDriver driver,
  ) async {
    final ok = await ensureLocationForBooking(context: context, ref: ref);
    if (!ok) return;
    ref.read(bookingProvider.notifier)
      ..setInstant()
      ..setPreferredDriver(driver.driverId);
    await fillPickupFromCurrentLocation(ref);
    if (context.mounted) context.go('/search');
  }

  Future<void> _openAll(BuildContext context, WidgetRef ref) async {
    final identity = await ref.read(riderIdentityProvider.future);
    if (!context.mounted) return;
    if (identity.hasSession && identity.email != null) {
      context.push('/favorites');
      return;
    }
    final success = await showEmailModal(context, ref);
    if (success && context.mounted) context.push('/favorites');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return favorites.when(
      data: (drivers) {
        if (drivers.isEmpty) return const SizedBox.shrink();
        final driver = drivers.first;
        final ratingLabel = driver.rating.toStringAsFixed(2);

        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 22, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.homeRideAgainTitle,
                      style: typo.titleMedium.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openAll(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.homeRideAgainViewAll,
                      style: typo.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Material(
                color: colors.card,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: () => _bookAgain(context, ref, driver),
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border),
                    ),
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
                    child: Row(
                      children: [
                        _DriverAvatar(
                          colors: colors,
                          name: driver.name,
                          photoUrl: driver.photo,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver.name,
                                style: typo.titleMedium.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: colors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.homeRideAgainUsuallyAvailable,
                                    style: typo.bodySmall.copyWith(
                                      color: colors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.homeRideAgainDriverStats(
                                  ratingLabel,
                                  driver.totalRides,
                                ),
                                style: typo.bodySmall.copyWith(
                                  color: colors.textMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _bookAgain(context, ref, driver),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.accent,
                            side: BorderSide(color: colors.accent),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.homeRideAgainBookAgain,
                                style: typo.labelLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({
    required this.colors,
    required this.name,
    this.photoUrl,
  });

  final HeyCabyColorTokens colors;
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 26,
      backgroundColor: colors.bgAlt,
      backgroundImage:
          photoUrl != null && photoUrl!.isNotEmpty ? NetworkImage(photoUrl!) : null,
      child: photoUrl == null || photoUrl!.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            )
          : null,
    );
  }
}
