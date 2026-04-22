import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../services/driver_data_service.dart';
import '../utils/chauffeurspas_validation.dart';
import '../utils/driver_compliance_ui.dart';
import '../widgets/driver_compliance_doc_row.dart';
import '../widgets/premium_settings_cards.dart';

/// Compliance hub — Wpv 2000 documents; chauffeurspas via RPC (no ILT live verify).
class DriverDocumentsScreen extends ConsumerStatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  ConsumerState<DriverDocumentsScreen> createState() =>
      _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends ConsumerState<DriverDocumentsScreen> {
  final _chauffeurspasCtrl = TextEditingController();
  final _chauffeurspasExpiryCtrl = TextEditingController();
  final _kvkNumberCtrl = TextEditingController();
  final _kvkNameCtrl = TextEditingController();
  final _kvkAddressCtrl = TextEditingController();
  final _insuranceProviderCtrl = TextEditingController();
  final _insurancePolicyCtrl = TextEditingController();
  final _insuranceExpiryCtrl = TextEditingController();

  bool _savingPas = false;
  bool _savingKvk = false;
  bool _savingInsurance = false;
  /// Set after a successful gallery upload; cleared after insurance RPC save.
  String? _pendingInsurancePhotoUrl;
  String? _message;
  bool? _messageOk;

  @override
  void dispose() {
    _chauffeurspasCtrl.dispose();
    _chauffeurspasExpiryCtrl.dispose();
    _kvkNumberCtrl.dispose();
    _kvkNameCtrl.dispose();
    _kvkAddressCtrl.dispose();
    _insuranceProviderCtrl.dispose();
    _insurancePolicyCtrl.dispose();
    _insuranceExpiryCtrl.dispose();
    super.dispose();
  }

  bool _chauffeurPasLocked(DriverComplianceSnapshot? s) {
    if (s == null) return false;
    if (s.chauffeurspasVerified == true) return true;
    return (s.chauffeurspasNumber ?? '').trim().isNotEmpty;
  }

  bool _kvkLocked(DriverComplianceSnapshot? s) {
    if (s == null) return false;
    return (s.kvkNumber ?? '').trim().isNotEmpty;
  }

  bool _insuranceLocked(DriverComplianceSnapshot? s) {
    if (s == null) return false;
    final photo = (s.taxiInsurancePhotoUrl ?? '').isNotEmpty;
    final p = (s.taxiInsuranceProvider ?? '').trim().isNotEmpty;
    final n = (s.taxiInsurancePolicyNumber ?? '').trim().isNotEmpty;
    final exp = s.taxiInsuranceExpiry != null;
    return photo && p && n && exp;
  }

  /// Non-empty Veriff name / ID expiry line for the licence card.
  String _veriffMetaLine(DriverComplianceSnapshot? s) {
    final parts = <String>[];
    final n = (s?.veriffFullName ?? '').trim();
    if (n.isNotEmpty) parts.add(n);
    final exp = s?.veriffIdExpiry;
    if (exp != null) {
      parts.add(exp.toIso8601String().split('T').first);
    }
    return parts.join(' · ');
  }

  Future<bool> _confirmPermanentDocSave(
    BuildContext context, {
    required bool insurance,
  }) async {
    final colors = ref.read(colorsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(DriverStrings.docSavePermanentTitle),
        content: Text(
          insurance
              ? DriverStrings.docSaveInsuranceBody
              : DriverStrings.docSavePermanentBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(DriverStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(DriverStrings.docSaveConfirm),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _syncFromSnapshot(DriverComplianceSnapshot? snap) {
    if (snap == null) return;
    if (_chauffeurspasCtrl.text.isEmpty &&
        (snap.chauffeurspasNumber ?? '').isNotEmpty) {
      _chauffeurspasCtrl.text = snap.chauffeurspasNumber!;
    }
    if (_chauffeurspasExpiryCtrl.text.isEmpty &&
        snap.chauffeurspasExpiry != null) {
      _chauffeurspasExpiryCtrl.text =
          snap.chauffeurspasExpiry!.toIso8601String().split('T').first;
    }
    if (_kvkNumberCtrl.text.isEmpty && (snap.kvkNumber ?? '').isNotEmpty) {
      _kvkNumberCtrl.text = snap.kvkNumber!;
    }
    if (_kvkNameCtrl.text.isEmpty && (snap.kvkBusinessName ?? '').isNotEmpty) {
      _kvkNameCtrl.text = snap.kvkBusinessName!;
    }
    if (_kvkAddressCtrl.text.isEmpty && (snap.kvkAddress ?? '').isNotEmpty) {
      _kvkAddressCtrl.text = snap.kvkAddress!;
    }
    if (_insuranceProviderCtrl.text.isEmpty &&
        (snap.taxiInsuranceProvider ?? '').isNotEmpty) {
      _insuranceProviderCtrl.text = snap.taxiInsuranceProvider!;
    }
    if (_insurancePolicyCtrl.text.isEmpty &&
        (snap.taxiInsurancePolicyNumber ?? '').isNotEmpty) {
      _insurancePolicyCtrl.text = snap.taxiInsurancePolicyNumber!;
    }
    if (_insuranceExpiryCtrl.text.isEmpty &&
        snap.taxiInsuranceExpiry != null) {
      _insuranceExpiryCtrl.text =
          snap.taxiInsuranceExpiry!.toIso8601String().split('T').first;
    }
  }

  Future<void> _saveChauffeurspas() async {
    final snap = ref.read(driverComplianceProvider).valueOrNull;
    if (_chauffeurPasLocked(snap)) return;
    if (await ref.read(driverIdProvider.future) == null) return;
    if (!mounted) return;
    if (!await _confirmPermanentDocSave(context, insurance: false)) return;
    final v = validateChauffeurspasNumber(_chauffeurspasCtrl.text);
    if (!v.valid) {
      setState(() {
        _message = v.error;
        _messageOk = false;
      });
      return;
    }
    setState(() {
      _savingPas = true;
      _message = null;
    });
    final expiry = _chauffeurspasExpiryCtrl.text.trim();
    final res = await ref.read(driverDataServiceProvider).saveDriverDocument(
          documentType: 'chauffeurspas',
          chauffeurspasNumber: v.cleaned,
          chauffeurspasExpiry: expiry.isEmpty ? null : expiry,
        );
    if (!mounted) return;
    setState(() => _savingPas = false);
    if (res?['success'] == true) {
      setState(() {
        _message = DriverStrings.chauffeurspasSaved;
        _messageOk = true;
      });
      ref.invalidate(driverComplianceProvider);
      ref.invalidate(driverProfileProvider);
    } else {
      setState(() {
        _message = res?['error']?.toString() ?? DriverStrings.chauffeurspasVerifyFailed;
        _messageOk = false;
      });
    }
  }

  Future<void> _saveKvk() async {
    final snap = ref.read(driverComplianceProvider).valueOrNull;
    if (_kvkLocked(snap)) return;
    if (await ref.read(driverIdProvider.future) == null) return;
    if (!mounted) return;
    if (!await _confirmPermanentDocSave(context, insurance: false)) return;
    final n = _kvkNumberCtrl.text.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(n)) {
      setState(() {
        _message = 'KvK nummer: 8 cijfers';
        _messageOk = false;
      });
      return;
    }
    setState(() => _savingKvk = true);
    final res = await ref.read(driverDataServiceProvider).saveDriverDocument(
          documentType: 'kvk',
          kvkNumber: n,
          kvkBusinessName: _kvkNameCtrl.text.trim(),
          kvkAddress: _kvkAddressCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _savingKvk = false);
    if (res?['success'] == true) {
      setState(() {
        _message = DriverStrings.chauffeurspasSaved;
        _messageOk = true;
      });
      ref.invalidate(driverComplianceProvider);
    } else {
      setState(() {
        _message = res?['error']?.toString() ?? 'Opslaan mislukt';
        _messageOk = false;
      });
    }
  }

  Future<void> _pickInsurancePhoto() async {
    final snap = ref.read(driverComplianceProvider).valueOrNull;
    if (_insuranceLocked(snap)) return;
    final id = await ref.read(driverIdProvider.future);
    if (id == null) return;
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final mime = x.mimeType ?? 'image/jpeg';
    final ext = mime.contains('png') ? 'png' : 'jpg';
    setState(() {
      _savingInsurance = true;
      _message = null;
    });
    final url = await ref.read(driverDataServiceProvider).uploadDriverInsurancePhoto(
          driverId: id,
          bytes: bytes,
          contentType: mime,
          fileExtension: ext,
        );
    if (!mounted) return;
    setState(() => _savingInsurance = false);
    if (url == null) {
      setState(() {
        _message = 'Upload mislukt';
        _messageOk = false;
      });
      return;
    }
    setState(() {
      _pendingInsurancePhotoUrl = url;
      _message =
          'Photo uploaded. Enter insurer, policy number, and expiry, then tap Save.';
      _messageOk = true;
    });
  }

  Future<void> _saveInsurance(DriverComplianceSnapshot? snap) async {
    if (_insuranceLocked(snap)) return;
    if (await ref.read(driverIdProvider.future) == null) return;
    final photoUrl =
        _pendingInsurancePhotoUrl ?? (snap?.taxiInsurancePhotoUrl ?? '');
    if (photoUrl.isEmpty) {
      setState(() {
        _message = 'Upload a photo of your insurance document first.';
        _messageOk = false;
      });
      return;
    }
    final provider = _insuranceProviderCtrl.text.trim();
    final policy = _insurancePolicyCtrl.text.trim();
    final expiry = _insuranceExpiryCtrl.text.trim();
    if (provider.isEmpty || policy.isEmpty || expiry.isEmpty) {
      setState(() {
        _message = 'Fill insurer, policy number, and expiry before saving.';
        _messageOk = false;
      });
      return;
    }
    if (!mounted) return;
    if (!await _confirmPermanentDocSave(context, insurance: true)) return;
    setState(() {
      _savingInsurance = true;
      _message = null;
    });
    final res = await ref.read(driverDataServiceProvider).saveDriverDocument(
          documentType: 'taxi_insurance',
          insurancePhotoUrl: photoUrl,
          insuranceProvider: provider,
          insurancePolicyNr: policy,
          insuranceExpiry: expiry,
        );
    if (!mounted) return;
    setState(() => _savingInsurance = false);
    if (res?['success'] == true) {
      setState(() {
        _pendingInsurancePhotoUrl = null;
        _message = DriverStrings.chauffeurspasSaved;
        _messageOk = true;
      });
      ref.invalidate(driverComplianceProvider);
    } else {
      setState(() {
        _message = res?['error']?.toString() ?? 'Opslaan mislukt';
        _messageOk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final complianceAsync = ref.watch(driverComplianceProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.bg,
      body: complianceAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: colors.accent)),
        error: (_, __) => Center(
          child: Text(
            DriverStrings.chauffeurspasVerifyFailed,
            style: typo.bodyMedium.copyWith(color: colors.textSoft),
          ),
        ),
        data: (snap) {
          _syncFromSnapshot(snap);
          final vs = (snap?.veriffStatus ?? '').toLowerCase();
          final approvedVeriff =
              vs == 'approved' || vs == 'success' || vs == 'completed';
          final rijbewijsOk = snap?.rijbewijsVerified == true;
          final pasLocked = _chauffeurPasLocked(snap);
          final kvkLocked = _kvkLocked(snap);
          final insLocked = _insuranceLocked(snap);
          final insurancePhotoReady = _pendingInsurancePhotoUrl != null ||
              (snap?.taxiInsurancePhotoUrl ?? '').isNotEmpty;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: colors.text,
                            size: 20,
                          ),
                          onPressed: () => context.pop(),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DriverStrings.complianceAndDocuments,
                                style: typo.titleMedium.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.35,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DriverStrings.complianceSubtitleV2,
                                style: typo.bodySmall.copyWith(
                                  color: colors.textSoft,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (snap != null)
                      DriverComplianceOverallBanner(
                        snap: snap,
                        colors: colors,
                        typo: typo,
                      ),
                    const SizedBox(height: 16),
                    if (_message != null) ...[
                      Text(
                        _message!,
                        style: typo.bodySmall.copyWith(
                          color: _messageOk == true ? colors.success : colors.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    PremiumSettingsSectionLabel(
                      text: DriverStrings.docChauffeurspas,
                      colors: colors,
                      typo: typo,
                    ),
                    PremiumSettingsCard(
                      colors: colors,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Builder(
                            builder: (context) {
                              final c = chipChauffeurspas(snap, colors);
                              return DriverComplianceDocRow(
                                icon: Icons.badge_rounded,
                                title: DriverStrings.docChauffeurspas,
                                subtitle: subtitleChauffeurspas(snap),
                                chipLabel: c.$1,
                                chipColor: c.$2,
                                chipBg: c.$3,
                                colors: colors,
                                typo: typo,
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _chauffeurspasCtrl,
                                  readOnly: pasLocked,
                                  keyboardType: TextInputType.text,
                                  maxLength: 14,
                                  decoration: InputDecoration(
                                    labelText: DriverStrings.chauffeurspasHintV2,
                                    counterText: '',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _chauffeurspasExpiryCtrl,
                                  readOnly: pasLocked,
                                  decoration: InputDecoration(
                                    labelText: DriverStrings.chauffeurspasExpiryLabel,
                                    hintText: 'YYYY-MM-DD',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                if (pasLocked) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    DriverStrings.fieldLockedContactSupport,
                                    style: typo.bodySmall.copyWith(
                                      color: colors.textSoft,
                                      height: 1.35,
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed:
                                        _savingPas ? null : _saveChauffeurspas,
                                    style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    child: _savingPas
                                        ? SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colors.onAccent,
                                            ),
                                          )
                                        : Text(
                                            DriverStrings.chauffeurspasSave,
                                            style: typo.labelLarge.copyWith(
                                              color: colors.onAccent,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    PremiumSettingsSectionLabel(
                      text: DriverStrings.docRijbewijs,
                      colors: colors,
                      typo: typo,
                    ),
                    PremiumSettingsCard(
                      colors: colors,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Builder(
                              builder: (context) {
                                final c = chipRijbewijs(snap, colors);
                                return DriverComplianceDocRow(
                                  icon: Icons.credit_card_rounded,
                                  title: DriverStrings.docRijbewijs,
                                  subtitle: subtitleRijbewijs(snap),
                                  chipLabel: c.$1,
                                  chipColor: c.$2,
                                  chipBg: c.$3,
                                  colors: colors,
                                  typo: typo,
                                );
                              },
                            ),
                            if (rijbewijsOk) ...[
                              if (_veriffMetaLine(snap).isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _veriffMetaLine(snap),
                                  style: typo.bodySmall.copyWith(
                                    color: colors.textSoft,
                                  ),
                                ),
                              ],
                            ] else if (approvedVeriff) ...[
                              const SizedBox(height: 8),
                              Text(
                                DriverStrings.licenceSubmittedPendingReview,
                                style: typo.bodySmall.copyWith(
                                  color: colors.text,
                                  height: 1.35,
                                ),
                              ),
                              if (_veriffMetaLine(snap).isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _veriffMetaLine(snap),
                                  style: typo.bodySmall.copyWith(
                                    color: colors.textSoft,
                                  ),
                                ),
                              ],
                            ] else ...[
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () =>
                                    context.push('/driver/veriff'),
                                child: Text(DriverStrings.veriffStart),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    PremiumSettingsSectionLabel(
                      text: DriverStrings.docTaxiInsurance,
                      colors: colors,
                      typo: typo,
                    ),
                    PremiumSettingsCard(
                      colors: colors,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Builder(
                              builder: (context) {
                                final c = rowChip(
                                  snap?.taxiInsuranceVerified,
                                  snap?.taxiInsuranceExpiry,
                                  colors,
                                );
                                return DriverComplianceDocRow(
                                  icon: Icons.shield_rounded,
                                  title: DriverStrings.docTaxiInsurance,
                                  subtitle: subtitleInsurance(snap),
                                  chipLabel: c.$1,
                                  chipColor: c.$2,
                                  chipBg: c.$3,
                                  colors: colors,
                                  typo: typo,
                                );
                              },
                            ),
                            if (insLocked)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  DriverStrings.fieldLockedContactSupport,
                                  style: typo.bodySmall.copyWith(
                                    color: colors.textSoft,
                                    height: 1.35,
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  DriverStrings.insuranceAccuracyWarning,
                                  style: typo.bodySmall.copyWith(
                                    color: colors.textSoft,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            if (insurancePhotoReady)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  DriverStrings.insurancePhotoOnFile,
                                  style: typo.bodySmall.copyWith(
                                    color: colors.success,
                                  ),
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: (_savingInsurance || insLocked)
                                  ? null
                                  : _pickInsurancePhoto,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: Text(DriverStrings.insurancePickPhoto),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _insuranceProviderCtrl,
                              readOnly: insLocked,
                              decoration: InputDecoration(
                                labelText: 'Verzekeraar',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _insurancePolicyCtrl,
                              readOnly: insLocked,
                              decoration: InputDecoration(
                                labelText: 'Polisnummer',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _insuranceExpiryCtrl,
                              readOnly: insLocked,
                              keyboardType: TextInputType.datetime,
                              decoration: InputDecoration(
                                labelText: 'Vervaldatum',
                                hintText: 'YYYY-MM-DD',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            if (!insLocked) ...[
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _savingInsurance
                                    ? null
                                    : () => _saveInsurance(snap),
                                child: _savingInsurance
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colors.onAccent,
                                        ),
                                      )
                                    : Text(DriverStrings.insuranceSave),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    PremiumSettingsSectionLabel(
                      text: DriverStrings.docKvk,
                      colors: colors,
                      typo: typo,
                    ),
                    PremiumSettingsCard(
                      colors: colors,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Builder(
                              builder: (context) {
                                final c = rowChip(snap?.kvkVerified, null, colors);
                                return DriverComplianceDocRow(
                                  icon: Icons.apartment_rounded,
                                  title: DriverStrings.docKvk,
                                  subtitle: DriverStrings.kvkManualVerifyHint,
                                  chipLabel: c.$1,
                                  chipColor: c.$2,
                                  chipBg: c.$3,
                                  colors: colors,
                                  typo: typo,
                                );
                              },
                            ),
                            TextField(
                              controller: _kvkNumberCtrl,
                              readOnly: kvkLocked,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8),
                              ],
                              decoration: InputDecoration(
                                labelText: 'KvK nummer (8 cijfers)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _kvkNameCtrl,
                              readOnly: kvkLocked,
                              decoration: InputDecoration(
                                labelText: 'Bedrijfsnaam',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _kvkAddressCtrl,
                              readOnly: kvkLocked,
                              decoration: InputDecoration(
                                labelText: 'Vestigingsadres',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            if (kvkLocked) ...[
                              const SizedBox(height: 10),
                              Text(
                                DriverStrings.fieldLockedContactSupport,
                                style: typo.bodySmall.copyWith(
                                  color: colors.textSoft,
                                  height: 1.35,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _savingKvk ? null : _saveKvk,
                                child: _savingKvk
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colors.onAccent,
                                        ),
                                      )
                                    : Text(DriverStrings.kvkSave),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    PremiumSettingsSectionLabel(
                      text: DriverStrings.docApkVehicle,
                      colors: colors,
                      typo: typo,
                    ),
                    PremiumSettingsCard(
                      colors: colors,
                      child: Column(
                        children: [
                          Builder(
                            builder: (context) {
                              final c = chipVehicle(snap, colors);
                              return DriverComplianceDocRow(
                                icon: Icons.directions_car_rounded,
                                title: DriverStrings.docApkVehicle,
                                subtitle: subtitleVehicle(snap),
                                chipLabel: c.$1,
                                chipColor: c.$2,
                                chipBg: c.$3,
                                colors: colors,
                                typo: typo,
                                onTap: () => context.push('/driver/vehicle'),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: colors.textSoft,
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Text(
                              DriverStrings.vehiclePlateRdw,
                              style: typo.bodySmall.copyWith(color: colors.textSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      DriverStrings.complianceFooterV2,
                      style: typo.bodySmall.copyWith(
                        color: colors.textSoft,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: bottomPad + 88),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
