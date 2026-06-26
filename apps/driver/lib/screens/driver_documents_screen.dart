import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_runtime_providers.dart';
import '../utils/driver_runtime_refresh.dart';
import '../services/driver_data_service.dart';
import '../utils/chauffeurspas_validation.dart';
import '../utils/driver_compliance_ui.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_compliance_doc_row.dart';
import '../widgets/driver_compliance_vault_body.dart';
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
  bool _chauffeurPasJustSaved = false;
  bool _savingKvk = false;
  bool _savingInsurance = false;
  bool _savingIndemnification = false;
  bool _savingLegalRead = false;
  bool _termsReadChecked = false;
  bool _indemnificationQuizPassedLocal = false;
  /// Set after a successful insurance photo upload; cleared after insurance RPC save.
  String? _pendingInsurancePhotoUrl;
  bool _indemnificationReadChecked = false;
  String? _message;
  bool? _messageOk;

  void _showInfoSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _refreshComplianceCaches() {
    ref.invalidate(driverComplianceProvider);
    ref.invalidate(driverProfileProvider);
    unawaited(refreshDriverRuntime(ref));
  }

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
    if (_chauffeurPasJustSaved) return true;
    if (s == null) return false;
    final hasSubmittedNumber = (s.chauffeurspasNumber ?? '').trim().isNotEmpty;
    final hasSubmittedExpiry = s.chauffeurspasExpiry != null;
    // Once submitted, lock in-app edits (support can assist with corrections).
    return s.chauffeurspasVerified == true ||
        (hasSubmittedNumber && hasSubmittedExpiry);
  }

  String? _normalizeDateToIso(String input) {
    final t = input.trim();
    if (t.isEmpty) return null;
    final iso = DateTime.tryParse(t);
    if (iso != null) return iso.toIso8601String().split('T').first;

    // Accept driver-friendly input like DD-MM-YYYY or DD/MM/YYYY.
    final m = RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$').firstMatch(t);
    if (m == null) return null;
    final day = int.tryParse(m.group(1)!);
    final month = int.tryParse(m.group(2)!);
    final year = int.tryParse(m.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed.toIso8601String().split('T').first;
  }

  bool _kvkLocked(DriverComplianceSnapshot? s) {
    if (s == null) return false;
    return (s.kvkNumber ?? '').trim().isNotEmpty;
  }

  bool _insuranceLocked(DriverComplianceSnapshot? s) {
    // Product decision: insurance can be updated at any time.
    return false;
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
    if (!_termsReadChecked && snap.termsAcceptedAt != null) {
      _termsReadChecked = true;
    }
    if (!_indemnificationReadChecked && snap.indemnificationReadAt != null) {
      _indemnificationReadChecked = true;
    }
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

  Future<void> _openIndemnificationDoc() async {
    if (!mounted) return;
    context.push('/driver/indemnification');
  }

  Future<void> _saveTermsAcknowledgement() async {
    if (_savingLegalRead) return;
    setState(() {
      _savingLegalRead = true;
      _message = null;
    });
    final ok = await ref.read(driverDataServiceProvider).saveTermsOfServiceAcknowledgement();
    if (!mounted) return;
    setState(() {
      _savingLegalRead = false;
      _message = ok
          ? DriverStrings.legalChecklistSaved
          : DriverStrings.legalChecklistSaveFailed;
      _messageOk = ok;
      if (ok) _termsReadChecked = true;
    });
    if (ok) {
      _refreshComplianceCaches();
    }
  }

  Future<void> _saveIndemnificationReadAcknowledgement() async {
    if (_savingLegalRead) return;
    setState(() {
      _savingLegalRead = true;
      _message = null;
    });
    final ok = await ref
        .read(driverDataServiceProvider)
        .saveIndemnificationReadAcknowledgement();
    if (!mounted) return;
    setState(() {
      _savingLegalRead = false;
      _message = ok
          ? DriverStrings.legalChecklistSaved
          : DriverStrings.legalChecklistSaveFailed;
      _messageOk = ok;
      if (ok) _indemnificationReadChecked = true;
    });
    if (ok) {
      _refreshComplianceCaches();
    }
  }

  Future<bool?> _runIndemnificationQuizAttempt() async {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    int? q1;
    int? q2;
    int? q3;
    int? q4;
    int? q5;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget optionRow(
            String title,
            List<String> options,
            int? value,
            void Function(int?) onChanged,
          ) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typo.bodyMedium.copyWith(color: colors.text, fontWeight: FontWeight.w700),
                ),
                ...List.generate(
                  options.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setLocal(() => onChanged(i)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: value == i ? colors.accent : colors.border,
                            width: value == i ? 1.6 : 1,
                          ),
                          color: value == i
                              ? colors.accent.withValues(alpha: 0.08)
                              : colors.card,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              value == i
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 18,
                              color: value == i ? colors.accent : colors.textSoft,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                options[i],
                                style: typo.bodySmall.copyWith(color: colors.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            );
          }

          return AlertDialog(
            title: Text(DriverStrings.indemnificationQuizTitle),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    optionRow(
                      '1) Who is responsible for transport obligations during rides?',
                      const ['HeyCaby', 'The Driver', 'Both equally'],
                      q1,
                      (v) => q1 = v,
                    ),
                    optionRow(
                      '2) If a driver has expired insurance, who is liable?',
                      const ['HeyCaby', 'The Driver', 'No one'],
                      q2,
                      (v) => q2 = v,
                    ),
                    optionRow(
                      '3) Does not reading the indemnification remove your liability?',
                      const ['Yes', 'No', 'Only partially'],
                      q3,
                      (v) => q3 = v,
                    ),
                    optionRow(
                      '4) Is HeyCaby a party to the Driver-Rider transport agreement?',
                      const ['Yes', 'No', 'Only for disputes'],
                      q4,
                      (v) => q4 = v,
                    ),
                    optionRow(
                      '5) What must be valid before operating?',
                      const [
                        'Only app login',
                        'Licences/permits/insurance and legal compliance',
                        'Only vehicle photo',
                      ],
                      q5,
                      (v) => q5 = v,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text(DriverStrings.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final answered = [q1, q2, q3, q4, q5].every((e) => e != null);
                  if (!answered) {
                    return;
                  }
                  final passed = q1 == 1 && q2 == 1 && q3 == 1 && q4 == 1 && q5 == 1;
                  Navigator.of(ctx).pop(passed);
                },
                child: const Text(DriverStrings.submit),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startIndemnificationFlow(DriverComplianceSnapshot? snap) async {
    final alreadyDone =
        snap?.indemnificationReadAt != null && snap?.indemnificationQuizPassed == true;
    if (alreadyDone) return;
    final indemnificationRead =
        (snap?.indemnificationReadAt != null) || _indemnificationReadChecked;
    if (!indemnificationRead) {
      setState(() {
        _message = DriverStrings.indemnificationReadRequired;
        _messageOk = false;
      });
      return;
    }

    setState(() {
      _savingIndemnification = true;
      _message = null;
    });

    var passed = false;
    while (mounted && !passed) {
      final result = await _runIndemnificationQuizAttempt();
      if (!mounted) return;
      if (result == null) {
        setState(() => _savingIndemnification = false);
        return;
      }
      if (result == true) {
        passed = true;
        break;
      }
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(DriverStrings.indemnificationQuizTitle),
          content: Text(DriverStrings.indemnificationQuizFail),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(DriverStrings.stop),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(DriverStrings.tryAgain),
            ),
          ],
        ),
      );
      if (retry != true) {
        setState(() => _savingIndemnification = false);
        return;
      }
    }

    final ok = await ref.read(driverDataServiceProvider).saveIndemnificationAcknowledgement(
          quizPassed: true,
        );
    if (!mounted) return;
    setState(() {
      _savingIndemnification = false;
      if (ok) _indemnificationQuizPassedLocal = true;
      _message = ok
          ? DriverStrings.indemnificationPassed
          : DriverStrings.indemnificationSaveFailed;
      _messageOk = ok;
    });
    if (ok) {
      await _showIndemnificationPassedDialog();
      if (!mounted) return;
      _refreshComplianceCaches();
    }
  }

  Future<void> _showIndemnificationPassedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(DriverStrings.indemnificationQuizPassTitle),
        content: Text(DriverStrings.indemnificationQuizPassBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(DriverStrings.indemnificationQuizPassCta),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChauffeurspas() async {
    final snap = ref.read(driverComplianceProvider).valueOrNull;
    if (_chauffeurPasLocked(snap)) {
      setState(() {
        _message = DriverStrings.fieldLockedContactSupport;
        _messageOk = false;
      });
      return;
    }
    if (await ref.read(driverIdProvider.future) == null) {
      setState(() {
        _message = DriverStrings.profileDriverSetupFailed;
        _messageOk = false;
      });
      return;
    }
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
    final expiryRaw = _chauffeurspasExpiryCtrl.text.trim();
    if (expiryRaw.isEmpty) {
      setState(() {
        _message = DriverStrings.chauffeurspasExpiryRequired;
        _messageOk = false;
      });
      return;
    }
    final expiry = _normalizeDateToIso(expiryRaw);
    if (expiry == null) {
      setState(() {
        _message = DriverStrings.chauffeurspasExpiryInvalid;
        _messageOk = false;
      });
      return;
    }
    setState(() {
      _savingPas = true;
      _message = null;
    });
    final res = await ref.read(driverDataServiceProvider).saveChauffeurspasDocument(
          chauffeurspasNumber: v.cleaned,
          chauffeurspasExpiry: expiry,
        );
    if (!mounted) return;
    setState(() => _savingPas = false);
    if (res?['success'] == true) {
      setState(() {
        _chauffeurPasJustSaved = true;
        _message = DriverStrings.chauffeurspasSaved;
        _messageOk = true;
      });
      _showInfoSnack('Document saved successfully.');
      _refreshComplianceCaches();
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
    if (_kvkAddressCtrl.text.trim().isEmpty) {
      setState(() {
        _message = DriverStrings.kvkNumberAddressRequired;
        _messageOk = false;
      });
      return;
    }
    setState(() => _savingKvk = true);
    final res = await ref.read(driverDataServiceProvider).saveKvkDocument(
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
      _showInfoSnack('Information saved successfully.');
      _refreshComplianceCaches();
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(DriverStrings.insuranceUseCamera),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(DriverStrings.insuranceUseGallery),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final x = await picker.pickImage(
      source: source,
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
    _showInfoSnack('Insurance photo uploaded.');
  }

  Future<void> _saveInsurance(DriverComplianceSnapshot? snap) async {
    if (_insuranceLocked(snap)) return;
    if (await ref.read(driverIdProvider.future) == null) return;
    final photoUrl =
        _pendingInsurancePhotoUrl ?? (snap?.taxiInsurancePhotoUrl ?? '');
    final provider = _insuranceProviderCtrl.text.trim();
    final policy = _insurancePolicyCtrl.text.trim();
    final expiry = _insuranceExpiryCtrl.text.trim();
    final missing = <String>[];
    if (provider.isEmpty) missing.add('insurer');
    if (policy.isEmpty) missing.add('policy number');
    if (expiry.isEmpty) missing.add('expiry date');
    if (photoUrl.isEmpty) missing.add('insurance photo');
    if (missing.isNotEmpty) {
      final message = 'Missing: ${missing.join(', ')}.';
      setState(() {
        _message = message;
        _messageOk = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }
    final insuranceExpiryIso = _normalizeDateToIso(expiry);
    if (insuranceExpiryIso == null) {
      setState(() {
        _message = DriverStrings.invalidExpiryDateFormat;
        _messageOk = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(DriverStrings.invalidExpiryDateFormat),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    if (!await _confirmPermanentDocSave(context, insurance: true)) return;
    setState(() {
      _savingInsurance = true;
      _message = null;
    });
    final res = await ref.read(driverDataServiceProvider).saveTaxiInsuranceDocument(
          insurancePhotoUrl: photoUrl,
          insuranceProvider: provider,
          insurancePolicyNr: policy,
          insuranceExpiry: insuranceExpiryIso,
        );
    if (!mounted) return;
    setState(() => _savingInsurance = false);
    if (res?['success'] == true) {
      setState(() {
        _pendingInsurancePhotoUrl = null;
        _message = 'Insurance saved successfully.';
        _messageOk = true;
      });
      _showInfoSnack('Insurance document saved successfully.');
      _refreshComplianceCaches();
    } else {
      setState(() {
        _message = res?['error']?.toString() ?? 'Opslaan mislukt';
        _messageOk = false;
      });
    }
  }

  void _openInsurancePreview(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final colors = ref.read(colorsProvider);
        final typo = ref.read(typographyProvider);
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.of(ctx).size.height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DriverStrings.insurancePreviewTitle,
                          style: typo.titleMedium.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          DriverStrings.insurancePreviewFailed,
                          style: typo.bodyMedium.copyWith(color: colors.textSoft),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _resolveInsurancePreviewUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    // Stored values may be public-style URLs, but `driver-documents` is private.
    // Generate a short-lived signed URL for reliable preview access.
    final idx = uri.pathSegments.indexOf('driver-documents');
    if (idx >= 0 && idx + 1 < uri.pathSegments.length) {
      final objectPath = uri.pathSegments.sublist(idx + 1).join('/');
      if (objectPath.isEmpty) return null;
      try {
        final signed = await HeyCabySupabase.client.storage
            .from('driver-documents')
            .createSignedUrl(objectPath, 60 * 10);
        return signed;
      } catch (_) {
        return null;
      }
    }

    // If already a signed/accessible URL, fallback to raw.
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final complianceAsync = ref.watch(driverComplianceProvider);
    final profileAsync = ref.watch(driverProfileProvider);
    final readinessAsync = ref.watch(driverReadinessProvider);

    return complianceAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: colors.primary)),
      error: (_, __) => Center(
        child: Text(
          DriverStrings.chauffeurspasVerifyFailed,
          style: typography.bodyMedium.copyWith(color: colors.textMuted),
        ),
      ),
      data: (snap) {
        final profile = profileAsync.valueOrNull;
        _syncFromSnapshot(snap);
        final approvedVeriff =
            _isApprovedVeriff(snap?.veriffStatus ?? '');
        final pasLocked = _chauffeurPasLocked(snap);
        final kvkLocked = _kvkLocked(snap);
        final insLocked = _insuranceLocked(snap);
        final insurancePhotoReady = _pendingInsurancePhotoUrl != null ||
            (snap?.taxiInsurancePhotoUrl ?? '').isNotEmpty;
        final insurancePreviewUrl =
            _pendingInsurancePhotoUrl ?? (snap?.taxiInsurancePhotoUrl ?? '');
        final readiness = readinessAsync.valueOrNull;
        final rijbewijsOk = snap?.rijbewijsVerified == true;
        final checklistItems = readiness?.checklist
                .map(
                  (item) => DriverComplianceChecklistItem(
                    title: item.label,
                    complete: item.complete,
                  ),
                )
                .toList() ??
            const <DriverComplianceChecklistItem>[];

        return DriverComplianceVaultBody(
          colors: colors,
          typography: typography,
          checklistTitle: DriverStrings.goOnlineChecklistTitle,
          checklistHint: DriverStrings.goOnlineChecklistHint,
          items: checklistItems,
          onBack: () => context.pop(),
          onRefreshChecklist: () => unawaited(refreshDriverRuntime(ref)),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _complianceDocumentSections(
              context: context,
              snap: snap,
              profile: profile,
              colors: ref.watch(colorsProvider),
              typo: ref.watch(typographyProvider),
              approvedVeriff: approvedVeriff,
              rijbewijsOk: rijbewijsOk,
              pasLocked: pasLocked,
              kvkLocked: kvkLocked,
              insLocked: insLocked,
              insurancePhotoReady: insurancePhotoReady,
              insurancePreviewUrl: insurancePreviewUrl,
            ),
          ),
        );
      },
    );
  }

  bool _isApprovedVeriff(String status) {
    final vs = status.toLowerCase();
    return vs == 'approved' || vs == 'success' || vs == 'completed';
  }

  List<Widget> _complianceDocumentSections({
    required BuildContext context,
    required DriverComplianceSnapshot? snap,
    required DriverProfile? profile,
    required HeyCabyColorTokens colors,
    required HeyCabyTypography typo,
    required bool approvedVeriff,
    required bool rijbewijsOk,
    required bool pasLocked,
    required bool kvkLocked,
    required bool insLocked,
    required bool insurancePhotoReady,
    required String insurancePreviewUrl,
  }) {
    return [
                    if (snap != null)
                      DriverComplianceOverallBanner(
                        snap: snap,
                        profilePhotoUrl: profile?.profilePhotoUrl,
                        vehiclePhotoUrls: profile?.vehiclePhotoUrls ?? const [],
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
                      text: DriverStrings.legalChecklistTitle,
                      colors: colors,
                      typo: typo,
                    ),
                    Builder(
                      builder: (_) {
                        final termsDone =
                            (snap?.termsAcceptedAt != null) || _termsReadChecked;
                        final indemnificationDone =
                            (snap?.indemnificationReadAt != null) ||
                                _indemnificationReadChecked;
                        final quizDone = (snap?.indemnificationQuizPassed == true) ||
                            _indemnificationQuizPassedLocal;
                        final completed = <bool>[
                          termsDone,
                          indemnificationDone,
                          quizDone,
                        ].where((it) => it).length;
                        if (completed >= 3) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 10),
                          child: Text(
                            DriverStrings.legalChecklistProgress(completed, 3),
                            style: typo.bodySmall.copyWith(
                              color: colors.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                    PremiumSettingsCard(
                      colors: colors,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if ((snap?.indemnificationReadAt != null) &&
                                (snap?.indemnificationQuizPassed == true))
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.success.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: colors.success.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: colors.success,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        DriverStrings.legalChecklistAllVerified,
                                        style: typo.labelSmall.copyWith(
                                          color: colors.success,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Text(
                              DriverStrings.indemnificationSummary1,
                              style: typo.bodySmall.copyWith(
                                color: colors.textSoft,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => context.push('/driver/terms'),
                              icon: const Icon(Icons.menu_book_rounded),
                              label: Text(DriverStrings.legalChecklistOpenTerms),
                            ),
                            CheckboxListTile(
                              value: (snap?.termsAcceptedAt != null) ||
                                  _termsReadChecked,
                              onChanged: (snap?.termsAcceptedAt != null)
                                  ? null
                                  : (v) async {
                                      if (v != true) return;
                                      await _saveTermsAcknowledgement();
                                    },
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                DriverStrings.legalChecklistTermsCheck,
                                style: typo.bodySmall.copyWith(color: colors.text),
                              ),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: _openIndemnificationDoc,
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: Text(DriverStrings.legalChecklistOpenIndemnification),
                            ),
                            CheckboxListTile(
                              value: snap?.indemnificationReadAt != null || _indemnificationReadChecked,
                              onChanged: (snap?.indemnificationReadAt != null)
                                  ? null
                                  : (v) async {
                                      if (v != true) return;
                                      await _saveIndemnificationReadAcknowledgement();
                                    },
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                DriverStrings.legalChecklistIndemnificationCheck,
                                style: typo.bodySmall.copyWith(color: colors.text),
                              ),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              value: (snap?.indemnificationQuizPassed == true) ||
                                  _indemnificationQuizPassedLocal,
                              onChanged: null,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                DriverStrings.legalChecklistQuizCheck,
                                style: typo.bodySmall.copyWith(color: colors.text),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: (((snap?.indemnificationQuizPassed == true) ||
                                          _indemnificationQuizPassedLocal) ||
                                      _savingIndemnification)
                                  ? null
                                  : () => _startIndemnificationFlow(snap),
                              child: _savingIndemnification
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.onAccent,
                                      ),
                                    )
                                  : Text(DriverStrings.indemnificationStartQuiz),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                                bool hasText(String? v) => (v ?? '').trim().isNotEmpty;
                                final expiry = snap?.taxiInsuranceExpiry;
                                final now = DateTime.now();
                                final expired =
                                    expiry != null && expiry.isBefore(now);
                                final hasInsuranceOnFile =
                                    hasText(snap?.taxiInsuranceProvider) &&
                                    hasText(snap?.taxiInsurancePolicyNumber) &&
                                    expiry != null &&
                                    hasText(snap?.taxiInsurancePhotoUrl);
                                final c = expired
                                    ? (
                                        DriverStrings.statusExpired,
                                        colors.error,
                                        colors.error.withValues(alpha: 0.12),
                                      )
                                    : hasInsuranceOnFile
                                    ? (
                                        DriverStrings.statusVerified,
                                        colors.success,
                                        colors.success.withValues(alpha: 0.12),
                                      )
                                    : (
                                        DriverStrings.statusActionNeeded,
                                        colors.warning,
                                        colors.warning.withValues(alpha: 0.14),
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
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                DriverStrings.insuranceCanEditAnytime,
                                style: typo.bodySmall.copyWith(
                                  color: colors.textSoft,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            if (!insLocked)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  DriverStrings.insuranceLiabilityDisclaimer,
                                  style: typo.bodySmall.copyWith(
                                    color: colors.textSoft,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            if (insurancePhotoReady)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: insurancePreviewUrl.isEmpty
                                      ? null
                                      : () async {
                                          final resolved =
                                              await _resolveInsurancePreviewUrl(
                                            insurancePreviewUrl,
                                          );
                                          if (!mounted) return;
                                          if (resolved == null ||
                                              resolved.trim().isEmpty) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  DriverStrings
                                                      .insurancePreviewFailed,
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          _openInsurancePreview(resolved);
                                        },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 2,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.verified_outlined,
                                          size: 16,
                                          color: colors.success,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            DriverStrings.insurancePhotoTapToView,
                                            style: typo.bodySmall.copyWith(
                                              color: colors.success,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: (_savingInsurance || insLocked)
                                  ? null
                                  : _pickInsurancePhoto,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: Text(
                                DriverStrings.insurancePickPhotoGreenCard,
                              ),
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
                                bool hasText(String? v) => (v ?? '').trim().isNotEmpty;
                                final hasKvkOnFile =
                                    hasText(snap?.kvkNumber) &&
                                    hasText(snap?.kvkAddress);
                                final c = hasKvkOnFile
                                    ? (
                                        DriverStrings.statusVerified,
                                        colors.success,
                                        colors.success.withValues(alpha: 0.12),
                                      )
                                    : (
                                        DriverStrings.statusActionNeeded,
                                        colors.warning,
                                        colors.warning.withValues(alpha: 0.14),
                                      );
                                return DriverComplianceDocRow(
                                  icon: Icons.apartment_rounded,
                                  title: DriverStrings.docKvk,
                                  subtitle: DriverStrings.kvkManualVerifyDetailed,
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
                              DriverStrings.vehiclePlateRdwOpenSource,
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
    ];
  }
}
