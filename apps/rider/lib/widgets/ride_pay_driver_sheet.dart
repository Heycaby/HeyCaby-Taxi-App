import 'package:flutter/material.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

class RidePayDriverResult {
  const RidePayDriverResult({
    required this.confirmed,
    this.tipEuro,
  });

  final bool confirmed;
  final double? tipEuro;
}

/// Rider payment reminder when the driver ends the trip — fare, optional tip, total.
Future<RidePayDriverResult?> showRidePayDriverSheet(
  BuildContext context, {
  required HeyCabyColorTokens colors,
  required HeyCabyTypography typography,
  required AppLocalizations l10n,
  String? fareLabel,
  required String paymentMethodTitle,
  String? paymentMethodSubtitle,
}) async {
  return showModalBottomSheet<RidePayDriverResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.48),
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => _RidePayDriverSheet(
      colors: colors,
      typography: typography,
      l10n: l10n,
      fareEuro: parseEuroAmountLabel(fareLabel),
      paymentMethodTitle: paymentMethodTitle,
      paymentMethodSubtitle: paymentMethodSubtitle,
    ),
  );
}

double? parseEuroAmountLabel(String? raw) {
  if (raw == null || raw.trim().isEmpty || raw.trim() == '—') return null;
  final cleaned = raw
      .replaceAll('€', '')
      .replaceAll(RegExp(r'EUR', caseSensitive: false), '')
      .trim()
      .replaceAll(',', '.');
  return double.tryParse(cleaned);
}

String formatEuroAmount(double value) => '€${value.toStringAsFixed(2)}';

String riderPaymentMethodTitle(
  AppLocalizations l10n,
  List<String> paymentMethods,
) {
  if (paymentMethods.isEmpty) return l10n.cash;
  final raw = paymentMethods.first.trim().toLowerCase();
  return switch (raw) {
    'cash' => l10n.cash,
    'pin' => 'PIN',
    'tikkie' => l10n.tikkie,
    _ => raw
        .split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' '),
  };
}

String? riderPaymentMethodSubtitle(
  AppLocalizations l10n,
  List<String> paymentMethods,
) {
  if (paymentMethods.isEmpty) return l10n.pinSubtitle;
  final raw = paymentMethods.first.trim().toLowerCase();
  return switch (raw) {
    'cash' => l10n.cash,
    'pin' => l10n.pinSubtitle,
    'tikkie' => l10n.tikkieSubtitle,
    _ => null,
  };
}

