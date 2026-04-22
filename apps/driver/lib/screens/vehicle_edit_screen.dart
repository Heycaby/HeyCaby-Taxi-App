import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final profile = ref.watch(driverProfileProvider).valueOrNull;
    final compliance = ref.watch(driverComplianceProvider).valueOrNull;
    final plateProfile = (profile?.vehiclePlate ?? '').trim();
    final plateCompliance = (compliance?.vehiclePlate ?? '').trim();
    final plateLocked =
        plateProfile.isNotEmpty || plateCompliance.isNotEmpty;
    final displayPlate =
        plateCompliance.isNotEmpty ? plateCompliance : plateProfile;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.text),
          onPressed: _saving ? null : () => context.pop(),
        ),
        title: Text(
          DriverStrings.vehicle,
          style: typo.headingLarge.copyWith(color: colors.text),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              DriverStrings.vehicleRdwTitle,
              style: typo.titleMedium.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              plateLocked
                  ? DriverStrings.vehiclePlateLockedSubtitle
                  : DriverStrings.vehicleRdwSubtitle,
              style: typo.bodySmall.copyWith(color: colors.textSoft, height: 1.4),
            ),
            const SizedBox(height: 20),
            if (plateLocked) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: colors.text.withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      'NL',
                      style: typo.labelLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.border),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        displayPlate,
                        style: typo.titleMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                DriverStrings.fieldLockedContactSupport,
                style: typo.bodySmall.copyWith(
                  color: colors.textSoft,
                  height: 1.35,
                ),
              ),
              if (compliance != null &&
                  ((compliance.rdwMerk ?? '').isNotEmpty ||
                      (compliance.rdwHandelsbenaming ?? '').isNotEmpty ||
                      (compliance.rdwApkVervaldatum ?? '').isNotEmpty)) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DriverStrings.vehicleVerifiedTaxi,
                        style: typo.labelLarge.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _row(
                        typo,
                        colors,
                        'Merk',
                        compliance.rdwMerk ?? '—',
                      ),
                      _row(
                        typo,
                        colors,
                        'Model',
                        compliance.rdwHandelsbenaming ?? '—',
                      ),
                      _row(
                        typo,
                        colors,
                        'APK',
                        compliance.rdwApkVervaldatum ?? '—',
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.text.withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      'NL',
                      style: typo.labelLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _plateCtrl,
                      maxLength: 9,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() {
                        _status = _PlateStatus.idle;
                        _rdwRow = null;
                      }),
                      onEditingComplete: _checkPlate,
                      onSubmitted: (_) => _checkPlate(),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'XX-000-X',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _checkPlate,
                  icon: _status == _PlateStatus.checking
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.accent,
                          ),
                        )
                      : Icon(Icons.search_rounded, color: colors.accent),
                  label: Text(
                    DriverStrings.lookupPlate,
                    style: typo.labelLarge.copyWith(color: colors.accent),
                  ),
                ),
              ),
              if (_status == _PlateStatus.notFound) ...[
                const SizedBox(height: 8),
                Text(
                  DriverStrings.plateNotFoundRdw,
                  style: typo.bodySmall.copyWith(color: colors.error),
                ),
              ],
              if (_status == _PlateStatus.notTaxi) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    DriverStrings.vehicleNotTaxiRdw,
                    style: typo.bodySmall.copyWith(color: colors.text, height: 1.4),
                  ),
                ),
              ],
              if (_status == _PlateStatus.taxi && _rdwRow != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.success.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DriverStrings.vehicleVerifiedTaxi,
                        style: typo.labelLarge.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _row(typo, colors, 'Merk', _rdwRow!.merk ?? '—'),
                      _row(typo, colors, 'Model', _rdwRow!.handelsbenaming ?? '—'),
                      _row(typo, colors, 'Kleur', _rdwRow!.eersteKleur ?? '—'),
                      _row(typo, colors, 'Zitplaatsen', _rdwRow!.aantalZitplaatsen ?? '—'),
                      _row(typo, colors, 'APK', _rdwRow!.vervaldatumApk ?? '—'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  child: _saving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onAccent,
                          ),
                        )
                      : Text(
                          DriverStrings.saveAndContinue,
                          style: typo.labelLarge.copyWith(fontWeight: FontWeight.w800),
                        ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(HeyCabyTypography typo, HeyCabyColorTokens colors, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              k,
              style: typo.bodySmall.copyWith(color: colors.textSoft),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: typo.bodyMedium.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}
