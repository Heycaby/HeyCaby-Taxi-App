import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';

class DriverBankTransferDetails {
  const DriverBankTransferDetails({
    required this.amount,
    required this.accountHolder,
    required this.iban,
    required this.bankName,
    required this.bic,
    required this.reference,
  });

  final String amount;
  final String accountHolder;
  final String iban;
  final String bankName;
  final String bic;
  final String reference;

  static DriverBankTransferDetails? fromBillingStatus(
    Map<String, dynamic>? status, {
    required String amount,
  }) {
    if (status?['bank_transfer_configured'] != true ||
        status?['settlement_method'] != 'bank_transfer') {
      return null;
    }
    final raw = status?['bank_transfer'];
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final details = DriverBankTransferDetails(
      amount: amount,
      accountHolder: data['account_holder']?.toString().trim() ?? '',
      iban: data['iban']?.toString().trim() ?? '',
      bankName: data['bank_name']?.toString().trim() ?? '',
      bic: data['bic']?.toString().trim() ?? '',
      reference: data['reference']?.toString().trim() ?? '',
    );
    return details.isComplete ? details : null;
  }

  bool get isComplete =>
      amount.isNotEmpty &&
      accountHolder.isNotEmpty &&
      iban.isNotEmpty &&
      bankName.isNotEmpty &&
      bic.isNotEmpty &&
      reference.isNotEmpty;
}

/// Returns `true` only when the driver explicitly chooses the online-payment
/// fallback. Closing the sheet never marks a bank transfer as paid.
Future<bool> showDriverBankTransferSheet({
  required BuildContext context,
  required DriverColors colors,
  required DriverTypography typography,
  required DriverBankTransferDetails details,
  bool allowOnlineFallback = true,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: colors.surface,
        barrierColor: colors.text.withValues(alpha: 0.34),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => _DriverBankTransferSheet(
          colors: colors,
          typography: typography,
          details: details,
          allowOnlineFallback: allowOnlineFallback,
        ),
      ) ??
      false;
}

class _DriverBankTransferSheet extends StatelessWidget {
  const _DriverBankTransferSheet({
    required this.colors,
    required this.typography,
    required this.details,
    required this.allowOnlineFallback,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final DriverBankTransferDetails details;
  final bool allowOnlineFallback;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.58,
      maxChildSize: 0.94,
      builder: (context, controller) => Column(
        children: [
          const SizedBox(height: DriverSpacing.sm),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                DriverSpacing.screenEdge,
                DriverSpacing.xl,
                DriverSpacing.screenEdge,
                DriverSpacing.xxl,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DriverStrings.platformBalanceBankTransferTitle,
                            style: typography.headlineSmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: DriverSpacing.xs),
                          Text(
                            DriverStrings.platformBalanceBankTransferSubtitle,
                            style: typography.bodyMedium.copyWith(
                              color: colors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: DriverStrings.close,
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                      color: colors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: DriverSpacing.xl),
                _AmountPanel(
                  colors: colors,
                  typography: typography,
                  amount: details.amount,
                ),
                const SizedBox(height: DriverSpacing.lg),
                _TransferRow(
                  colors: colors,
                  typography: typography,
                  label: DriverStrings.platformBalanceAccountHolder,
                  value: details.accountHolder,
                ),
                _TransferRow(
                  colors: colors,
                  typography: typography,
                  label: DriverStrings.platformBalanceIban,
                  value: details.iban,
                ),
                _TransferRow(
                  colors: colors,
                  typography: typography,
                  label: DriverStrings.platformBalanceBankName,
                  value: details.bankName,
                ),
                _TransferRow(
                  colors: colors,
                  typography: typography,
                  label: DriverStrings.platformBalanceBic,
                  value: details.bic,
                ),
                _TransferRow(
                  colors: colors,
                  typography: typography,
                  label: DriverStrings.platformBalancePaymentReference,
                  value: details.reference,
                  emphasized: true,
                ),
                const SizedBox(height: DriverSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(DriverSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colors.warning,
                        size: 22,
                      ),
                      const SizedBox(width: DriverSpacing.md),
                      Expanded(
                        child: Text(
                          DriverStrings.platformBalanceReferenceWarning,
                          style: typography.bodySmall.copyWith(
                            color: colors.text,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DriverSpacing.lg),
                Text(
                  DriverStrings.platformBalanceBankTransferTiming,
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (allowOnlineFallback) ...[
                  const SizedBox(height: DriverSpacing.xl),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: Text(
                      DriverStrings.platformBalancePayOnlineInstead,
                    ),
                  ),
                ],
                const SizedBox(height: DriverSpacing.md),
                FilledButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(DriverStrings.done),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountPanel extends StatelessWidget {
  const _AmountPanel({
    required this.colors,
    required this.typography,
    required this.amount,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DriverSpacing.xl),
      decoration: BoxDecoration(
        color: colors.backgroundAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DriverStrings.platformBalanceTransferAmount,
            style: typography.labelMedium.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DriverSpacing.xs),
          Text(
            amount,
            style: typography.displaySmall.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.colors,
    required this.typography,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String label;
  final String value;
  final bool emphasized;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(DriverStrings.platformBalanceCopied(label))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: typography.labelMedium.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: typography.bodyLarge.copyWith(
                    color: colors.text,
                    fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '${DriverStrings.platformBalanceCopy} $label',
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_rounded),
            color: colors.primary,
          ),
        ],
      ),
    );
  }
}
