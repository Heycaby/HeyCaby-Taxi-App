import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_map/heycaby_map.dart';
import 'package:heycaby_models/heycaby_models.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_location_provider.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../utils/taxi_terug_wizard_contract.dart';

enum TaxiTerugWizardPath { goingHome, goingSomewhere }

enum _WizardStep {
  choosePath,
  homePin,
  dropDistance,
  destination,
  departure,
  pickupRadius,
  discount,
  confirm,
}

/// Step-by-step Taxi Terug activation (icon-first, one idea per step).
Future<bool> showDriverTaxiTerugWizard(
  BuildContext context,
  WidgetRef ref, {
  TaxiTerugWizardPath? initialPath,
  bool skipPathChoice = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DriverTaxiTerugWizardSheet(
      initialPath: initialPath,
      skipPathChoice: skipPathChoice,
    ),
  );
  return result == true;
}

class _DriverTaxiTerugWizardSheet extends ConsumerStatefulWidget {
  const _DriverTaxiTerugWizardSheet({
    this.initialPath,
    this.skipPathChoice = false,
  });

  final TaxiTerugWizardPath? initialPath;
  final bool skipPathChoice;

  @override
  ConsumerState<_DriverTaxiTerugWizardSheet> createState() =>
      _DriverTaxiTerugWizardSheetState();
}

