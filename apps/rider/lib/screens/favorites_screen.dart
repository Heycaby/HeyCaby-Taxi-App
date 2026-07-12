import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../widgets/booking/booking_flow_screen_header.dart';
import '../providers/booking_provider.dart';
import '../providers/favorites_provider.dart';
import '../services/booking_pickup_from_location.dart';
import 'location_required_screen.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final Set<String> _selectedDrivers = {};
  bool _selectAll = false;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final l10n = AppLocalizations.of(context);

    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.myDrivers,
              subtitle: l10n.favoritesSaveTrustedDriversBody,
              icon: Icons.star_rounded,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: favoritesAsync.when(
                data: (drivers) {
                  if (drivers.isEmpty) {
                    return _EmptyState(colors: colors, typo: typo, l10n: l10n);
                  }
                  return _FavoritesList(
                    drivers: drivers,
                    selectedDrivers: _selectedDrivers,
                    selectAll: _selectAll,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                    onSelectAllChanged: (v) {
                      setState(() {
                        _selectAll = v;
                        if (v) {
                          _selectedDrivers.addAll(drivers.map((d) => d.id));
                        } else {
                          _selectedDrivers.clear();
                        }
                      });
                    },
                    onDriverTap: (driver) {
                      setState(() {
                        if (_selectedDrivers.contains(driver.id)) {
                          _selectedDrivers.remove(driver.id);
                        } else {
                          // The backend supports one exact driver or the rider's
                          // complete favorite network. Do not imply that an
                          // arbitrary partial group can be targeted.
                          _selectedDrivers.clear();
                          _selectedDrivers.add(driver.id);
                        }
                        _selectAll = false;
                      });
                    },
                    onPostRide: () async {
                      final ok = await ensureLocationForBooking(
                          context: context, ref: ref);
                      if (!ok) return;
                      final bookingNotifier =
                          ref.read(bookingProvider.notifier);
                      bookingNotifier.setInstant();
                      if (_selectedDrivers.length == 1) {
                        final favId = _selectedDrivers.first;
                        final driver =
                            drivers.where((d) => d.id == favId).firstOrNull;
                        if (driver != null) {
                          bookingNotifier.setPreferredDriver(driver.driverId);
                        }
                      } else {
                        bookingNotifier.setMarketplaceDriverAudience(
                          MarketplaceDriverAudience.myDriversOnly,
                        );
                      }
                      await fillPickupFromCurrentLocation(ref);
                      if (context.mounted) context.go('/search');
                    },
                    onRemoveDriver: (driver) async {
                      final removed = await ref
                          .read(favoritesProvider.notifier)
                          .removeFavorite(driver.driverId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              removed
                                  ? l10n.driverRemoved
                                  : l10n.favoritesRemoveFailed,
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        if (removed) {
                          setState(() {
                            _selectedDrivers.remove(driver.id);
                            _selectAll = false;
                          });
                        }
                      }
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
                error: (_, __) => _FavoritesErrorState(
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                  onRetry: () => ref.read(favoritesProvider.notifier).refresh(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesList extends StatelessWidget {
  final List<FavoriteDriver> drivers;
  final Set<String> selectedDrivers;
  final bool selectAll;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final ValueChanged<bool> onSelectAllChanged;
  final ValueChanged<FavoriteDriver> onDriverTap;
  final VoidCallback onPostRide;
  final ValueChanged<FavoriteDriver> onRemoveDriver;

  const _FavoritesList({
    required this.drivers,
    required this.selectedDrivers,
    required this.selectAll,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onSelectAllChanged,
    required this.onDriverTap,
    required this.onPostRide,
    required this.onRemoveDriver,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SelectAllBar(
          selectAll: selectAll,
          selectedCount: selectedDrivers.length,
          totalCount: drivers.length,
          colors: colors,
          typo: typo,
          l10n: l10n,
          onChanged: onSelectAllChanged,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              final isSelected = selectedDrivers.contains(driver.id);
              return Dismissible(
                key: ValueKey(driver.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsetsDirectional.only(end: 20),
                  margin: const EdgeInsetsDirectional.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.error,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.delete_rounded, color: colors.onAccent),
                ),
                confirmDismiss: (_) async {
                  onRemoveDriver(driver);
                  return false;
                },
                child: _DriverCard(
                  driver: driver,
                  isSelected: isSelected,
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                  onTap: () => onDriverTap(driver),
                ),
              );
            },
          ),
        ),
        if (selectedDrivers.isNotEmpty)
          _PostRideButton(
            selectedCount: selectedDrivers.length,
            colors: colors,
            typo: typo,
            l10n: l10n,
            onTap: onPostRide,
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  const _EmptyState({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsetsDirectional.all(24),
              decoration: BoxDecoration(
                color: colors.accentL,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_outline,
                size: 56,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noFavouritesYet,
              style: typo.headingMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.favoritesSaveTrustedDriversBody,
              style: typo.bodyMedium.copyWith(color: colors.textMid),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesErrorState extends StatelessWidget {
  const _FavoritesErrorState({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onRetry,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: colors.textMid, size: 42),
            const SizedBox(height: 16),
            Text(
              l10n.favoritesLoadFailed,
              textAlign: TextAlign.center,
              style: typo.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectAllBar extends StatelessWidget {
  final bool selectAll;
  final int selectedCount;
  final int totalCount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final ValueChanged<bool> onChanged;

  const _SelectAllBar({
    required this.selectAll,
    required this.selectedCount,
    required this.totalCount,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selectAll,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: colors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.favoritesSelectAllDrivers,
              style: typo.bodyLarge.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selectedCount > 0)
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$selectedCount/$totalCount',
                style: typo.labelLarge.copyWith(
                  color: colors.bg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final FavoriteDriver driver;
  final bool isSelected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _DriverCard({
    required this.driver,
    required this.isSelected,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: 12),
        padding: const EdgeInsetsDirectional.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentL : colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                image: driver.photo != null
                    ? DecorationImage(
                        image: NetworkImage(driver.photo!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: driver.photo == null
                  ? Icon(Icons.person, color: colors.success, size: 24)
                  : null,
            ),
            const SizedBox(width: 14),
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
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: driver.isAvailable
                              ? colors.success
                              : colors.textSoft,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        driver.isAvailable
                            ? l10n.driverAvailableNow
                            : l10n.driverOffline,
                        style: typo.bodySmall.copyWith(
                          color: driver.isAvailable
                              ? colors.success
                              : colors.textSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '·',
                        style: typo.bodySmall.copyWith(
                          color: colors.textSoft,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${driver.rating.toStringAsFixed(1)} ★ · ${driver.totalRides} ${l10n.rides.toLowerCase()}',
                        style: typo.bodySmall.copyWith(
                          color: colors.textMid,
                        ),
                      ),
                    ],
                  ),
                  if (driver.vehicleDescription.isNotEmpty ||
                      (driver.vehiclePlate ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.directions_car_rounded,
                            size: 14, color: colors.textSoft),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              driver.vehicleDescription,
                              driver.vehiclePlate,
                            ]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' · '),
                            style: typo.bodySmall.copyWith(
                              color: colors.textSoft,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: colors.accent, size: 24)
            else
              Icon(Icons.circle_outlined, color: colors.border, size: 24),
          ],
        ),
      ),
    );
  }
}

class _PostRideButton extends StatelessWidget {
  final int selectedCount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _PostRideButton({
    required this.selectedCount,
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.send, color: colors.onAccent, size: 20),
              const SizedBox(width: 10),
              Text(
                l10n.favoritesPostRideTo(selectedCount),
                style: typo.labelLarge.copyWith(
                  color: colors.onAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
