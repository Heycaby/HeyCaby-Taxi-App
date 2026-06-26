import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
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

  String _tariffName(String profileName) {
    final lower = profileName.toLowerCase();
    if (lower.contains(DriverStrings.tariffSuffix)) return profileName;
    return '$profileName ${DriverStrings.tariffSuffix}';
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
  }

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  bool _hasDayPartProfile(
    List<DriverRateProfile> profiles,
    _DayPartSlot slot,
  ) {
    final tokens = slot.matchTokens;
    for (final p in profiles) {
      final n = p.profileName.toLowerCase();
      for (final t in tokens) {
        if (n.contains(t)) return true;
      }
    }
    return false;
  }

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
      final ok = await ref.read(driverDataServiceProvider).updateRateProfileValues(
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
        const SnackBar(content: Text(DriverStrings.tariffsSaved)),
      );
      navigator.pop();
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text(DriverStrings.tariffsSaveFailed)),
      );
    }
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
      loading: () => DriverRateControlBody(
        colors: colors,
        typography: typography,
        loading: true,
        errorMessage: null,
        presetBanner: null,
        profileEditors: const [],
        saving: _saving,
        onBack: () => Navigator.of(context).pop(),
        onSave: _saveAll,
      ),
      error: (_, __) => DriverRateControlBody(
        colors: colors,
        typography: typography,
        loading: false,
        errorMessage: DriverStrings.tariffsSaveFailed,
        presetBanner: null,
        profileEditors: const [],
        saving: _saving,
        onBack: () => Navigator.of(context).pop(),
        onSave: _saveAll,
      ),
      data: (profiles) {
        _ensureControllers(profiles);
        final hasMissingPresets = !_hasDayPartProfile(profiles, _DayPartSlot.morning) ||
            !_hasDayPartProfile(profiles, _DayPartSlot.evening) ||
            !_hasDayPartProfile(profiles, _DayPartSlot.lateNight);

        return DriverRateControlBody(
          colors: colors,
          typography: typography,
          loading: false,
          errorMessage: null,
          presetBanner: hasMissingPresets && driverId != null
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
          profileEditors: profiles
              .map(
                (p) => DriverTariffProfileEditorCard(
                  title: _tariffName(p.profileName),
                  colors: colors,
                  typography: typography,
                  baseField: DriverRateEditableField(
                    label: DriverStrings.rateStart,
                    prefix: '€',
                    controller: _baseCtrls[p.id]!,
                    colors: tokenColors,
                    typo: tokenTypo,
                  ),
                  kmField: DriverRateEditableField(
                    label: DriverStrings.ratePerKm,
                    prefix: '€',
                    controller: _kmCtrls[p.id]!,
                    colors: tokenColors,
                    typo: tokenTypo,
                  ),
                  minField: DriverRateEditableField(
                    label: DriverStrings.ratePerMin,
                    prefix: '€',
                    controller: _minCtrls[p.id]!,
                    colors: tokenColors,
                    typo: tokenTypo,
                  ),
                  waitField: DriverRateEditableField(
                    label: DriverStrings.rateWaiting,
                    prefix: '€',
                    suffix: '/min',
                    controller: _waitCtrls[p.id]!,
                    colors: tokenColors,
                    typo: tokenTypo,
                  ),
                ),
              )
              .toList(),
          saving: _saving,
          onBack: () => Navigator.of(context).pop(),
          onSave: _saveAll,
        );
      },
    );
  }
}

enum _DayPartSlot {
  morning,
  evening,
  lateNight,
}

extension on _DayPartSlot {
  List<String> get matchTokens {
    switch (this) {
      case _DayPartSlot.morning:
        return const ['morning', 'ochtend'];
      case _DayPartSlot.evening:
        return const ['evening', 'avond'];
      case _DayPartSlot.lateNight:
        return const ['late night', 'latenight', 'nacht'];
    }
  }
}
