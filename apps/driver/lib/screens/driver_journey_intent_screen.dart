import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_location_provider.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_trip_planning_flow_common.dart';

enum _IntentType { home, airport, city, custom }

enum _DepartureOption { now, in30, in60, custom }

class DriverJourneyIntentScreen extends ConsumerStatefulWidget {
  const DriverJourneyIntentScreen({super.key});

  @override
  ConsumerState<DriverJourneyIntentScreen> createState() =>
      _DriverJourneyIntentScreenState();
}

class _DriverJourneyIntentScreenState
    extends ConsumerState<DriverJourneyIntentScreen> {
  _IntentType _intentType = _IntentType.home;
  _DepartureOption _departureOption = _DepartureOption.now;
  AddressResult? _destination;
  double _pickupRadiusKm = 10;
  double _destinationRadiusKm = 5;
  double _discountPct = 15;
  DateTime? _customDepartureTime;
  bool _isActivating = false;
  bool _isSearching = false;
  List<AddressResult> _searchResults = [];
  Timer? _debounce;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    ref.read(geocodingServiceProvider).startSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFromExistingStatus();
    });
  }

  void _initFromExistingStatus() {
    final status = ref.read(driverReturnModeProvider).valueOrNull;
    if (status == null) return;
    if (status.destinationLabel != null) {
      _searchController.text = status.destinationLabel!;
    }
    _pickupRadiusKm = status.pickupRadiusKm;
    _destinationRadiusKm = status.destinationRadiusKm;
    _discountPct = status.returnDiscountPct > 0 ? status.returnDiscountPct : 15;
    if (status.destinationLat != null && status.destinationLng != null) {
      _destination = AddressResult(
        lat: status.destinationLat!,
        lng: status.destinationLng!,
        fullAddress: status.destinationLabel ?? '',
        displayName: status.destinationLabel ?? '',
      );
    }
    if (status.hasDepartureTime) {
      _customDepartureTime = status.departureTime;
      _departureOption = _DepartureOption.custom;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _doSearch(query));
  }

  Future<void> _doSearch(String query) async {
    try {
      final pos = ref.read(driverLocationProvider).valueOrNull;
      final results = await ref.read(geocodingServiceProvider).search(
            query: query,
            proximityLat: pos?.latitude,
            proximityLng: pos?.longitude,
          );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectAddress(AddressResult result) async {
    AddressResult selected = result;
    if (selected.lat == 0.0 && (selected.mapboxId?.isNotEmpty ?? false)) {
      final resolved =
          await ref.read(geocodingServiceProvider).retrieve(selected.mapboxId!);
      if (resolved != null) selected = resolved;
    }
    setState(() {
      _destination = selected;
      _searchController.text = selected.displayName.isNotEmpty
          ? selected.displayName
          : selected.fullAddress;
      _searchResults = [];
    });
    _searchFocus.unfocus();
  }

  DateTime? get _resolvedDepartureTime {
    switch (_departureOption) {
      case _DepartureOption.now:
        return null;
      case _DepartureOption.in30:
        return DateTime.now().add(const Duration(minutes: 30));
      case _DepartureOption.in60:
        return DateTime.now().add(const Duration(minutes: 60));
      case _DepartureOption.custom:
        return _customDepartureTime;
    }
  }

  String get _intentTypeString {
    switch (_intentType) {
      case _IntentType.home:
        return 'home';
      case _IntentType.airport:
        return 'airport';
      case _IntentType.city:
        return 'city';
      case _IntentType.custom:
        return 'custom';
    }
  }

  Future<void> _activate() async {
    if (_destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.journeyIntentPickDestination)),
      );
      return;
    }
    setState(() => _isActivating = true);
    HapticService.mediumTap();

    final result = await ref.read(driverDataServiceProvider).activateReturnMode(
          destinationLabel: _destination!.displayName.isNotEmpty
              ? _destination!.displayName
              : _destination!.fullAddress,
          destinationLat: _destination!.lat,
          destinationLng: _destination!.lng,
          pickupRadiusKm: _pickupRadiusKm,
          returnDiscountPct: _discountPct,
          intentType: _intentTypeString,
          departureTime: _resolvedDepartureTime,
          destinationRadiusKm: _destinationRadiusKm,
        );

    if (!mounted) return;
    setState(() => _isActivating = false);

    ref.invalidate(driverReturnModeProvider);
    ref.invalidate(driverProfileProvider);
    ref.invalidate(driverRateProfilesProvider);
    ref.invalidate(activeRateProfileProvider);
    ref.invalidate(filteredReturnTripsProvider);

    if (result.ok) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.activationErrorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverTripPlanningFlowScaffold(
      title: DriverStrings.journeyIntentTitle,
      subtitle: DriverStrings.journeyIntentSubtitle,
      colors: colors,
      typography: typography,
      onBack: () => context.pop(),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            DriverSpacing.screenEdge,
            DriverSpacing.lg,
            DriverSpacing.screenEdge,
            MediaQuery.paddingOf(context).bottom + DriverSpacing.xl,
          ),
          children: [
            _IntentTypeSection(
              colors: colors,
              typography: typography,
              selected: _intentType,
              onChanged: (v) => setState(() => _intentType = v),
            ),
            const SizedBox(height: DriverSpacing.lg),
            _DestinationSection(
              colors: colors,
              typography: typography,
              controller: _searchController,
              focusNode: _searchFocus,
              isSearching: _isSearching,
              searchResults: _searchResults,
              hasDestination: _destination != null,
              onSearchChanged: _onSearchChanged,
              onSelect: _selectAddress,
            ),
            const SizedBox(height: DriverSpacing.lg),
            _DepartureTimeSection(
              colors: colors,
              typography: typography,
              selected: _departureOption,
              customTime: _customDepartureTime,
              onChanged: (v) => setState(() => _departureOption = v),
              onPickCustom: () => _pickCustomTime(),
            ),
            const SizedBox(height: DriverSpacing.lg),
            _RadiusSection(
              colors: colors,
              typography: typography,
              pickupRadiusKm: _pickupRadiusKm,
              destinationRadiusKm: _destinationRadiusKm,
              onPickupChanged: (v) => setState(() => _pickupRadiusKm = v),
              onDestinationChanged: (v) =>
                  setState(() => _destinationRadiusKm = v),
            ),
            const SizedBox(height: DriverSpacing.lg),
            _DiscountSection(
              colors: colors,
              typography: typography,
              discountPct: _discountPct,
              onChanged: (v) => setState(() => _discountPct = v),
            ),
            const SizedBox(height: DriverSpacing.xl),
            FilledButton(
              onPressed: _isActivating ? null : _activate,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DriverRadius.md),
                ),
              ),
              child: Text(
                _isActivating
                    ? DriverStrings.journeyIntentActivating
                    : DriverStrings.journeyIntentActivate,
                style: typography.titleMedium
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomTime() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(minutes: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(hours: 12)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 30))),
    );
    if (time == null || !mounted) return;
    setState(() {
      _customDepartureTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
      _departureOption = _DepartureOption.custom;
    });
  }
}

