import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../models/trip_category_estimate.dart';

class SmartVehicleBundleCategoryRow extends StatelessWidget {
  const SmartVehicleBundleCategoryRow({
    super.key,
    required this.estimate,
    required this.selected,
    required this.colors,
    required this.typo,
    required this.onChanged,
  });

  final TripCategoryEstimate estimate;
  final bool selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final ValueChanged<bool> onChanged;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: selected
            ? colors.accent.withValues(alpha: 0.07)
            : colors.surface.withValues(alpha: 0.55),
        border: Border.all(
          color: selected
              ? colors.accent.withValues(alpha: 0.4)
              : colors.border.withValues(alpha: 0.75),
          width: 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: -4,
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estimate.label,
                  style: typo.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.accent.withValues(alpha: 0.12)
                        : colors.bgAlt.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '€${_fmt(estimate.priceEuro)}',
                    style: typo.labelLarge.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: selected,
            onChanged: onChanged,
            activeTrackColor: colors.accent,
          ),
        ],
      ),
    );
  }
}
