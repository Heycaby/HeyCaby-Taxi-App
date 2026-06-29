import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../widgets/booking/booking_flow_screen_header.dart';

class RiderReceiptScreen extends ConsumerWidget {
  const RiderReceiptScreen({super.key, required this.rideRequestId});

  final String rideRequestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final receiptAsync = ref.watch(_receiptProvider(rideRequestId));

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingFlowScreenHeader(
              colors: colors,
              typo: typo,
              title: l10n.rideReceiptTitle,
              icon: Icons.receipt_long_rounded,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 24),
                child: receiptAsync.when(
                  data: (receipt) {
                    if (receipt == null) {
                      return Center(
                        child: Text(
                          l10n.rideReceiptUnavailable,
                          style: typo.bodyMedium.copyWith(color: colors.textMid),
                        ),
                      );
                    }

                    final expected = _tryParseAmount(receipt['expected_amount']);
                    final paid = _tryParseAmount(receipt['paid_amount']);
                    final method = receipt['payment_method']?.toString();
                    final note = receipt['note']?.toString();
                    final diff = (expected != null && paid != null)
                        ? (paid - expected)
                        : null;

                    return SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: colors.text.withValues(alpha: 0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.rideReceiptSettlement,
                              style: typo.titleSmall.copyWith(
                                color: colors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _Row(
                              label: l10n.rideReceiptRideId,
                              value: rideRequestId,
                              colors: colors,
                              typo: typo,
                            ),
                            if (expected != null)
                              _Row(
                                label: l10n.rideReceiptExpected,
                                value: 'EUR ${expected.toStringAsFixed(2)}',
                                colors: colors,
                                typo: typo,
                              ),
                            if (paid != null)
                              _Row(
                                label: l10n.rideReceiptPaid,
                                value: 'EUR ${paid.toStringAsFixed(2)}',
                                colors: colors,
                                typo: typo,
                              ),
                            if (method != null && method.isNotEmpty)
                              _Row(
                                label: l10n.rideReceiptMethod,
                                value: method,
                                colors: colors,
                                typo: typo,
                              ),
                            if (note != null && note.isNotEmpty)
                              _Row(
                                label: l10n.rideReceiptNote,
                                value: note,
                                colors: colors,
                                typo: typo,
                              ),
                            if (diff != null && diff < 0)
                              _Row(
                                label: l10n.rideReceiptOutstanding,
                                value: 'EUR ${diff.abs().toStringAsFixed(2)}',
                                colors: colors,
                                typo: typo,
                                valueColor: colors.error,
                              ),
                            if (diff != null && diff > 0)
                              _Row(
                                label: l10n.rideReceiptOverpaid,
                                value: 'EUR ${diff.toStringAsFixed(2)}',
                                colors: colors,
                                typo: typo,
                                valueColor: colors.success,
                              ),
                            if (diff != null && diff == 0)
                              _Row(
                                label: l10n.rideReceiptStatus,
                                value: l10n.rideReceiptSettlementComplete,
                                colors: colors,
                                typo: typo,
                                valueColor: colors.success,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  ),
                  error: (_, __) => Center(
                    child: Text(
                      l10n.rideDetailReceiptLoadFailed,
                      style: typo.bodyMedium.copyWith(color: colors.textMid),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _receiptProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, rideId) async {
  final api = ref.read(riderApiProvider);
  return api.fetchRideReceipt(rideRequestId: rideId);
});

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.colors,
    required this.typo,
    this.valueColor,
  });

  final String label;
  final String value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: typo.bodySmall.copyWith(color: colors.textMid),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: typo.bodyMedium.copyWith(
                color: valueColor ?? colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double? _tryParseAmount(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
}
