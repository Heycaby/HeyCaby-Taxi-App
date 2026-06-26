import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../models/driver_runtime_models.dart';
import '../utils/driver_readiness_routes.dart';

class DriverDynamicChecklistCard extends StatelessWidget {
  const DriverDynamicChecklistCard({
    super.key,
    required this.items,
    required this.colors,
    required this.typo,
    this.onIncompleteItemTapped,
  });

  final List<DriverReadinessItem> items;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  /// When set, incomplete rows with a known route become tappable (e.g. open profile / documents).
  final void Function(DriverReadinessItem item)? onIncompleteItemTapped;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ChecklistRow(
                  item: item,
                  colors: colors,
                  typo: typo,
                  onIncompleteItemTapped: onIncompleteItemTapped,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.colors,
    required this.typo,
    this.onIncompleteItemTapped,
  });

  final DriverReadinessItem item;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final void Function(DriverReadinessItem item)? onIncompleteItemTapped;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          item.complete ? Icons.check_circle : Icons.radio_button_unchecked,
          color: item.complete ? colors.success : colors.textSoft,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: typo.bodyMedium.copyWith(
                  color: item.complete ? colors.textSoft : colors.text,
                  fontWeight: item.complete ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
              if (item.note != null && item.note!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.note!,
                    style: typo.bodySmall.copyWith(color: colors.textMid),
                  ),
                ),
            ],
          ),
        ),
        if (!item.complete &&
            onIncompleteItemTapped != null &&
            flutterRouteForReadinessItem(item) != null)
          Icon(Icons.chevron_right_rounded, color: colors.textSoft, size: 22),
      ],
    );

    final tappable = !item.complete &&
        onIncompleteItemTapped != null &&
        flutterRouteForReadinessItem(item) != null;

    if (!tappable) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onIncompleteItemTapped!(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: content,
        ),
      ),
    );
  }
}
