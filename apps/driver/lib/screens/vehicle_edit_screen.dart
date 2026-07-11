import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_vehicle_profile_body.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart' show kVehiclePlateDuplicateCode;
import '../services/rdw_open_data_service.dart';

enum _PlateStatus { idle, checking, taxi, notTaxi, notFound }

/// Single kenteken field + RDW lookup; saves via `save_vehicle_info` RPC.
class VehicleEditScreen extends ConsumerStatefulWidget {
  const VehicleEditScreen({super.key});

  @override
  ConsumerState<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends ConsumerState<VehicleEditScreen> {
  final _plateCtrl = TextEditingController();
  final _rdw = RdwOpenDataService();
  _PlateStatus _status = _PlateStatus.idle;
  RdwVehicleRow? _rdwRow;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(driverProfileProvider).valueOrNull;
      if (profile?.vehiclePlate != null) {
        _plateCtrl.text = profile!.vehiclePlate!;
      }
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

  Future<void> _save() async {
    final profile = ref.read(driverProfileProvider).valueOrNull;
    final compliance = ref.read(driverComplianceProvider).valueOrNull;
    final locked = (profile?.vehiclePlate ?? '').trim().isNotEmpty ||
        (compliance?.vehiclePlate ?? '').trim().isNotEmpty;
    if (locked) return;

    final raw = _plateCtrl.text.trim();
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.length < 4) return;
    if (_status != _PlateStatus.taxi || _rdwRow == null) return;

    setState(() => _saving = true);
    final r = _rdwRow!;
    final verification =
        r.isTaxiVehicle ? 'rdw_verified_taxi' : 'rdw_verified_not_taxi';

    final res = await ref.read(driverDataServiceProvider).saveVehicleInfo(
          vehiclePlate: cleaned,
          vehiclePlateEntered: raw,
          rdwVoertuigsoort: r.voertuigsoort,
          rdwMerk: r.merk,
          rdwHandelsbenaming: r.handelsbenaming,
          rdwEersteKleur: r.eersteKleur,
          rdwDatumEersteToelating: r.datumEersteToelating,
          rdwAantalZitplaatsen: r.aantalZitplaatsen,
          rdwInrichting: r.inrichting,
          rdwWamVerzekerd: r.wamVerzekerd,
          rdwApkVervaldatum: r.vervaldatumApk,
          vehicleVerificationStatus: verification,
        );

    if (!mounted) return;
    setState(() => _saving = false);
    if (res?['success'] == true) {
      ref.invalidate(driverProfileProvider);
      ref.invalidate(driverComplianceProvider);
      if (mounted) context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_vehicleSaveErrorMessage(res?['error'])),
        ),
      );
    }
  }

  String _vehicleSaveErrorMessage(Object? err) {
    if (err == null || err.toString().isEmpty) return 'Opslaan mislukt';
    if (err.toString() == kVehiclePlateDuplicateCode) {
      return DriverStrings.vehiclePlateDuplicate;
    }
    final s = err.toString();
    if (s.contains('drivers_vehicle_plate_unique') ||
        s.contains('vehicle_plate_unique') ||
        (s.contains('23505') && s.contains('duplicate'))) {
      return DriverStrings.vehiclePlateDuplicate;
    }
    return s;
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
    final profile = ref.watch(driverProfileProvider).valueOrNull;
    final compliance = ref.watch(driverComplianceProvider).valueOrNull;
    final plateProfile = (profile?.vehiclePlate ?? '').trim();
    final plateCompliance = (compliance?.vehiclePlate ?? '').trim();
    final plateLocked = plateProfile.isNotEmpty || plateCompliance.isNotEmpty;
    final displayPlate =
        plateCompliance.isNotEmpty ? plateCompliance : plateProfile;

    return DriverVehicleProfileBody(
      colors: colors,
      typography: typography,
      plateLocked: plateLocked,
      displayPlate: displayPlate,
      plateController: _plateCtrl,
      status: _mapStatus(_status),
      saving: _saving,
      canSave: _status == _PlateStatus.taxi && _rdwRow != null,
      rdwMake: _rdwRow?.merk ?? compliance?.rdwMerk,
      rdwModel: _rdwRow?.handelsbenaming ?? compliance?.rdwHandelsbenaming,
      rdwApk: _rdwRow?.vervaldatumApk ?? compliance?.rdwApkVervaldatum,
      onBack: _saving ? () {} : () => context.pop(),
      onLookupPlate: _checkPlate,
      onSave: _save,
    );
  }
}
