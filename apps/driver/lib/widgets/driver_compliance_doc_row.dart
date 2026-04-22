import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

/// Status chip for a single compliance document row.
class DriverComplianceDocRow extends StatelessWidget {
  const DriverComplianceDocRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chipLabel,
    required this.chipColor,
    required this.chipBg,
    required this.colors,
    required this.typo,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String chipLabel;
  final Color chipColor;
  final Color chipBg;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, size: 22, color: colors.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: typo.bodyLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: typo.bodySmall.copyWith(color: colors.textMid, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing!
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chipLabel,
                    style: typo.labelSmall.copyWith(
                      color: chipColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Maps overall `compliance_status` to user-facing title + colors.
({String title, Color fg, Color bg}) complianceBannerStyle(
  String? status,
  HeyCabyColorTokens colors,
) {
  final s = (status ?? '').toLowerCase();
  if (s == 'compliant') {
    return (
      title: DriverStrings.complianceCompliant,
      fg: colors.success,
      bg: colors.success.withValues(alpha: 0.12),
    );
  }
  if (s == 'pending_review' || s == 'pending') {
    return (
      title: DriverStrings.compliancePending,
      fg: colors.warning,
      bg: colors.warning.withValues(alpha: 0.14),
    );
  }
  if (s == 'suspended') {
    return (
      title: DriverStrings.complianceSuspended,
      fg: colors.error,
      bg: colors.error.withValues(alpha: 0.12),
    );
  }
  if (s == 'rejected') {
    return (
      title: DriverStrings.complianceRejected,
      fg: colors.error,
      bg: colors.error.withValues(alpha: 0.1),
    );
  }
  return (
    title: DriverStrings.complianceIncomplete,
    fg: colors.textMid,
    bg: colors.border.withValues(alpha: 0.35),
  );
}
