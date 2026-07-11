import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/rider_receipt_provider.dart';
import '../widgets/booking/booking_flow_screen_header.dart';

class RiderReceiptScreen extends ConsumerWidget {
  const RiderReceiptScreen({super.key, required this.rideRequestId});

  final String rideRequestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final receiptAsync = ref.watch(riderReceiptProvider(rideRequestId));

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
              child: receiptAsync.when(
                data: (receipt) {
                  if (receipt == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.rideReceiptUnavailable,
                          textAlign: TextAlign.center,
                          style:
                              typo.bodyMedium.copyWith(color: colors.textMid),
                        ),
                      ),
                    );
                  }

                  return _ReceiptContent(
                    receipt: receipt,
                    rideRequestId: rideRequestId,
                    colors: colors,
                    typo: typo,
                    l10n: l10n,
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.accent),
                ),
                error: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.rideDetailReceiptLoadFailed,
                      textAlign: TextAlign.center,
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

class _ReceiptContent extends StatelessWidget {
  const _ReceiptContent({
    required this.receipt,
    required this.rideRequestId,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final Map<String, dynamic> receipt;
  final String rideRequestId;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final baseFare = _tryParseAmount(receipt['base_expected_amount']);
    final expected = _tryParseAmount(receipt['expected_amount']);
    final paid = _tryParseAmount(receipt['paid_amount']);
    final waitingFee = _tryParseAmount(receipt['waiting_fee_amount']);
    final waitingWaived = receipt['waiting_fee_waived'] == true;
    final chargeableWaitSeconds =
        _tryParseInt(receipt['chargeable_wait_seconds']) ?? 0;
    final method = receipt['payment_method']?.toString();
    final note = receipt['note']?.toString();
    final receiptId = receipt['receipt_id']?.toString();
    final currency = receipt['currency']?.toString() ?? 'EUR';
    final pickupAddress = receipt['pickup_address']?.toString().trim();
    final destinationAddress =
        receipt['destination_address']?.toString().trim();
    final completedAt = _parseDateTime(
      receipt['completed_at'] ?? receipt['issued_at'],
    );
    final diff = (expected != null && paid != null) ? paid - expected : null;

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 28),
      children: [
        if (completedAt != null) ...[
          Text(
            DateFormat.yMMMd(
              Localizations.localeOf(context).toString(),
            ).add_jm().format(completedAt.toLocal()),
            style: typo.bodyMedium.copyWith(
              color: colors.textMid,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if ((pickupAddress != null && pickupAddress.isNotEmpty) ||
            (destinationAddress != null && destinationAddress.isNotEmpty))
          _ReceiptRouteCard(
            colors: colors,
            typo: typo,
            l10n: l10n,
            pickupAddress: pickupAddress ?? '',
            destinationAddress: destinationAddress ?? '',
          ),
        if ((pickupAddress != null && pickupAddress.isNotEmpty) ||
            (destinationAddress != null && destinationAddress.isNotEmpty))
          const SizedBox(height: 14),
        _ReceiptHero(
          amount: paid ?? expected,
          currency: currency,
          diff: diff,
          colors: colors,
          typo: typo,
          l10n: l10n,
        ),
        const SizedBox(height: 14),
        _ReceiptBreakdownCard(
          colors: colors,
          typo: typo,
          l10n: l10n,
          rows: [
            if (baseFare != null)
              _ReceiptRowData(
                icon: Icons.local_taxi_rounded,
                label: l10n.rideReceiptBaseFare,
                value: _formatMoney(baseFare, currency),
              ),
            if (waitingFee != null && (waitingFee > 0 || waitingWaived))
              _ReceiptRowData(
                icon: waitingWaived
                    ? Icons.volunteer_activism_rounded
                    : Icons.timer_rounded,
                label: waitingWaived
                    ? l10n.rideReceiptWaitingWaived
                    : l10n.rideReceiptWaitingFee,
                value: _formatMoney(waitingFee, currency),
                valueColor: waitingWaived ? colors.success : null,
              ),
            if (chargeableWaitSeconds > 0)
              _ReceiptRowData(
                icon: Icons.av_timer_rounded,
                label: l10n.rideReceiptChargeableWait,
                value: l10n.rideReceiptSeconds(chargeableWaitSeconds),
              ),
            if (expected != null)
              _ReceiptRowData(
                icon: Icons.receipt_long_rounded,
                label: l10n.rideReceiptExpected,
                value: _formatMoney(expected, currency),
                emphasized: true,
              ),
            if (paid != null)
              _ReceiptRowData(
                icon: Icons.check_circle_rounded,
                label: l10n.rideReceiptPaid,
                value: _formatMoney(paid, currency),
                valueColor: colors.success,
                emphasized: true,
              ),
            if (method != null && method.isNotEmpty)
              _ReceiptRowData(
                icon: Icons.payments_rounded,
                label: l10n.rideReceiptMethod,
                value: method,
              ),
            if (receiptId != null && receiptId.isNotEmpty)
              _ReceiptRowData(
                icon: Icons.tag_rounded,
                label: l10n.rideReceiptReference,
                value: receiptId,
              ),
            _ReceiptRowData(
              icon: Icons.confirmation_number_rounded,
              label: l10n.rideReceiptRideId,
              value: _compactId(rideRequestId),
            ),
            if (note != null && note.isNotEmpty)
              _ReceiptRowData(
                icon: Icons.notes_rounded,
                label: l10n.rideReceiptNote,
                value: note,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _ReceiptTrustCard(colors: colors, typo: typo, l10n: l10n),
        const SizedBox(height: 14),
        _ReceiptShareBar(
          receipt: receipt,
          rideRequestId: rideRequestId,
          colors: colors,
          typo: typo,
          l10n: l10n,
        ),
      ],
    );
  }
}

class _ReceiptRouteCard extends StatelessWidget {
  const _ReceiptRouteCard({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.pickupAddress,
    required this.destinationAddress,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final String pickupAddress;
  final String destinationAddress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.yourRoute,
            style: typo.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (pickupAddress.isNotEmpty)
            _RouteStopRow(
              colors: colors,
              typo: typo,
              dotColor: colors.accent,
              label: l10n.pickup,
              address: pickupAddress,
            ),
          if (pickupAddress.isNotEmpty && destinationAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 11, top: 4, bottom: 4),
              child: Container(width: 2, height: 18, color: colors.border),
            ),
          if (destinationAddress.isNotEmpty)
            _RouteStopRow(
              colors: colors,
              typo: typo,
              dotColor: colors.text,
              label: l10n.destination,
              address: destinationAddress,
            ),
        ],
      ),
    );
  }
}

class _RouteStopRow extends StatelessWidget {
  const _RouteStopRow({
    required this.colors,
    required this.typo,
    required this.dotColor,
    required this.label,
    required this.address,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final Color dotColor;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: typo.labelMedium.copyWith(
                  color: colors.textMid,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: typo.bodyMedium.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReceiptHero extends StatelessWidget {
  const _ReceiptHero({
    required this.amount,
    required this.currency,
    required this.diff,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final double? amount;
  final String currency;
  final double? diff;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final statusLabel = diff == null
        ? l10n.rideReceiptSettlement
        : diff! < 0
            ? l10n.rideReceiptOutstanding
            : diff! > 0
                ? l10n.rideReceiptOverpaid
                : l10n.rideReceiptSettlementComplete;
    final statusColor = diff == null
        ? colors.accent
        : diff! < 0
            ? colors.error
            : colors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.card,
            colors.accentL.withValues(alpha: 0.72),
            colors.card,
          ],
        ),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: colors.onAccent,
                  size: 28,
                ),
              ),
              const Spacer(),
              _StatusPill(
                label: statusLabel,
                color: statusColor,
                colors: colors,
                typo: typo,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            l10n.rideReceiptPaidTitle,
            style: typo.bodyMedium.copyWith(
              color: colors.textMid,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount != null ? _formatMoney(amount!, currency) : '--',
            style: typo.displayMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptBreakdownCard extends StatelessWidget {
  const _ReceiptBreakdownCard({
    required this.colors,
    required this.typo,
    required this.l10n,
    required this.rows,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;
  final List<_ReceiptRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.rideReceiptFareBreakdown,
            style: typo.titleMedium.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...rows.map(
            (row) => _ReceiptRow(
              data: row,
              colors: colors,
              typo: typo,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptTrustCard extends StatelessWidget {
  const _ReceiptTrustCard({
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.accentL.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.rideReceiptBusinessReady,
                  style: typo.titleSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.rideReceiptBusinessReadyBody,
                  style: typo.bodySmall.copyWith(
                    color: colors.textMid,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.data,
    required this.colors,
    required this.typo,
  });

  final _ReceiptRowData data;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(data.icon, color: colors.textMid, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                data.label,
                style: typo.bodyMedium.copyWith(
                  color: colors.textMid,
                  fontWeight:
                      data.emphasized ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                data.value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: typo.bodyMedium.copyWith(
                  color: data.valueColor ?? colors.text,
                  fontWeight:
                      data.emphasized ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.colors,
    required this.typo,
  });

  final String label;
  final Color color;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: typo.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReceiptRowData {
  const _ReceiptRowData({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;
}

double? _tryParseAmount(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
}

int? _tryParseInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw.toString());
}

String _formatMoney(double amount, String currency) {
  final normalized = currency.toUpperCase();
  if (normalized == 'EUR') {
    return '€${amount.toStringAsFixed(2)}';
  }
  return '$normalized ${amount.toStringAsFixed(2)}';
}

String _compactId(String value) {
  if (value.length <= 12) return value;
  return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
}

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

String _buildReceiptText(Map<String, dynamic> receipt, String rideRequestId) {
  final expected = _tryParseAmount(receipt['expected_amount']);
  final paid = _tryParseAmount(receipt['paid_amount']);
  final method = receipt['payment_method']?.toString() ?? 'cash';
  final receiptId = receipt['receipt_id']?.toString() ?? '—';
  final pickup = receipt['pickup_address']?.toString().trim() ?? '—';
  final dest = receipt['destination_address']?.toString().trim() ?? '—';
  final completedAt = _parseDateTime(receipt['completed_at'] ?? receipt['issued_at']);
  final currency = receipt['currency']?.toString() ?? 'EUR';

  final lines = <String>[
    'HeyCaby — Ride Receipt',
    'Receipt ID: $receiptId',
    'Ride ID: $rideRequestId',
    if (completedAt != null)
      'Date: ${DateFormat.yMMMd().add_Hm().format(completedAt.toLocal())}',
    '',
    'From: $pickup',
    'To: $dest',
    '',
    if (expected != null) 'Expected: ${_formatMoney(expected, currency)}',
    if (paid != null) 'Paid: ${_formatMoney(paid, currency)}',
    'Payment method: $method',
    '',
    'HeyCaby — Independent taxi platform',
  ];
  return lines.join('\n');
}

Future<List<int>> _buildReceiptPdfBytes(
  Map<String, dynamic> receipt,
  String rideRequestId,
) async {
  final expected = _tryParseAmount(receipt['expected_amount']);
  final paid = _tryParseAmount(receipt['paid_amount']);
  final baseFare = _tryParseAmount(receipt['base_expected_amount']);
  final waitingFee = _tryParseAmount(receipt['waiting_fee_amount']);
  final waitingWaived = receipt['waiting_fee_waived'] == true;
  final method = receipt['payment_method']?.toString() ?? 'cash';
  final receiptId = receipt['receipt_id']?.toString() ?? '—';
  final pickup = receipt['pickup_address']?.toString().trim() ?? '';
  final dest = receipt['destination_address']?.toString().trim() ?? '';
  final completedAt = _parseDateTime(receipt['completed_at'] ?? receipt['issued_at']);
  final currency = receipt['currency']?.toString() ?? 'EUR';
  final note = receipt['note']?.toString();

  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 16),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 2)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('HeyCaby',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Ride Receipt',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        _pdfRow('Receipt ID', receiptId),
        _pdfRow('Ride ID', rideRequestId),
        if (completedAt != null)
          _pdfRow('Date',
              DateFormat.yMMMd().add_Hm().format(completedAt.toLocal())),
        pw.SizedBox(height: 16),
        pw.Text('Route',
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        _pdfRow('From', pickup),
        _pdfRow('To', dest),
        pw.SizedBox(height: 16),
        pw.Text('Fare Breakdown',
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (baseFare != null) _pdfRow('Base fare', _formatMoney(baseFare, currency)),
        if (waitingFee != null && (waitingFee > 0 || waitingWaived))
          _pdfRow(
              waitingWaived ? 'Waiting fee (waived)' : 'Waiting fee',
              _formatMoney(waitingFee, currency)),
        if (expected != null)
          _pdfRow('Expected total', _formatMoney(expected, currency)),
        if (paid != null) _pdfRow('Paid', _formatMoney(paid, currency)),
        _pdfRow('Payment method', method),
        if (note != null && note.isNotEmpty) _pdfRow('Note', note),
        pw.SizedBox(height: 24),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            'HeyCaby — Independent taxi platform. This receipt is generated for your records.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _pdfRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 140,
          child: pw.Text(label,
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 11)),
        ),
        pw.Expanded(
          child: pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    ),
  );
}

class _ReceiptShareBar extends StatelessWidget {
  const _ReceiptShareBar({
    required this.receipt,
    required this.rideRequestId,
    required this.colors,
    required this.typo,
    required this.l10n,
  });

  final Map<String, dynamic> receipt;
  final String rideRequestId;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _shareViaWhatsApp(context),
              icon: const Icon(Icons.share_outlined, size: 20),
              label: Text(l10n.rideReceiptShareWhatsapp),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _shareViaEmail(context),
              icon: const Icon(Icons.mail_outline, size: 20),
              label: Text(l10n.rideReceiptShareEmail),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.text,
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdfBytes = await _buildReceiptPdfBytes(receipt, rideRequestId);
      final tmp = await getTemporaryDirectory();
      final file = File(
        '${tmp.path}/heycaby_receipt_${rideRequestId.substring(0, 8)}.pdf',
      );
      await file.writeAsBytes(pdfBytes, flush: true);
      final text = _buildReceiptText(receipt, rideRequestId);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: text,
        subject: 'HeyCaby Ride Receipt',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.rideReceiptShareFailed)),
      );
    }
  }

  Future<void> _shareViaEmail(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdfBytes = await _buildReceiptPdfBytes(receipt, rideRequestId);
      final tmp = await getTemporaryDirectory();
      final file = File(
        '${tmp.path}/heycaby_receipt_${rideRequestId.substring(0, 8)}.pdf',
      );
      await file.writeAsBytes(pdfBytes, flush: true);
      final text = _buildReceiptText(receipt, rideRequestId);
      final uri = Uri(
        scheme: 'mailto',
        queryParameters: {
          'subject': 'HeyCaby Ride Receipt',
          'body': text,
        },
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          subject: 'HeyCaby Ride Receipt',
          text: text,
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.rideReceiptShareFailed)),
      );
    }
  }
}
