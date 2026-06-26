import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

/// Parses `plans` from GET `/api/driver/status` (same shape as billing status payload).
/// Entries without a non-empty `code` are ignored. No client-side price fallback.
List<Map<String, dynamic>> parseServerBillingPlans(Map<String, dynamic>? status) {
  final raw = status?['plans'];
  final out = <Map<String, dynamic>>[];
  if (raw is! List) return out;
  for (final e in raw) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    if ((m['code'] ?? '').toString().trim().isEmpty) continue;
    out.add(m);
  }
  return out;
}

/// Shows plan radio dialog; returns selected plan `code`, or `null` if [plans] is empty (shows snackbar).
Future<String?> pickDriverBillingPlanCode(
  BuildContext context, {
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typo,
  required List<Map<String, dynamic>> plans,
}) async {
  if (plans.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.billingPlansUnavailable)),
      );
    }
    return null;
  }

  var selected = '';
  for (final p in plans) {
    final c = (p['code'] ?? '').toString().trim();
    if (c.isNotEmpty) {
      selected = c;
      break;
    }
  }
  if (selected.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DriverStrings.billingPlansUnavailable)),
      );
    }
    return null;
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(DriverStrings.billingChoosePlanTitle, style: typo.titleLarge),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final raw in plans)
                RadioListTile<String>(
                  value: (raw['code'] ?? '').toString(),
                  groupValue: selected,
                  onChanged: (v) {
                    if (v != null) setState(() => selected = v);
                  },
                  title: Text(
                    (raw['title'] ?? DriverStrings.billingPlanUnknown).toString(),
                  ),
                  subtitle: Text(
                    (raw['description'] ?? '').toString(),
                    style: typo.bodySmall.copyWith(color: colors.textSoft),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(DriverStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              HapticService.mediumTap();
              Navigator.pop(ctx, selected);
            },
            child: Text(DriverStrings.billingUseSelectedPlan),
          ),
        ],
      ),
    ),
  );
}
