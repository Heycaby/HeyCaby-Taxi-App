import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../utils/driver_tariff_profile_slots.dart';
import '../widgets/driver_performance_flow_common.dart';
import '../widgets/driver_rate_control_body.dart';
import '../widgets/driver_rate_profile_controls.dart';

class DriverTariffEditorScreen extends ConsumerStatefulWidget {
  const DriverTariffEditorScreen({super.key});

  @override
  ConsumerState<DriverTariffEditorScreen> createState() =>
      _DriverTariffEditorScreenState();
}

class _DriverTariffEditorScreenState
    extends ConsumerState<DriverTariffEditorScreen> {
  final Map<String, TextEditingController> _baseCtrls = {};
  final Map<String, TextEditingController> _kmCtrls = {};
  final Map<String, TextEditingController> _minCtrls = {};
  final Map<String, TextEditingController> _waitCtrls = {};
  bool _saving = false;
  bool _creatingPresets = false;
  String? _selectedProfileId;

  @override
  void dispose() {
    for (final c in _baseCtrls.values) {
      c.dispose();
    }
    for (final c in _kmCtrls.values) {
      c.dispose();
    }
    for (final c in _minCtrls.values) {
      c.dispose();
    }
    for (final c in _waitCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(List<DriverRateProfile> profiles) {
    for (final p in profiles) {
      _baseCtrls.putIfAbsent(
        p.id,
        () => TextEditingController(text: p.baseFare.toStringAsFixed(2)),
      );
      _kmCtrls.putIfAbsent(
        p.id,
        () => TextEditingController(text: p.perKmRate.toStringAsFixed(2)),
      );
      _minCtrls.putIfAbsent(
        p.id,
        () => TextEditingController(text: p.perMinRate.toStringAsFixed(2)),
      );
      _waitCtrls.putIfAbsent(
        p.id,
        () => TextEditingController(text: p.waitingRate.toStringAsFixed(2)),
      );
    }
    final sorted = sortTariffProfiles(profiles);
    if (sorted.isEmpty) {
      _selectedProfileId = null;
      return;
    }
    if (_selectedProfileId == null ||
        !sorted.any((p) => p.id == _selectedProfileId)) {
      _selectedProfileId = sorted.first.id;
    }
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _saveAll() async {
    final id = ref.read(driverIdProvider).valueOrNull;
    if (id == null) return;
    final profiles = ref.read(driverRateProfilesProvider).valueOrNull ?? [];
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    var allOk = true;
    for (final p in profiles) {
      final base = _parse(_baseCtrls[p.id]!);
      final km = _parse(_kmCtrls[p.id]!);
      final min = _parse(_minCtrls[p.id]!);
      final wait = _parse(_waitCtrls[p.id]!);
      if (base == null || km == null || min == null || wait == null) {
        allOk = false;
        break;
      }
      final ok =
          await ref.read(driverDataServiceProvider).updateRateProfileValues(
                driverId: id,
                profileId: p.id,
                baseFare: base,
                perKmRate: km,
                perMinRate: min,
                waitingRate: wait,
              );
      if (!ok) allOk = false;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (allOk) {
      ref.invalidate(driverRateProfilesProvider);
      ref.invalidate(activeRateProfileProvider);
      ref.invalidate(driverProfileProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(DriverStrings.tariffsSaved)),
      );
      navigator.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(DriverStrings.tariffsSaveFailed)),
      );
    }
  }

  Widget _buildBody({
    required DriverColors colors,
    required DriverTypography typography,
    required HeyCabyColorTokens tokenColors,
    required HeyCabyTypography tokenTypo,
    required bool loading,
    required String? errorMessage,
    required List<DriverRateProfile> profiles,
    required String? driverId,
  }) {
    return DriverRateControlBody(
      colors: colors,
      typography: typography,
      tokenColors: tokenColors,
      tokenTypo: tokenTypo,
      loading: loading,
      errorMessage: errorMessage,
      presetBanner: !loading &&
              profiles.isNotEmpty &&
              tariffPresetsIncomplete(profiles) &&
              driverId != null
          ? DriverTariffPresetBanner(
              title: DriverStrings.tariffSuggestionCardTitle,
              body: DriverStrings.tariffSuggestionCardBody,
              buttonLabel: DriverStrings.tariffSuggestionCardButton,
              busyLabel: DriverStrings.creatingDayPartProfiles,
              busy: _creatingPresets,
              colors: colors,
              typography: typography,
              onApply: () async {
                setState(() => _creatingPresets = true);
                await ref
                    .read(driverDataServiceProvider)
                    .ensureTariffPresetProfiles(driverId);
                if (!mounted) return;
                setState(() => _creatingPresets = false);
                ref.invalidate(driverRateProfilesProvider);
              },
            )
          : null,
      profiles: profiles,
      selectedProfileId: _selectedProfileId,
      onProfileSelected: (id) => setState(() => _selectedProfileId = id),
      baseFieldBuilder: (p) => DriverRateEditableField(
        label: DriverStrings.rateStart,
        icon: Icons.flag_rounded,
        prefix: '€',
        controller: _baseCtrls[p.id]!,
        colors: tokenColors,
        typo: tokenTypo,
      ),
      kmFieldBuilder: (p) => DriverRateEditableField(
        label: DriverStrings.ratePerKm,
        icon: Icons.route_rounded,
        prefix: '€',
        controller: _kmCtrls[p.id]!,
        colors: tokenColors,
        typo: tokenTypo,
      ),
      minFieldBuilder: (p) => DriverRateEditableField(
        label: DriverStrings.ratePerMin,
        icon: Icons.schedule_rounded,
        prefix: '€',
        controller: _minCtrls[p.id]!,
        colors: tokenColors,
        typo: tokenTypo,
      ),
      waitFieldBuilder: (p) => DriverRateEditableField(
        label: DriverStrings.rateWaiting,
        icon: Icons.hourglass_top_rounded,
        prefix: '€',
        suffix: '/min',
        controller: _waitCtrls[p.id]!,
        colors: tokenColors,
        typo: tokenTypo,
      ),
      saving: _saving,
      onBack: () => Navigator.of(context).pop(),
      onSave: _saveAll,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final tokenColors = ref.watch(colorsProvider);
    final tokenTypo = ref.watch(typographyProvider);
    final profilesAsync = ref.watch(driverRateProfilesProvider);
    final driverId = ref.watch(driverIdProvider).valueOrNull;

    return profilesAsync.when(
      loading: () => _buildBody(
        colors: colors,
        typography: typography,
        tokenColors: tokenColors,
        tokenTypo: tokenTypo,
        loading: true,
        errorMessage: null,
        profiles: const [],
        driverId: driverId,
      ),
      error: (_, __) => _buildBody(
        colors: colors,
        typography: typography,
        tokenColors: tokenColors,
        tokenTypo: tokenTypo,
        loading: false,
        errorMessage: DriverStrings.tariffsSaveFailed,
        profiles: const [],
        driverId: driverId,
      ),
      data: (profiles) {
        _ensureControllers(profiles);
        return _buildBody(
          colors: colors,
          typography: typography,
          tokenColors: tokenColors,
          tokenTypo: tokenTypo,
          loading: false,
          errorMessage: null,
          profiles: profiles,
          driverId: driverId,
        );
      },
    );
  }
}
