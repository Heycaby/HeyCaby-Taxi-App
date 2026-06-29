import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

/// Parses `plans` from GET `/api/driver/status` (same shape as billing status payload).
/// Entries without a non-empty `code` are ignored. No client-side price fallback.
List<Map<String, dynamic>> parseServerBillingPlans(
    Map<String, dynamic>? status) {
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
        const SnackBar(content: Text(DriverStrings.billingPlansUnavailable)),
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
        const SnackBar(content: Text(DriverStrings.billingPlansUnavailable)),
      );
    }
    return null;
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title:
            Text(DriverStrings.billingChoosePlanTitle, style: typo.titleLarge),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final raw in plans) ...[
                _BillingPlanChoice(
                  code: (raw['code'] ?? '').toString(),
                  title: (raw['title'] ?? DriverStrings.billingPlanUnknown)
                      .toString(),
                  description: (raw['description'] ?? '').toString(),
                  selected: selected == (raw['code'] ?? '').toString(),
                  colors: colors,
                  typo: typo,
                  onSelected: (code) => setState(() => selected = code),
                ),
                const SizedBox(height: 10),
              ],
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
            child: const Text(DriverStrings.billingUseSelectedPlan),
          ),
        ],
      ),
    ),
  );
}

class _BillingPlanChoice extends StatelessWidget {
  const _BillingPlanChoice({
    required this.code,
    required this.title,
    required this.description,
    required this.selected,
    required this.colors,
    required this.typo,
    required this.onSelected,
  });

  final String code;
  final String title;
  final String description;
  final bool selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onSelected(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.1)
              : colors.card.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? colors.accent
                : colors.border.withValues(alpha: 0.72),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? colors.accent : colors.textSoft,
                  width: selected ? 6 : 1.5,
                ),
                color: colors.card,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typo.titleSmall.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (description.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: typo.bodySmall.copyWith(
                        color: colors.textSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
