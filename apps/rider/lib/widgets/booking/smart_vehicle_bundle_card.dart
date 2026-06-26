import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../../models/trip_category_estimate.dart';
import 'smart_vehicle_bundle_category_row.dart';

/// Collapsible card: trip price band + per-category toggles + pet-friendly (Supabase estimates).
class SmartVehicleBundleCard extends StatefulWidget {
  const SmartVehicleBundleCard({
    super.key,
    required this.estimates,
    required this.selectedKeys,
    required this.onSelectionChanged,
    required this.colors,
    required this.typography,
    required this.l10n,
  });

  final List<TripCategoryEstimate> estimates;
  final Set<String> selectedKeys;
  final ValueChanged<Set<String>> onSelectionChanged;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final AppLocalizations l10n;

  @override
  State<SmartVehicleBundleCard> createState() => _SmartVehicleBundleCardState();
}

class _SmartVehicleBundleCardState extends State<SmartVehicleBundleCard> {
  // Keep options visible by default so riders don't need to guess they can tap.
  bool _expanded = true;

  List<TripCategoryEstimate> get _est => widget.estimates;

  Set<String> get _sel => widget.selectedKeys;

  ({double min, double max}) _bandFor(Set<String> keys) {
    final prices = _est
        .where((e) => keys.contains(e.categoryKey))
        .map((e) => e.priceEuro)
        .toList();
    if (prices.isEmpty) return (min: 0, max: 0);
    prices.sort();
    return (min: prices.first, max: prices.last);
  }

  String _priceLabel() {
    final b = _bandFor(_sel);
    if (b.min <= 0 && b.max <= 0) return '—';
    final formatter = NumberFormat.currency(
      locale: 'nl_NL',
      symbol: '€',
      decimalDigits: 0,
    );
    final min = formatter.format(b.min);
    final max = formatter.format(b.max);
    return widget.l10n.smartBundleEstimatedPrice(min, max);
  }

  String _footnote() {
    if (_sel.length >= _est.length) return widget.l10n.smartBundleFootnoteWide;
    return widget.l10n.smartBundleFootnoteNarrow;
  }

  void _toggleExpanded() {
    HapticService.lightTap();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typo = widget.typography;
    final l10n = widget.l10n;

    const radius = 24.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colors.card, colors.accentL, 0.22)!,
            colors.card,
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: _expanded
              ? colors.accent.withValues(alpha: 0.38)
              : colors.border.withValues(alpha: 0.9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.045),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleExpanded,
                splashColor: colors.accent.withValues(alpha: 0.06),
                highlightColor: colors.accent.withValues(alpha: 0.04),
                child: Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(18, 16, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.accent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(
                              Icons.layers_outlined,
                              color: colors.accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.smartBundleRideTypeOptions,
                                  style: typo.labelSmall.copyWith(
                                    color: colors.accent,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _priceLabel(),
                                  style: typo.headingSmall.copyWith(
                                    color: colors.text,
                                    fontWeight: FontWeight.w800,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.smartBundleDriverPricingNote,
                                  style: typo.bodyMedium.copyWith(
                                    color: colors.text,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: colors.textMid,
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _expanded
                            ? l10n.smartBundleTapToHide
                            : l10n.smartBundleTapToExpand,
                        style: typo.titleMedium.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.smartBundleExpandSubtitle,
                        style: typo.bodyMedium.copyWith(
                          color: colors.textMid,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          14, 12, 14, 12,
                        ),
                        decoration: BoxDecoration(
                          color: colors.bgAlt.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.65),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _footnote(),
                                style: typo.bodySmall.copyWith(
                                  color: colors.textMid,
                                  height: 1.4,
                                ),
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
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 16),
                child: Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.border.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < _est.length; i++) ...[
                      SmartVehicleBundleCategoryRow(
                        estimate: _est[i],
                        selected: _sel.contains(_est[i].categoryKey),
                        colors: colors,
                        typo: typo,
                        onChanged: (on) {
                          final next = Set<String>.from(_sel);
                          if (on) {
                            next.add(_est[i].categoryKey);
                          } else {
                            if (next.length <= 1) return;
                            next.remove(_est[i].categoryKey);
                          }
                          widget.onSelectionChanged(next);
                        },
                      ),
                      if (i < _est.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 260),
            ),
          ],
        ),
      ),
    );
  }
}