class _RidePayDriverSheet extends StatefulWidget {
  const _RidePayDriverSheet({
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.fareEuro,
    required this.paymentMethodTitle,
    required this.paymentMethodSubtitle,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typography;
  final AppLocalizations l10n;
  final double? fareEuro;
  final String paymentMethodTitle;
  final String? paymentMethodSubtitle;

  @override
  State<_RidePayDriverSheet> createState() => _RidePayDriverSheetState();
}

class _RidePayDriverSheetState extends State<_RidePayDriverSheet> {
  static const List<int> _presetTips = [1, 2, 3, 5];
  static const double _scale = 1.1;

  bool _tipExpanded = false;
  int? _selectedTip;
  bool _customTip = false;
  final _customTipController = TextEditingController();

  @override
  void dispose() {
    _customTipController.dispose();
    super.dispose();
  }

  double? get _tipEuro {
    if (!_tipExpanded) return null;
    if (_customTip) {
      return double.tryParse(_customTipController.text.trim().replaceAll(',', '.'));
    }
    return _selectedTip?.toDouble();
  }

  double? get _totalEuro {
    final fare = widget.fareEuro;
    final tip = _tipEuro;
    if (fare == null && tip == null) return null;
    return (fare ?? 0) + (tip ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typography = widget.typography;
    final l10n = widget.l10n;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final fare = widget.fareEuro;
    final tip = _tipEuro;
    final total = _totalEuro;
    final fareLabel =
        fare != null ? formatEuroAmount(fare) : '—';
    final totalLabel =
        total != null && total > 0 ? formatEuroAmount(total) : fareLabel;
    final iconSize = 58.0 * _scale;
    final buttonHeight = 58.0 * _scale;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 14),
        child: GlassPanel(
          colors: colors,
          typography: typography,
          padding: EdgeInsets.fromLTRB(
            22 * _scale,
            12 * _scale,
            22 * _scale,
            22 * _scale,
          ),
          borderRadius: BorderRadius.circular(30 * _scale),
          tintColor: colors.card,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48 * _scale,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                SizedBox(height: 20 * _scale),
                Center(
                  child: Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: MoneySilhouetteIcon(
                        color: colors.warning,
                        size: 30 * _scale,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 18 * _scale),
                Text(
                  l10n.ridePayDriverTitle,
                  textAlign: TextAlign.center,
                  style: typography.titleLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: (typography.titleLarge.fontSize ?? 22) * _scale,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 10 * _scale),
                Text(
                  l10n.ridePayDriverBody,
                  textAlign: TextAlign.center,
                  style: typography.bodyMedium.copyWith(
                    color: colors.textMid,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 20 * _scale),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * _scale,
                    vertical: 18 * _scale,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20 * _scale),
                    border: Border.all(
                      color: colors.warning.withValues(alpha: 0.32),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (tip != null && tip > 0) ...[
                        _PayLineRow(
                          label: l10n.ridePayDriverFareLine,
                          amount: fareLabel,
                          colors: colors,
                          typo: typography,
                        ),
                        SizedBox(height: 6 * _scale),
                        _PayLineRow(
                          label: l10n.ridePayDriverTipLine,
                          amount: formatEuroAmount(tip),
                          colors: colors,
                          typo: typography,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 10 * _scale),
                          child: Divider(
                            color: colors.border.withValues(alpha: 0.8),
                            height: 1,
                          ),
                        ),
                        Text(
                          l10n.ridePayDriverTotalCaption,
                          textAlign: TextAlign.center,
                          style: typography.labelLarge.copyWith(
                            color: colors.textMid,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6 * _scale),
                        Text(
                          totalLabel,
                          textAlign: TextAlign.center,
                          style: typography.displaySmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 44 * _scale,
                            height: 1.05,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ] else ...[
                        Text(
                          l10n.ridePayDriverAmountCaption,
                          textAlign: TextAlign.center,
                          style: typography.labelLarge.copyWith(
                            color: colors.textMid,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8 * _scale),
                        Text(
                          fareLabel,
                          textAlign: TextAlign.center,
                          style: typography.displaySmall.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 42 * _scale,
                            height: 1.05,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 12 * _scale),
                if (!_tipExpanded)
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticService.lightTap();
                      setState(() => _tipExpanded = true);
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(l10n.ridePayDriverAddTip),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(48 * _scale),
                      foregroundColor: colors.accent,
                      side: BorderSide(color: colors.accent.withValues(alpha: 0.45)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14 * _scale),
                      ),
                    ),
                  )
                else ...[
                  Text(
                    l10n.tipDriverTitle,
                    textAlign: TextAlign.center,
                    style: typography.bodySmall.copyWith(
                      color: colors.textMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 10 * _scale),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._presetTips.map((amount) {
                        final selected = !_customTip && _selectedTip == amount;
                        return _TipChip(
                          label: '€$amount',
                          selected: selected,
                          colors: colors,
                          typo: typography,
                          onTap: () {
                            HapticService.lightTap();
                            setState(() {
                              _selectedTip = amount;
                              _customTip = false;
                            });
                          },
                        );
                      }),
                      _TipChip(
                        label: l10n.tipAmountCustom,
                        selected: _customTip,
                        colors: colors,
                        typo: typography,
                        onTap: () {
                          HapticService.lightTap();
                          setState(() {
                            _customTip = true;
                            _selectedTip = null;
                          });
                        },
                      ),
                    ],
                  ),
                  if (_customTip) ...[
                    SizedBox(height: 10 * _scale),
                    Center(
                      child: SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _customTipController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixText: '€ ',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colors.accent, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
                SizedBox(height: 14 * _scale),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * _scale,
                    vertical: 14 * _scale,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accentL.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16 * _scale),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        l10n.ridePayDriverPayVia(widget.paymentMethodTitle),
                        textAlign: TextAlign.center,
                        style: typography.titleSmall.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (widget.paymentMethodSubtitle != null &&
                          widget.paymentMethodSubtitle!.trim().isNotEmpty) ...[
                        SizedBox(height: 4 * _scale),
                        Text(
                          widget.paymentMethodSubtitle!,
                          textAlign: TextAlign.center,
                          style: typography.bodySmall.copyWith(
                            color: colors.textMid,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 24 * _scale),
                FilledButton(
                  onPressed: () {
                    HapticService.lightTap();
                    Navigator.of(context).pop(
                      const RidePayDriverResult(confirmed: false),
                    );
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(buttonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18 * _scale),
                    ),
                  ),
                  child: Text(l10n.ridePayDriverDismiss),
                ),
                SizedBox(height: 11 * _scale),
                OutlinedButton(
                  onPressed: () {
                    HapticService.mediumTap();
                    final tipValue = _tipEuro;
                    Navigator.of(context).pop(
                      RidePayDriverResult(
                        confirmed: true,
                        tipEuro: tipValue != null && tipValue > 0
                            ? tipValue
                            : null,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(buttonHeight),
                    foregroundColor: colors.accent,
                    side: BorderSide(
                      color: colors.accent.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18 * _scale),
                    ),
                  ),
                  child: Text(
                    total != null && total > 0
                        ? l10n.ridePayDriverConfirmWithTotal(totalLabel)
                        : l10n.ridePayDriverConfirm,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PayLineRow extends StatelessWidget {
  const _PayLineRow({
    required this.label,
    required this.amount,
    required this.colors,
    required this.typo,
  });

  final String label;
  final String amount;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: typo.bodyMedium.copyWith(
            color: colors.textMid,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          amount,
          style: typo.titleSmall.copyWith(
            color: colors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.12)
              : colors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: typo.bodyMedium.copyWith(
            color: selected ? colors.accent : colors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
