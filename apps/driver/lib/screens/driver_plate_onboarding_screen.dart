import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../models/driver_start_shift_args.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_runtime_providers.dart';
import '../screens/driver_start_shift_screen.dart';
import '../utils/driver_go_online_onboarding.dart';
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
          context.go('/driver');
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

  Future<void> _openStartShiftScreen(DriverStartShiftArgs args) async {
    setState(() => _saving = false);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DriverStartShiftScreen(args: args),
      ),
    );
  }

  Future<void> _claim({bool confirmShiftStart = false}) async {
    final raw = _plateCtrl.text.trim();
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.length < 4) return;
    if (_status != _PlateStatus.taxi || _rdwRow == null) return;

    setState(() => _saving = true);
    final row = _rdwRow!;
    final verification =
        row.isTaxiVehicle ? 'rdw_verified_taxi' : 'rdw_verified_not_taxi';
    final resumeGoOnline = driverGoOnlineResumeRequested(GoRouterState.of(context));

    final res = await ref.read(driverDataServiceProvider).claimVehiclePlateV2(
          vehiclePlate: cleaned,
          vehiclePlateEntered: raw,
          rdwSnapshot: _rdwSnapshot(row),
          vehicleVerificationStatus: verification,
          confirmShiftStart: confirmShiftStart,
        );

    if (!mounted) return;

    if (res?['success'] == true) {
      ref.invalidate(driverProfileProvider);
      ref.invalidate(driverComplianceProvider);
      await continueDriverGoOnlineOnboarding(
        context: context,
        ref: ref,
        resumeGoOnline: resumeGoOnline,
      );
      return;
    }

    final shiftArgs = DriverStartShiftArgs.fromShiftStartPrompt(
      response: res,
      vehiclePlate: cleaned,
      vehiclePlateEntered: raw,
      rdwSnapshot: _rdwSnapshot(row),
      vehicleVerificationStatus: verification,
      resumeGoOnline: resumeGoOnline,
    );
    if (shiftArgs != null && !confirmShiftStart) {
      await _openStartShiftScreen(shiftArgs);
      return;
    }

    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_errorMessage(res?['error']))),
    );
  }

  String _errorMessage(Object? err) {
    final text = err?.toString() ?? '';
    if (text.isEmpty) return DriverStrings.supportChatSendFailed;
    if (text.contains('vehicle_verification_status') ||
        text.contains('invalid_verification_status')) {
      return DriverStrings.onboardingPlateSaveFailed;
    }
    if (text.contains('driver_not_found')) {
      return DriverStrings.supportChatSendFailed;
    }
    return text.length > 180 ? DriverStrings.onboardingPlateSaveFailed : text;
  }

  void _handleBack() {
    if (_saving) return;
    if (context.canPop()) {
      context.pop(false);
      return;
    }
    context.go('/driver');
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
    final resumeGoOnline = driverGoOnlineResumeRequested(GoRouterState.of(context));

    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _saving) return;
        _handleBack();
      },
      child: DriverVehicleProfileBody(
        colors: colors,
        typography: typography,
        flowTitle: resumeGoOnline
            ? DriverStrings.goOnlineTitle
            : DriverStrings.onboardingPlateFlowTitle,
        headerTitle: DriverStrings.onboardingPlateTitle,
        headerSubtitle: resumeGoOnline
            ? DriverStrings.goOnlinePlateSubtitle
            : DriverStrings.onboardingPlateSubtitle,
        saveLabel: resumeGoOnline
            ? DriverStrings.onboardingPlateContinueGoOnline
            : DriverStrings.onboardingPlateContinue,
        plateLocked: false,
        displayPlate: '',
        plateController: _plateCtrl,
        status: _mapStatus(_status),
        saving: _saving,
        canSave: _status == _PlateStatus.taxi && _rdwRow != null,
        rdwMake: _rdwRow?.merk,
        rdwModel: _rdwRow?.handelsbenaming,
        rdwApk: _rdwRow?.vervaldatumApk,
        onBack: _handleBack,
        onLookupPlate: _checkPlate,
        onSave: () => _claim(),
      ),
    );
  }
}
