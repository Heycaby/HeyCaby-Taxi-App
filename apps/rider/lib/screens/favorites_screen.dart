import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../providers/favorites_provider.dart';
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
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.myDrivers,
          style: typo.headingLarge.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            favoritesAsync.when(
              data: (drivers) {
                if (drivers.isEmpty) {
                  return Expanded(
                    child: _EmptyState(colors: colors, typo: typo, l10n: l10n),
                  );
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
                        _selectAll = false;
                      } else {
                        _selectedDrivers.add(driver.id);
                        if (_selectedDrivers.length == drivers.length) {
                          _selectAll = true;
                        }
                      }
                    });
                  },
                  onPostRide: () async {
                    final ok = await ensureLocationForBooking(context: context, ref: ref);
                    if (!ok) return;
                    if (context.mounted) context.go('/search');
                  },
                );
              },
              loading: () => Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
              ),
              error: (_, __) => Expanded(
                child: _EmptyState(colors: colors, typo: typo, l10n: l10n),
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
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
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
                return _DriverCard(
                  driver: driver,
                  isSelected: isSelected,
                  colors: colors,
                  typo: typo,
                  l10n: l10n,
                  onTap: () => onDriverTap(driver),
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
      ),
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
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
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
                          color: colors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusText(),
                        style: typo.bodySmall.copyWith(
                          color: colors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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

  String _getStatusText() {
    return '${l10n.rateDriver}: ${driver.rating.toStringAsFixed(1)} · ${driver.totalRides} ${l10n.rides.toLowerCase()}';
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