class _DriverTaxiTerugWizardSheetState
    extends ConsumerState<_DriverTaxiTerugWizardSheet> {
  late List<_WizardStep> _steps;
  int _stepIndex = 0;

  TaxiTerugWizardPath? _path;
  String? _homeLabel;
  double? _homeLat;
  double? _homeLng;
  String? _homeZoneId;
  AddressResult? _destination;
  double _dropDistanceKm = 5;
  double _pickupRadiusKm = 10;
  double _discountPct = 10;
  double _departureHoursFromNow = 0;
  bool _isBusy = false;
  bool _loadingHome = false;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<AddressResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _prefillFromProfile();
    _rebuildSteps();
    if (widget.skipPathChoice && _path != null) {
      _stepIndex = 0;
    }
    ref.read(geocodingServiceProvider).startSession();
  }

  double _snapDropDistanceKm(double km) =>
      TaxiTerugWizardContract.snapDropDistanceKm(km);

  void _prefillFromProfile() {
    final profile = ref.read(driverProfileProvider).valueOrNull;
    final status = ref.read(driverReturnModeProvider).valueOrNull;
    _pickupRadiusKm = TaxiTerugWizardContract.clampPickupRadiusKm(
      status?.pickupRadiusKm ?? profile?.pickupDistanceMaxKm ?? 10,
    );
    _dropDistanceKm =
        _snapDropDistanceKm(status?.destinationRadiusKm ?? 5);
    final discount = status?.returnDiscountPct ?? profile?.activeReturnDiscountPct;
    if (discount != null && discount > 0) {
      _discountPct = TaxiTerugWizardContract.clampDiscountPct(discount);
    }
    if (status?.departureTime != null) {
      final mins = status!.departureTime!.difference(DateTime.now()).inMinutes;
      if (mins > 0) {
        _departureHoursFromNow = TaxiTerugWizardContract.clampDepartureHours(
          mins / 60.0,
        );
      }
    }

    final label = profile?.homeCity?.trim().isNotEmpty == true
        ? profile!.homeCity!.trim()
        : status?.destinationLabel?.trim();
    final lat = status?.destinationLat;
    final lng = status?.destinationLng;
    if (label != null && label.isNotEmpty && lat != null && lng != null) {
      _homeLabel = label;
      _homeLat = lat;
      _homeLng = lng;
    }
    _homeZoneId = profile?.headingHomeZoneId ?? status?.destinationZoneId;
    if (status?.enabled == true &&
        status?.destinationLat != null &&
        status?.destinationLng != null) {
      _destination = AddressResult(
        lat: status!.destinationLat!,
        lng: status.destinationLng!,
        fullAddress: status.destinationLabel ?? '',
        displayName: status.destinationLabel ?? '',
      );
      if (status.isPlannedDirection) {
        _path = TaxiTerugWizardPath.goingSomewhere;
      } else {
        _path = TaxiTerugWizardPath.goingHome;
      }
    }
  }

  bool get _hasSavedHome =>
      _homeLabel != null &&
      _homeLabel!.isNotEmpty &&
      _homeLat != null &&
      _homeLng != null;

  void _rebuildSteps() {
    if (_path == null) {
      _steps = [_WizardStep.choosePath];
      return;
    }
    if (_path == TaxiTerugWizardPath.goingHome) {
      _steps = [
        if (!widget.skipPathChoice) _WizardStep.choosePath,
        if (!_hasSavedHome) _WizardStep.homePin,
        _WizardStep.dropDistance,
        _WizardStep.pickupRadius,
        _WizardStep.discount,
        _WizardStep.confirm,
      ];
      if (widget.skipPathChoice) {
        _steps = _steps.where((s) => s != _WizardStep.choosePath).toList();
      }
    } else {
      _steps = [
        if (!widget.skipPathChoice) _WizardStep.choosePath,
        _WizardStep.destination,
        _WizardStep.departure,
        _WizardStep.pickupRadius,
        _WizardStep.discount,
        _WizardStep.confirm,
      ];
      if (widget.skipPathChoice) {
        _steps = _steps.where((s) => s != _WizardStep.choosePath).toList();
      }
    }
    if (_stepIndex >= _steps.length) _stepIndex = _steps.length - 1;
  }

  _WizardStep get _currentStep => _steps[_stepIndex];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _selectPath(TaxiTerugWizardPath path) {
    setState(() {
      _path = path;
      _rebuildSteps();
      _stepIndex = _steps.indexWhere((s) => s != _WizardStep.choosePath);
      if (_stepIndex < 0) _stepIndex = 0;
    });
  }

  void _next() {
    if (_stepIndex < _steps.length - 1) {
      HapticService.selectionClick();
      setState(() => _stepIndex++);
    } else {
      unawaited(_activate());
    }
  }

  void _back() {
    if (_stepIndex > 0) {
      HapticService.selectionClick();
      setState(() => _stepIndex--);
      return;
    }
    Navigator.of(context).pop(false);
  }

  bool _canContinue() {
    switch (_currentStep) {
      case _WizardStep.choosePath:
        return _path != null;
      case _WizardStep.homePin:
        return _hasSavedHome;
      case _WizardStep.dropDistance:
        return true;
      case _WizardStep.destination:
        return _destination != null &&
            _destination!.lat.abs() <= 90 &&
            !(_destination!.lat == 0 && _destination!.lng == 0);
      case _WizardStep.departure:
        return true;
      case _WizardStep.pickupRadius:
        return true;
      case _WizardStep.discount:
        return true;
      case _WizardStep.confirm:
        return true;
    }
  }

  Future<void> _useMyLocationForHome() async {
    setState(() => _loadingHome = true);
    try {
      await ref.read(driverLocationProvider.notifier).refresh();
      final pos = ref.read(driverLocationProvider).valueOrNull;
      if (pos == null) return;
      final reverse = await ref.read(geocodingServiceProvider).reverseGeocode(
            lat: pos.latitude,
            lng: pos.longitude,
          );
      if (!mounted) return;
      if (reverse == null) return;
      final label = reverse.displayName.isNotEmpty
          ? reverse.displayName
          : reverse.fullAddress;
      setState(() {
        _homeLat = pos.latitude;
        _homeLng = pos.longitude;
        _homeLabel = label;
      });
      HapticService.mediumTap();
    } finally {
      if (mounted) setState(() => _loadingHome = false);
    }
  }

  Future<void> _saveHomeIfNeeded() async {
    if (!_hasSavedHome) return;
    final saved = await ref.read(driverDataServiceProvider).saveDriverHomeLocation(
          homeCity: _homeLabel!,
          lat: _homeLat,
          lng: _homeLng,
        );
    if (saved.zoneId != null) {
      _homeZoneId = saved.zoneId;
    }
    if (saved.ok) {
      ref.invalidate(driverProfileProvider);
    }
  }

  DateTime? get _departureTime {
    if (_departureHoursFromNow <= 0) return null;
    final minutes = (_departureHoursFromNow * 60).round();
    return DateTime.now().add(Duration(minutes: minutes));
  }

  Future<void> _activate() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    HapticService.mediumTap();

    final service = ref.read(driverDataServiceProvider);
    DriverReturnModeStatus result;

    if (_path == TaxiTerugWizardPath.goingHome) {
      await _saveHomeIfNeeded();
      result = await service.activateReturnMode(
        destinationLabel: _homeLabel,
        destinationZoneId: _homeZoneId,
        destinationLat: _homeLat,
        destinationLng: _homeLng,
        pickupRadiusKm:
            TaxiTerugWizardContract.clampPickupRadiusKm(_pickupRadiusKm),
        returnDiscountPct:
            TaxiTerugWizardContract.clampDiscountPct(_discountPct),
        intentType: 'home',
        destinationRadiusKm:
            TaxiTerugWizardContract.clampDropDistanceKm(_dropDistanceKm),
      );
    } else {
      final dest = _destination!;
      final zoneId = await service.resolveZoneIdAtPoint(
        lat: dest.lat,
        lng: dest.lng,
      );
      result = await service.activateReturnMode(
        destinationLabel: dest.displayName.isNotEmpty
            ? dest.displayName
            : dest.fullAddress,
        destinationZoneId: zoneId,
        destinationLat: dest.lat,
        destinationLng: dest.lng,
        pickupRadiusKm:
            TaxiTerugWizardContract.clampPickupRadiusKm(_pickupRadiusKm),
        returnDiscountPct:
            TaxiTerugWizardContract.clampDiscountPct(_discountPct),
        intentType: 'planned_direction',
        departureTime: _departureTime,
        destinationRadiusKm:
            TaxiTerugWizardContract.clampDropDistanceKm(_dropDistanceKm),
      );
    }

    ref.invalidate(driverReturnModeProvider);
    ref.invalidate(driverProfileProvider);
    ref.invalidate(driverRateProfilesProvider);
    ref.invalidate(activeRateProfileProvider);
    ref.invalidate(filteredReturnTripsProvider);

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.activationErrorMessage)),
      );
    }
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
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(query));
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

  Future<void> _selectDestination(AddressResult result) async {
    var selected = result;
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

  void _showWhySheet(String title, String body) {
    final colors = DriverColors.fromTheme(ref.read(colorsProvider));
    final typo = DriverTypography.fromTheme(ref.read(typographyProvider));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          DriverSpacing.lg,
          DriverSpacing.sm,
          DriverSpacing.lg,
          DriverSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: typo.titleMedium.copyWith(
                fontWeight: FontWeight.w900,
                color: colors.text,
              ),
            ),
            const SizedBox(height: DriverSpacing.sm),
            Text(
              body,
              style: typo.bodyMedium.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: DriverSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(DriverStrings.taxiTerugWizardGotIt),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typo = DriverTypography.fromTheme(ref.watch(typographyProvider));
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: Icon(Icons.arrow_back_rounded, color: colors.text),
                  ),
                  Expanded(
                    child: _StepDots(
                      count: _steps.length,
                      index: _stepIndex,
                      colors: colors,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DriverSpacing.screenEdge,
                  DriverSpacing.md,
                  DriverSpacing.screenEdge,
                  DriverSpacing.lg,
                ),
                child: _buildStepBody(colors, typo),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                DriverSpacing.screenEdge,
                0,
                DriverSpacing.screenEdge,
                bottom + DriverSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_whyForStep(_currentStep) != null)
                    TextButton.icon(
                      onPressed: () {
                        final why = _whyForStep(_currentStep)!;
                        _showWhySheet(why.$1, why.$2);
                      },
                      icon: Icon(Icons.help_outline_rounded,
                          size: 20, color: colors.textSecondary),
                      label: Text(DriverStrings.taxiTerugWizardWhyAsk),
                    ),
                  if (_currentStep != _WizardStep.choosePath)
                    FilledButton(
                      onPressed:
                          (_canContinue() && !_isBusy) ? _next : null,
                      child: Text(_primaryCtaLabel()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, String)? _whyForStep(_WizardStep step) {
    switch (step) {
      case _WizardStep.homePin:
        return (
          DriverStrings.taxiTerugWizardWhyHomeTitle,
          DriverStrings.taxiTerugWizardWhyHomeBody,
        );
      case _WizardStep.dropDistance:
        return (
          DriverStrings.taxiTerugWizardWhyDropTitle,
          DriverStrings.taxiTerugWizardWhyDropBody,
        );
      case _WizardStep.pickupRadius:
        return (
          DriverStrings.taxiTerugWizardWhyPickupTitle,
          DriverStrings.taxiTerugWizardWhyPickupBody,
        );
      case _WizardStep.discount:
        return (
          DriverStrings.taxiTerugWizardWhyDiscountTitle,
          DriverStrings.taxiTerugWizardWhyDiscountBody,
        );
      case _WizardStep.departure:
        return (
          DriverStrings.taxiTerugWizardWhyWhenTitle,
          DriverStrings.taxiTerugWizardWhyWhenBody,
        );
      default:
        return null;
    }
  }

  String _primaryCtaLabel() {
    if (_isBusy) return DriverStrings.journeyIntentActivating;
    if (_currentStep == _WizardStep.confirm) {
      return _path == TaxiTerugWizardPath.goingSomewhere
          ? DriverStrings.taxiTerugWizardPostTrip
          : DriverStrings.taxiTerugWizardTurnOn;
    }
    return DriverStrings.taxiTerugWizardNext;
  }

  Widget _buildStepBody(DriverColors colors, DriverTypography typo) {
    switch (_currentStep) {
      case _WizardStep.choosePath:
        return _PathStep(colors: colors, typo: typo, onSelect: _selectPath);
      case _WizardStep.homePin:
        return _HomePinStep(
          colors: colors,
          typo: typo,
          label: _homeLabel,
          loading: _loadingHome,
          onUseLocation: _useMyLocationForHome,
        );
      case _WizardStep.dropDistance:
        return _KmChoiceStep(
          colors: colors,
          typo: typo,
          title: DriverStrings.taxiTerugWizardDropTitle,
          subtitle: DriverStrings.taxiTerugWizardDropSubtitle,
          icon: Icons.home_work_outlined,
          valueKm: _dropDistanceKm,
          options: TaxiTerugWizardContract.dropDistanceOptions,
          onChanged: (v) => setState(() => _dropDistanceKm = v),
        );
      case _WizardStep.destination:
        return _DestinationStep(
          colors: colors,
          typo: typo,
          controller: _searchController,
          focusNode: _searchFocus,
          isSearching: _isSearching,
          results: _searchResults,
          hasDestination: _destination != null,
          onSearchChanged: _onSearchChanged,
          onSelect: _selectDestination,
        );
      case _WizardStep.departure:
        return _DepartureStep(
          colors: colors,
          typo: typo,
          hoursFromNow: _departureHoursFromNow,
          onChanged: (v) => setState(() => _departureHoursFromNow = v),
        );
      case _WizardStep.pickupRadius:
        return _PickupRadiusStep(
          colors: colors,
          typo: typo,
          valueKm: _pickupRadiusKm,
          onChanged: (v) => setState(() => _pickupRadiusKm = v),
        );
      case _WizardStep.discount:
        return _DiscountStep(
          colors: colors,
          typo: typo,
          value: _discountPct,
          onChanged: (v) => setState(() => _discountPct = v),
        );
      case _WizardStep.confirm:
        return _ConfirmStep(
          colors: colors,
          typo: typo,
          path: _path!,
          homeLabel: _homeLabel,
          destination: _destination,
          dropKm: _dropDistanceKm,
          pickupKm: _pickupRadiusKm,
          discountPct: _discountPct,
          departureHoursFromNow: _departureHoursFromNow,
        );
    }
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.count,
    required this.index,
    required this.colors,
  });

  final int count;
  final int index;
  final DriverColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return Container(
          width: active ? 10 : 7,
          height: active ? 10 : 7,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? colors.primary : colors.border,
          ),
        );
      }),
    );
  }
}

