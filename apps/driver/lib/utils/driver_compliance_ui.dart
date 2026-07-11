import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../services/driver_data_service.dart';
import '../widgets/driver_compliance_doc_row.dart';

/// Overall compliance status banner.
class DriverComplianceOverallBanner extends StatelessWidget {
  const DriverComplianceOverallBanner({
    super.key,
    required this.snap,
    required this.profilePhotoUrl,
    required this.vehiclePhotoUrls,
    required this.colors,
    required this.typo,
  });

  final DriverComplianceSnapshot snap;
  final String? profilePhotoUrl;
  final List<String> vehiclePhotoUrls;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    final st = complianceBannerStyle(snap.complianceStatus, colors);
    final progress = driverComplianceProgress(
      snap,
      profilePhotoUrl: profilePhotoUrl,
      vehiclePhotoUrls: vehiclePhotoUrls,
    );
    final percent = ((progress.completed / progress.total) * 100).round();
    final progressValue = (progress.completed / progress.total).clamp(0.0, 1.0);
    final licensePendingManual =
        progress.licenseStepDone && snap.rijbewijsVerified != true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: st.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: st.fg, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DriverStrings.complianceOverall,
                  style: typo.labelSmall.copyWith(
                      color: colors.textSoft, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  st.title,
                  style: typo.titleMedium
                      .copyWith(color: st.fg, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      DriverStrings.complianceProgressTitle,
                      style: typo.labelSmall.copyWith(
                        color: colors.textSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DriverStrings.complianceProgressPercent(percent),
                      style: typo.labelSmall.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 8,
                    backgroundColor: colors.border.withValues(alpha: 0.45),
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DriverStrings.complianceProgressCount(
                    progress.completed,
                    progress.total,
                  ),
                  style: typo.labelSmall.copyWith(
                    color: colors.textSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (licensePendingManual) ...[
                  const SizedBox(height: 6),
                  Text(
                    DriverStrings.complianceManualLicensePending,
                    style: typo.labelSmall.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String fmtNlDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String subtitleChauffeurspas(DriverComplianceSnapshot? d) {
  if (d == null) return DriverStrings.statusNotSet;
  if (d.chauffeurspasExpiry != null) {
    return '${DriverStrings.expiresOn} ${fmtNlDate(d.chauffeurspasExpiry!)}';
  }
  return DriverStrings.statusNotSet;
}

/// True when Veriff returned a positive decision (mirrors documents screen / webhook).
bool veriffDecisionLooksApproved(String? veriffStatus) {
  final vs = (veriffStatus ?? '').toLowerCase();
  return vs == 'approved' || vs == 'success' || vs == 'completed';
}

String subtitleRijbewijs(DriverComplianceSnapshot? d) {
  if (d == null) return DriverStrings.statusNotSet;
  if (d.rijbewijsVerified == true) {
    final exp = d.rijbewijsExpiry ?? d.veriffIdExpiry;
    if (exp != null) {
      return '${DriverStrings.expiresOn} ${fmtNlDate(exp)}';
    }
    return DriverStrings.statusVerified;
  }
  if (veriffDecisionLooksApproved(d.veriffStatus)) {
    if (d.veriffIdExpiry != null) {
      return '${DriverStrings.licenceSubmittedPendingReview}\n'
          '${DriverStrings.expiresOn} ${fmtNlDate(d.veriffIdExpiry!)}';
    }
    return DriverStrings.licenceSubmittedPendingReview;
  }
  if (d.rijbewijsExpiry != null) {
    return '${DriverStrings.expiresOn} ${fmtNlDate(d.rijbewijsExpiry!)}';
  }
  return DriverStrings.complianceUploadPortal;
}

/// Driving licence: verified only when `rijbewijs_verified` (ops after Veriff review).
/// Veriff-approved but unconfirmed stays **pending**.
(String, Color, Color) chipRijbewijs(
    DriverComplianceSnapshot? d, HeyCabyColorTokens colors) {
  if (d == null) return rowChip(null, null, colors);
  if (d.rijbewijsVerified == true) {
    final exp = d.rijbewijsExpiry ?? d.veriffIdExpiry;
    return rowChip(true, exp, colors);
  }
  if (veriffDecisionLooksApproved(d.veriffStatus)) {
    final exp = d.rijbewijsExpiry ?? d.veriffIdExpiry;
    return rowChip(null, exp, colors);
  }
  return rowChip(d.rijbewijsVerified, d.rijbewijsExpiry, colors);
}

String subtitleVog(DriverComplianceSnapshot? d) {
  if (d == null) return DriverStrings.statusNotSet;
  if (d.vogImpliedByChauffeurspas == true) return DriverStrings.statusImplied;
  if (d.vogExpiresAt != null)
    return '${DriverStrings.expiresOn} ${fmtNlDate(d.vogExpiresAt!)}';
  return DriverStrings.complianceUploadPortal;
}

String subtitleInsurance(DriverComplianceSnapshot? d) {
  if (d == null) return DriverStrings.statusNotSet;
  if (d.taxiInsuranceExpiry != null) {
    return '${DriverStrings.expiresOn} ${fmtNlDate(d.taxiInsuranceExpiry!)}';
  }
  return DriverStrings.complianceUploadPortal;
}

String subtitleVehicle(DriverComplianceSnapshot? d) {
  if (d == null) return DriverStrings.statusNotSet;
  final plate = d.vehiclePlate ?? '—';
  final brand = [d.rdwMerk, d.rdwHandelsbenaming]
      .whereType<String>()
      .where((e) => e.isNotEmpty)
      .join(' ');
  final apk = d.apkExpiry;
  final apkStr = apk != null
      ? '${DriverStrings.expiresOn} ${fmtNlDate(apk)}'
      : DriverStrings.statusNotSet;
  final wam = d.rdwWamVerzekerd;
  final wamStr = wam != null ? 'WAM: $wam' : '';
  return '$plate · $brand\n$apkStr ${wamStr.isEmpty ? '' : '· $wamStr'}';
}

(String, Color, Color) chipChauffeurspas(
    DriverComplianceSnapshot? d, HeyCabyColorTokens colors) {
  if (d == null) {
    return (
      DriverStrings.statusActionNeeded,
      colors.warning,
      colors.warning.withValues(alpha: 0.14),
    );
  }
  final now = DateTime.now();
  final expiry = d.chauffeurspasExpiry;
  final hasNumber = (d.chauffeurspasNumber ?? '').trim().isNotEmpty;
  if (expiry != null && expiry.isBefore(now)) {
    return (
      DriverStrings.statusExpired,
      colors.error,
      colors.error.withValues(alpha: 0.12)
    );
  }
  if (hasNumber && expiry != null) {
    return (
      DriverStrings.statusVerified,
      colors.success,
      colors.success.withValues(alpha: 0.12)
    );
  }
  return (
    DriverStrings.statusActionNeeded,
    colors.warning,
    colors.warning.withValues(alpha: 0.14),
  );
}

(String, Color, Color) rowChip(
    bool? verified, DateTime? expiry, HeyCabyColorTokens colors) {
  final now = DateTime.now();
  if (expiry != null && expiry.isBefore(now)) {
    return (
      DriverStrings.statusExpired,
      colors.error,
      colors.error.withValues(alpha: 0.12)
    );
  }
  if (verified == true) {
    return (
      DriverStrings.statusVerified,
      colors.success,
      colors.success.withValues(alpha: 0.12)
    );
  }
  if (verified == false) {
    return (
      DriverStrings.statusActionNeeded,
      colors.warning,
      colors.warning.withValues(alpha: 0.14)
    );
  }
  return (
    DriverStrings.statusPending,
    colors.textMid,
    colors.border.withValues(alpha: 0.35)
  );
}

(String, Color, Color) rowChipVog(
    DriverComplianceSnapshot? d, HeyCabyColorTokens colors) {
  if (d?.vogImpliedByChauffeurspas == true) {
    return (
      DriverStrings.statusImplied,
      colors.accent,
      colors.accent.withValues(alpha: 0.12)
    );
  }
  return rowChip(d?.vogVerified, d?.vogExpiresAt, colors);
}

(String, Color, Color) chipVehicle(
    DriverComplianceSnapshot? d, HeyCabyColorTokens colors) {
  final now = DateTime.now();
  final apk = d?.apkExpiry;
  if (apk != null && apk.isBefore(now)) {
    return (
      DriverStrings.statusExpired,
      colors.error,
      colors.error.withValues(alpha: 0.12)
    );
  }
  final status = d?.vehicleVerificationStatus?.toLowerCase() ?? '';
  if (status.contains('taxi') || d?.vehicleVerified == true) {
    return (
      DriverStrings.statusVerified,
      colors.success,
      colors.success.withValues(alpha: 0.12)
    );
  }
  if (d?.vehicleVerified == false || status.contains('not_taxi')) {
    return (
      DriverStrings.statusActionNeeded,
      colors.warning,
      colors.warning.withValues(alpha: 0.14)
    );
  }
  return (
    DriverStrings.statusPending,
    colors.textMid,
    colors.border.withValues(alpha: 0.35)
  );
}

class DriverComplianceProgress {
  const DriverComplianceProgress({
    required this.completed,
    required this.total,
    required this.licenseStepDone,
  });

  final int completed;
  final int total;
  final bool licenseStepDone;
}

DriverComplianceProgress driverComplianceProgress(
  DriverComplianceSnapshot d, {
  required String? profilePhotoUrl,
  required List<String> vehiclePhotoUrls,
}) {
  bool hasText(String? v) => (v ?? '').trim().isNotEmpty;

  final pictureDone = hasText(profilePhotoUrl);
  final carDone = vehiclePhotoUrls.where((e) => e.trim().isNotEmpty).isNotEmpty;
  final kvkDone = hasText(d.kvkNumber) && hasText(d.kvkAddress);
  final insuranceDone = hasText(d.taxiInsuranceProvider) &&
      hasText(d.taxiInsurancePolicyNumber) &&
      d.taxiInsuranceExpiry != null &&
      hasText(d.taxiInsurancePhotoUrl);
  final licenceDone = d.rijbewijsVerified == true ||
      veriffDecisionLooksApproved(d.veriffStatus);
  final chauffeurDone =
      hasText(d.chauffeurspasNumber) && d.chauffeurspasExpiry != null;
  final vehicleAndApkDone = hasText(d.vehiclePlate) && d.apkExpiry != null;
  final termsDone = d.termsAcceptedAt != null;
  final shortQuizDone = d.indemnificationQuizPassed == true;
  final indemnificationDone = d.indemnificationReadAt != null && shortQuizDone;

  final checks = <bool>[
    pictureDone,
    carDone,
    kvkDone,
    insuranceDone,
    licenceDone,
    chauffeurDone,
    vehicleAndApkDone,
    termsDone,
    shortQuizDone,
    indemnificationDone,
  ];
  final completed = checks.where((it) => it).length;
  return DriverComplianceProgress(
    completed: completed,
    total: checks.length,
    licenseStepDone: licenceDone,
  );
}