// ─── Intent type section ───────────────────────────────────────────────────

class _IntentTypeSection extends StatelessWidget {
  const _IntentTypeSection({
    required this.colors,
    required this.typography,
    required this.selected,
    required this.onChanged,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final _IntentType selected;
  final ValueChanged<_IntentType> onChanged;

  @override
  Widget build(BuildContext context) {
    return DriverTripPlanningSectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.journeyIntentTypeLabel,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            DriverStrings.journeyIntentTypeBody,
            style: typography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          Wrap(
            spacing: DriverSpacing.sm,
            runSpacing: DriverSpacing.sm,
            children: [
              _IntentChip(
                colors: colors,
                typography: typography,
                label: DriverStrings.journeyIntentTypeHome,
                icon: Icons.home_rounded,
                selected: selected == _IntentType.home,
                onTap: () => onChanged(_IntentType.home),
              ),
              _IntentChip(
                colors: colors,
                typography: typography,
                label: DriverStrings.journeyIntentTypeAirport,
                icon: Icons.flight_takeoff_rounded,
                selected: selected == _IntentType.airport,
                onTap: () => onChanged(_IntentType.airport),
              ),
              _IntentChip(
                colors: colors,
                typography: typography,
                label: DriverStrings.journeyIntentTypeCity,
                icon: Icons.location_city_rounded,
                selected: selected == _IntentType.city,
                onTap: () => onChanged(_IntentType.city),
              ),
              _IntentChip(
                colors: colors,
                typography: typography,
                label: DriverStrings.journeyIntentTypeCustom,
                icon: Icons.edit_location_alt_rounded,
                selected: selected == _IntentType.custom,
                onTap: () => onChanged(_IntentType.custom),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntentChip extends StatelessWidget {
  const _IntentChip({
    required this.colors,
    required this.typography,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DriverRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.card,
          borderRadius: BorderRadius.circular(DriverRadius.pill),
          border: Border.all(
            color: selected
                ? colors.primary
                : colors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? colors.onPrimary : colors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: typography.labelMedium.copyWith(
                color: selected ? colors.onPrimary : colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Destination section ───────────────────────────────────────────────────

class _DestinationSection extends StatelessWidget {
  const _DestinationSection({
    required this.colors,
    required this.typography,
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.searchResults,
    required this.hasDestination,
    required this.onSearchChanged,
    required this.onSelect,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final List<AddressResult> searchResults;
  final bool hasDestination;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AddressResult> onSelect;

  @override
  Widget build(BuildContext context) {
    return DriverTripPlanningSectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.journeyIntentDestinationLabel,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearchChanged,
            style: typography.bodyMedium.copyWith(color: colors.text),
            decoration: InputDecoration(
              hintText: DriverStrings.journeyIntentDestinationHint,
              hintStyle:
                  typography.bodyMedium.copyWith(color: colors.textMuted),
              prefixIcon:
                  Icon(Icons.search_rounded, color: colors.textSecondary),
              suffixIcon: isSearching
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: colors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DriverRadius.sm),
                borderSide: BorderSide(
                  color: colors.border.withValues(alpha: 0.5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DriverRadius.sm),
                borderSide: BorderSide(
                  color: colors.border.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DriverRadius.sm),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
          if (searchResults.isNotEmpty) ...[
            const SizedBox(height: DriverSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(DriverRadius.sm),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.4),
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: searchResults.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: colors.border.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) {
                  final r = searchResults[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.location_on_rounded,
                      size: 20,
                      color: colors.primary,
                    ),
                    title: Text(
                      r.displayName.isNotEmpty ? r.displayName : r.fullAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodySmall.copyWith(color: colors.text),
                    ),
                    onTap: () => onSelect(r),
                  );
                },
              ),
            ),
          ],
          if (hasDestination && searchResults.isEmpty) ...[
            const SizedBox(height: DriverSpacing.sm),
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 18, color: colors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DriverStrings.journeyIntentDestinationSet,
                    style: typography.bodySmall.copyWith(
                      color: colors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Departure time section ────────────────────────────────────────────────

class _DepartureTimeSection extends StatelessWidget {
  const _DepartureTimeSection({
    required this.colors,
    required this.typography,
    required this.selected,
    required this.customTime,
    required this.onChanged,
    required this.onPickCustom,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final _DepartureOption selected;
  final DateTime? customTime;
  final ValueChanged<_DepartureOption> onChanged;
  final VoidCallback onPickCustom;

  @override
  Widget build(BuildContext context) {
    return DriverTripPlanningSectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.journeyIntentDepartureLabel,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            DriverStrings.journeyIntentDepartureBody,
            style: typography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          Wrap(
            spacing: DriverSpacing.sm,
            runSpacing: DriverSpacing.sm,
            children: [
              _DepartureChip(
                colors: colors,
                typography: typography,
                label: DriverStrings.journeyIntentDepartureNow,
                selected: selected == _DepartureOption.now,
                onTap: () => onChanged(_DepartureOption.now),
              ),
              _DepartureChip(
                colors: colors,
                typography: typography,
                label: DriverStrings.journeyIntentDepartureIn30,
                selected: selected == _DepartureOption.in30,
                onTap: () => onChanged(_DepartureOption.in30),
              ),
              _DepartureChip(
                colors: colors,
                typography: typography,
                label: DriverStrings.journeyIntentDepartureIn60,
                selected: selected == _DepartureOption.in60,
                onTap: () => onChanged(_DepartureOption.in60),
              ),
              _DepartureChip(
                colors: colors,
                typography: typography,
                label: customTime != null
                    ? _formatTime(customTime!)
                    : DriverStrings.journeyIntentDepartureCustom,
                selected: selected == _DepartureOption.custom,
                onTap: onPickCustom,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _DepartureChip extends StatelessWidget {
  const _DepartureChip({
    required this.colors,
    required this.typography,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DriverRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.card,
          borderRadius: BorderRadius.circular(DriverRadius.pill),
          border: Border.all(
            color: selected
                ? colors.primary
                : colors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: typography.labelMedium.copyWith(
            color: selected ? colors.onPrimary : colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Radius section ────────────────────────────────────────────────────────

class _RadiusSection extends StatelessWidget {
  const _RadiusSection({
    required this.colors,
    required this.typography,
    required this.pickupRadiusKm,
    required this.destinationRadiusKm,
    required this.onPickupChanged,
    required this.onDestinationChanged,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final double pickupRadiusKm;
  final double destinationRadiusKm;
  final ValueChanged<double> onPickupChanged;
  final ValueChanged<double> onDestinationChanged;

  @override
  Widget build(BuildContext context) {
    return DriverTripPlanningSectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.journeyIntentRadiusLabel,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          Row(
            children: [
              Icon(Icons.my_location_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DriverStrings.journeyIntentPickupRadius,
                  style: typography.bodySmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${pickupRadiusKm.toStringAsFixed(0)} km',
                style: typography.titleSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: pickupRadiusKm,
            min: 1,
            max: 50,
            divisions: 49,
            activeColor: colors.primary,
            onChanged: onPickupChanged,
          ),
          const SizedBox(height: DriverSpacing.sm),
          Row(
            children: [
              Icon(Icons.location_on_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DriverStrings.journeyIntentDestinationRadius,
                  style: typography.bodySmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${destinationRadiusKm.toStringAsFixed(0)} km',
                style: typography.titleSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: destinationRadiusKm,
            min: 1,
            max: 50,
            divisions: 49,
            activeColor: colors.primary,
            onChanged: onDestinationChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Discount section ──────────────────────────────────────────────────────

class _DiscountSection extends StatelessWidget {
  const _DiscountSection({
    required this.colors,
    required this.typography,
    required this.discountPct,
    required this.onChanged,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final double discountPct;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return DriverTripPlanningSectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.journeyIntentDiscountLabel,
            style: typography.titleSmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DriverSpacing.sm),
          Text(
            DriverStrings.journeyIntentDiscountBody,
            style: typography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
          Row(
            children: [
              Text(
                '0%',
                style: typography.labelSmall.copyWith(color: colors.textMuted),
              ),
              Expanded(
                child: Slider(
                  value: discountPct,
                  min: 0,
                  max: 40,
                  divisions: 8,
                  activeColor: colors.primary,
                  onChanged: onChanged,
                ),
              ),
              Text(
                '40%',
                style: typography.labelSmall.copyWith(color: colors.textMuted),
              ),
              const SizedBox(width: DriverSpacing.sm),
              SizedBox(
                width: 56,
                child: Text(
                  '${discountPct.toStringAsFixed(0)}%',
                  textAlign: TextAlign.center,
                  style: typography.titleMedium.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