class _WizardHero extends StatelessWidget {
  const _WizardHero({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.typo,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final DriverColors colors;
  final DriverTypography typo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, size: 36, color: colors.primary),
        ),
        const SizedBox(height: DriverSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: typo.titleLarge.copyWith(
            fontWeight: FontWeight.w900,
            color: colors.text,
          ),
        ),
        const SizedBox(height: DriverSpacing.sm),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: typo.bodyMedium.copyWith(
            color: colors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _PathStep extends StatelessWidget {
  const _PathStep({
    required this.colors,
    required this.typo,
    required this.onSelect,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final ValueChanged<TaxiTerugWizardPath> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WizardHero(
          icon: Icons.alt_route_rounded,
          title: DriverStrings.taxiTerugWizardPathTitle,
          subtitle: DriverStrings.taxiTerugWizardPathSubtitle,
          colors: colors,
          typo: typo,
        ),
        const SizedBox(height: DriverSpacing.xl),
        _PathCard(
          colors: colors,
          typo: typo,
          icon: Icons.home_rounded,
          label: DriverStrings.taxiTerugWizardGoingHome,
          hint: DriverStrings.taxiTerugWizardGoingHomeHint,
          onTap: () => onSelect(TaxiTerugWizardPath.goingHome),
        ),
        const SizedBox(height: DriverSpacing.md),
        _PathCard(
          colors: colors,
          typo: typo,
          icon: Icons.explore_rounded,
          label: DriverStrings.taxiTerugWizardGoingSomewhere,
          hint: DriverStrings.taxiTerugWizardGoingSomewhereHint,
          onTap: () => onSelect(TaxiTerugWizardPath.goingSomewhere),
        ),
      ],
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(DriverRadius.lg),
      child: InkWell(
        onTap: () {
          HapticService.mediumTap();
          onTap();
        },
        borderRadius: BorderRadius.circular(DriverRadius.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(DriverSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DriverRadius.lg),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 30, color: colors.primary),
              ),
              const SizedBox(width: DriverSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: typo.titleSmall.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      style: typo.bodySmall.copyWith(
                        color: colors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePinStep extends StatelessWidget {
  const _HomePinStep({
    required this.colors,
    required this.typo,
    required this.label,
    required this.loading,
    required this.onUseLocation,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final String? label;
  final bool loading;
  final VoidCallback onUseLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WizardHero(
          icon: Icons.home_rounded,
          title: DriverStrings.taxiTerugWizardHomeTitle,
          subtitle: DriverStrings.taxiTerugWizardHomeSubtitle,
          colors: colors,
          typo: typo,
        ),
        const SizedBox(height: DriverSpacing.xl),
        if (label != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DriverSpacing.lg),
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(DriverRadius.md),
              border: Border.all(color: colors.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: colors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label!,
                    style: typo.titleSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DriverSpacing.md),
        ],
        FilledButton.icon(
          onPressed: loading ? null : onUseLocation,
          icon: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onPrimary,
                  ),
                )
              : const Icon(Icons.gps_fixed_rounded),
          label: Text(DriverStrings.taxiTerugWizardUseMyLocation),
        ),
      ],
    );
  }
}

class _KmChoiceStep extends StatelessWidget {
  const _KmChoiceStep({
    required this.colors,
    required this.typo,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.valueKm,
    required this.options,
    required this.onChanged,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final String title;
  final String subtitle;
  final IconData icon;
  final double valueKm;
  final List<int> options;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WizardHero(
          icon: icon,
          title: title,
          subtitle: subtitle,
          colors: colors,
          typo: typo,
        ),
        const SizedBox(height: DriverSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            const columns = 3;
            const spacing = DriverSpacing.sm;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: options.map((km) {
                final selected = valueKm.round() == km;
                return SizedBox(
                  width: tileWidth,
                  child: _KmTile(
                    colors: colors,
                    typo: typo,
                    km: km,
                    selected: selected,
                    onTap: () {
                      HapticService.selectionClick();
                      onChanged(km.toDouble());
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _KmTile extends StatelessWidget {
  const _KmTile({
    required this.colors,
    required this.typo,
    required this.km,
    required this.selected,
    required this.onTap,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final int km;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.primary : colors.surface,
      borderRadius: BorderRadius.circular(DriverRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DriverRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DriverRadius.md),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.radio_button_unchecked_rounded,
                size: 28,
                color: selected ? colors.onPrimary : colors.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                '$km',
                style: typo.headlineSmall.copyWith(
                  fontWeight: FontWeight.w900,
                  color: selected ? colors.onPrimary : colors.text,
                ),
              ),
              Text(
                'km',
                style: typo.labelSmall.copyWith(
                  color: selected
                      ? colors.onPrimary.withValues(alpha: 0.85)
                      : colors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickupRadiusStep extends StatelessWidget {
  const _PickupRadiusStep({
    required this.colors,
    required this.typo,
    required this.valueKm,
    required this.onChanged,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final double valueKm;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WizardHero(
          icon: Icons.my_location_rounded,
          title: DriverStrings.taxiTerugWizardPickupTitle,
          subtitle: DriverStrings.taxiTerugWizardPickupSubtitle,
          colors: colors,
          typo: typo,
        ),
        const SizedBox(height: DriverSpacing.xl),
        _HapticValueSlider(
          colors: colors,
          typo: typo,
          value: valueKm,
          min: TaxiTerugWizardContract.minPickupRadiusKm,
          max: TaxiTerugWizardContract.maxPickupRadiusKm,
          divisions: (TaxiTerugWizardContract.maxPickupRadiusKm -
                  TaxiTerugWizardContract.minPickupRadiusKm)
              .round(),
          valueText: DriverStrings.taxiTerugWizardPickupKmLabel(valueKm.round()),
          minLabel: DriverStrings.taxiTerugWizardPickupKmLabel(
            TaxiTerugWizardContract.minPickupRadiusKm.round(),
          ),
          maxLabel: DriverStrings.taxiTerugWizardPickupKmLabel(
            TaxiTerugWizardContract.maxPickupRadiusKm.round(),
          ),
          helperText: DriverStrings.taxiTerugWizardPickupRadiusHint,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DiscountStep extends StatelessWidget {
  const _DiscountStep({
    required this.colors,
    required this.typo,
    required this.value,
    required this.onChanged,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WizardHero(
          icon: Icons.percent_rounded,
          title: DriverStrings.taxiTerugWizardDiscountTitle,
          subtitle: DriverStrings.taxiTerugWizardDiscountSubtitle,
          colors: colors,
          typo: typo,
        ),
        const SizedBox(height: DriverSpacing.xl),
        _HapticValueSlider(
          colors: colors,
          typo: typo,
          value: value,
          min: 0,
          max: TaxiTerugWizardContract.maxDiscountPct,
          divisions: 50,
          valueText: DriverStrings.taxiTerugWizardDiscountValue(value.round()),
          minLabel: '0%',
          maxLabel: '${TaxiTerugWizardContract.maxDiscountPct.toStringAsFixed(0)}%',
          helperText: DriverStrings.taxiTerugWizardDiscountFastPickup,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DepartureStep extends StatelessWidget {
  const _DepartureStep({
    required this.colors,
    required this.typo,
    required this.hoursFromNow,
    required this.onChanged,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final double hoursFromNow;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final leavesAt = hoursFromNow > 0 ? _departureTime : null;
    final leavesAtLabel = leavesAt == null
        ? null
        : DriverStrings.taxiTerugWizardLeavesAt(
            DriverStrings.taxiTerugWizardClockTime(leavesAt),
          );

    return Column(
      children: [
        _WizardHero(
          icon: Icons.schedule_rounded,
          title: DriverStrings.taxiTerugWizardWhenTitle,
          subtitle: DriverStrings.taxiTerugWizardWhenSubtitle,
          colors: colors,
          typo: typo,
        ),
        const SizedBox(height: DriverSpacing.xl),
        _HapticValueSlider(
          colors: colors,
          typo: typo,
          value: hoursFromNow,
          min: 0,
          max: TaxiTerugWizardContract.maxDepartureHours,
          divisions: 20,
          valueText:
              DriverStrings.taxiTerugWizardDepartureHoursLabel(hoursFromNow),
          minLabel: DriverStrings.journeyIntentDepartureNow,
          maxLabel: DriverStrings.taxiTerugWizardDepartureMaxHours(
            TaxiTerugWizardContract.maxDepartureHours.toInt(),
          ),
          helperText: leavesAtLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }

  DateTime get _departureTime {
    final minutes = (hoursFromNow * 60).round();
    return DateTime.now().add(Duration(minutes: minutes));
  }
}

/// Slider with light haptic tick on each step change.
class _HapticValueSlider extends StatefulWidget {
  const _HapticValueSlider({
    required this.colors,
    required this.typo,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueText,
    required this.minLabel,
    required this.maxLabel,
    required this.onChanged,
    this.helperText,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueText;
  final String minLabel;
  final String maxLabel;
  final ValueChanged<double> onChanged;
  final String? helperText;

  @override
  State<_HapticValueSlider> createState() => _HapticValueSliderState();
}

class _HapticValueSliderState extends State<_HapticValueSlider> {
  double? _lastHapticStep;

  double _quantize(double raw) {
    if (widget.divisions <= 0) return raw.clamp(widget.min, widget.max);
    final step = (widget.max - widget.min) / widget.divisions;
    final steps = ((raw - widget.min) / step).round();
    return (widget.min + steps * step).clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    final clamped = widget.value.clamp(widget.min, widget.max);
    return Column(
      children: [
        Text(
          widget.valueText,
          textAlign: TextAlign.center,
          style: widget.typo.headlineSmall.copyWith(
            fontWeight: FontWeight.w900,
            color: widget.colors.primary,
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: DriverSpacing.xs),
          Text(
            widget.helperText!,
            textAlign: TextAlign.center,
            style: widget.typo.bodySmall.copyWith(
              color: widget.colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: DriverSpacing.md),
        Slider(
          value: clamped,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          activeColor: widget.colors.primary,
          onChanged: (raw) {
            final stepped = _quantize(raw);
            if (_lastHapticStep == null || stepped != _lastHapticStep) {
              HapticService.selectionClick();
              _lastHapticStep = stepped;
            }
            widget.onChanged(stepped);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DriverSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.minLabel,
                style: widget.typo.labelSmall.copyWith(
                  color: widget.colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.maxLabel,
                style: widget.typo.labelSmall.copyWith(
                  color: widget.colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DestinationStep extends StatelessWidget {
  const _DestinationStep({
    required this.colors,
    required this.typo,
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.results,
    required this.hasDestination,
    required this.onSearchChanged,
    required this.onSelect,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final List<AddressResult> results;
  final bool hasDestination;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AddressResult> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WizardHero(
          icon: Icons.location_city_rounded,
          title: DriverStrings.taxiTerugWizardDestTitle,
          subtitle: DriverStrings.taxiTerugWizardDestSubtitle,
          colors: colors,
          typo: typo,
        ),
        const SizedBox(height: DriverSpacing.lg),
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: DriverStrings.journeyIntentDestinationHint,
            prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary),
            suffixIcon: isSearching
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DriverRadius.md),
            ),
          ),
        ),
        if (results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: DriverSpacing.sm),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(DriverRadius.md),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: colors.border),
              itemBuilder: (context, i) {
                final r = results[i];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.place_rounded, color: colors.primary),
                  title: Text(
                    r.displayName.isNotEmpty ? r.displayName : r.fullAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelect(r),
                );
              },
            ),
          ),
        if (hasDestination && results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DriverSpacing.md),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: colors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DriverStrings.journeyIntentDestinationSet,
                    style: typo.bodySmall.copyWith(
                      color: colors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.colors,
    required this.typo,
    required this.path,
    this.homeLabel,
    this.destination,
    required this.dropKm,
    required this.pickupKm,
    required this.discountPct,
    required this.departureHoursFromNow,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final TaxiTerugWizardPath path;
  final String? homeLabel;
  final AddressResult? destination;
  final double dropKm;
  final double pickupKm;
  final double discountPct;
  final double departureHoursFromNow;

  @override
  Widget build(BuildContext context) {
    final destLabel = path == TaxiTerugWizardPath.goingHome
        ? (homeLabel ?? '—')
        : (destination?.displayName.isNotEmpty == true
            ? destination!.displayName
            : destination?.fullAddress ?? '—');

    return Column(
      children: [
        _WizardHero(
          icon: Icons.checklist_rounded,
          title: DriverStrings.taxiTerugWizardConfirmTitle,
          subtitle: DriverStrings.taxiTerugWizardConfirmSubtitle,
          colors: colors,
          typo: typo,
        ),
        const SizedBox(height: DriverSpacing.xl),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(DriverSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(DriverRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              _ConfirmRow(
                colors: colors,
                typo: typo,
                icon: path == TaxiTerugWizardPath.goingHome
                    ? Icons.home_rounded
                    : Icons.explore_rounded,
                label: destLabel,
              ),
              if (path == TaxiTerugWizardPath.goingSomewhere) ...[
                const SizedBox(height: DriverSpacing.md),
                _ConfirmRow(
                  colors: colors,
                  typo: typo,
                  icon: Icons.schedule_rounded,
                  label: DriverStrings.taxiTerugWizardDepartureHoursLabel(
                    departureHoursFromNow,
                  ),
                ),
                const SizedBox(height: DriverSpacing.md),
                _ConfirmRow(
                  colors: colors,
                  typo: typo,
                  icon: Icons.my_location_rounded,
                  label: '${pickupKm.toStringAsFixed(0)} km',
                ),
              ],
              if (path == TaxiTerugWizardPath.goingHome) ...[
                const SizedBox(height: DriverSpacing.md),
                _ConfirmRow(
                  colors: colors,
                  typo: typo,
                  icon: Icons.home_work_outlined,
                  label:
                      '${dropKm.toStringAsFixed(0)} km ${DriverStrings.taxiTerugWizardDropShort}',
                ),
                const SizedBox(height: DriverSpacing.md),
                _ConfirmRow(
                  colors: colors,
                  typo: typo,
                  icon: Icons.my_location_rounded,
                  label: DriverStrings.taxiTerugWizardPickupKmLabel(
                    pickupKm.round(),
                  ),
                ),
              ],
              const SizedBox(height: DriverSpacing.md),
              _ConfirmRow(
                colors: colors,
                typo: typo,
                icon: Icons.percent_rounded,
                label: '${discountPct.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.colors,
    required this.typo,
    required this.icon,
    required this.label,
  });

  final DriverColors colors;
  final DriverTypography typo;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: colors.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: typo.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.text,
            ),
          ),
        ),
      ],
    );
  }
}
