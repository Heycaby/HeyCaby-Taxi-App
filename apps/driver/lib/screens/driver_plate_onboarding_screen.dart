import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_runtime_providers.dart';
import '../utils/driver_entry_navigation.dart';
import '../utils/driver_runtime_refresh.dart';
import '../services/rdw_open_data_service.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_vehicle_profile_body.dart';

enum _PlateStatus { idle, checking, taxi, notTaxi, notFound }

/// Plate-first onboarding (V2): RDW lookup + vehicle session claim.
class DriverPlateOnboardingScreen extends ConsumerStatefulWidget {
  const DriverPlateOnboardingScreen({super.key});

  @override
  ConsumerState<DriverPlateOnboardingScreen> createState() =>
      _DriverPlateOnboardingScreenState();
}

class _DriverPlateOnboardingScreenState
    extends ConsumerState<DriverPlateOnboardingScreen> {
  final _plateCtrl = TextEditingController();
  final _rdw = RdwOpenDataService();
  _PlateStatus _status = _PlateStatus.idle;
  RdwVehicleRow? _rdwRow;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (HeyCabySupabase.client.auth.currentSession == null) {
        context.go('/login');
        return;
      }
      try {
        final runtime = await ref.read(driverRuntimeSnapshotProvider.future);
        if (!mounted) return;
        if (runtime.plateVerified) {
          context.go(resolveDriverEntryRoute(runtime));
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkPlate() async {
    final raw = _plateCtrl.text.trim();
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.length < 4) {
      setState(() {
        _status = _PlateStatus.idle;
        _rdwRow = null;
      });
      return;
    }
    setState(() {
      _status = _PlateStatus.checking;
      _rdwRow = null;
    });
    final row = await _rdw.lookupByPlate(cleaned);
    if (!mounted) return;
    if (row == null) {
      setState(() => _status = _PlateStatus.notFound);
      return;
    }
    setState(() {
      _rdwRow = row;
      _status = row.isTaxiVehicle ? _PlateStatus.taxi : _PlateStatus.notTaxi;
    });
  }

  Map<String, dynamic> _rdwSnapshot(RdwVehicleRow row) {
    return {
      'merk': row.merk,
      'handelsbenaming': row.handelsbenaming,
      'eerste_kleur': row.eersteKleur,
      'voertuigsoort': row.voertuigsoort,
      'inrichting': row.inrichting,
      'aantal_zitplaatsen': row.aantalZitplaatsen,
      'vervaldatum_apk': row.vervaldatumApk,
      'wam_verzekerd': row.wamVerzekerd,
      'datum_eerste_toelating': row.datumEersteToelating,
    };
  }

  Future<bool> _confirmSharedFleet() async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          DriverStrings.onboardingSharedFleetTitle,
          style: typo.titleMedium.copyWith(color: colors.text),
        ),
        content: Text(
          DriverStrings.onboardingSharedFleetBody,
          style: typo.bodyMedium.copyWith(color: colors.textMid, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(DriverStrings.cancel, style: TextStyle(color: colors.textMid)),
          ),
          FilledButton(
            onPressed: () {
              HapticService.mediumTap();
              Navigator.of(ctx).pop(true);
            },
            child: Text(DriverStrings.onboardingSharedFleetConfirm),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<void> _claim({bool sharedFleetAck = false}) async {
    final raw = _plateCtrl.text.trim();
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.length < 4) return;
    if (_status != _PlateStatus.taxi || _rdwRow == null) return;

    setState(() => _saving = true);
    final row = _rdwRow!;
    final verification =
        row.isTaxiVehicle ? 'rdw_verified_taxi' : 'rdw_verified_not_taxi';

    final res = await ref.read(driverDataServiceProvider).claimVehiclePlateV2(
          vehiclePlate: cleaned,
          vehiclePlateEntered: raw,
          rdwSnapshot: _rdwSnapshot(row),
          vehicleVerificationStatus: verification,
          sharedFleetAck: sharedFleetAck,
        );

    if (!mounted) return;

    if (res?['success'] == true) {
      ref.invalidate(driverProfileProvider);
      ref.invalidate(driverComplianceProvider);
      final runtime = await refreshDriverRuntime(ref);
      if (!mounted) return;
      context.go(resolveDriverEntryRoute(runtime));
      return;
    }

    final sharedPrompt = res?['shared_prompt'] == true;
    if (sharedPrompt && !sharedFleetAck) {
      setState(() => _saving = false);
      final confirmed = await _confirmSharedFleet();
      if (confirmed && mounted) {
        await _claim(sharedFleetAck: true);
      }
      return;
    }

    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_errorMessage(res?['error']))),
    );
  }

  String _errorMessage(Object? err) {
    if (err == null || err.toString().isEmpty) {
      return DriverStrings.supportChatSendFailed;
    }
    return err.toString();
  }

  DriverVehiclePlateStatus _mapStatus(_PlateStatus status) {
    switch (status) {
      case _PlateStatus.idle:
        return DriverVehiclePlateStatus.idle;
      case _PlateStatus.checking:
        return DriverVehiclePlateStatus.checking;
      case _PlateStatus.taxi:
        return DriverVehiclePlateStatus.taxi;
      case _PlateStatus.notTaxi:
        return DriverVehiclePlateStatus.notTaxi;
      case _PlateStatus.notFound:
        return DriverVehiclePlateStatus.notFound;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return DriverVehicleProfileBody(
      colors: colors,
      typography: typography,
      flowTitle: DriverStrings.onboardingPlateFlowTitle,
      headerTitle: DriverStrings.onboardingPlateTitle,
      headerSubtitle: DriverStrings.onboardingPlateSubtitle,
      saveLabel: DriverStrings.onboardingPlateContinue,
      plateLocked: false,
      displayPlate: '',
      plateController: _plateCtrl,
      status: _mapStatus(_status),
      saving: _saving,
      canSave: _status == _PlateStatus.taxi && _rdwRow != null,
      rdwMake: _rdwRow?.merk,
      rdwModel: _rdwRow?.handelsbenaming,
      rdwApk: _rdwRow?.vervaldatumApk,
      onBack: _saving ? () {} : () => context.go('/splash'),
      onLookupPlate: _checkPlate,
      onSave: () => _claim(),
    );
  }
}
