import 'package:flutter/foundation.dart';

/// One row from GET `/api/driver/payments` (shape may vary; parse defensively).
@immutable
class DriverPaymentLedgerItem {
  const DriverPaymentLedgerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.sortDate,
    this.amountLabel,
    this.statusLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime sortDate;
  final String? amountLabel;
  final String? statusLabel;

  static DriverPaymentLedgerItem fromMap(Map<String, dynamic> j) {
    final id = (j['id'] ?? j['payment_id'] ?? j['mollie_payment_id'] ?? '').toString();
    final title = (j['title'] ??
            j['description'] ??
            j['type'] ??
            'Payment')
        .toString();
    final status = j['status']?.toString();
    final amountLabel = _formatAmount(j);

    DateTime? at;
    for (final k in const [
      'paid_at',
      'settled_at',
      'created_at',
      'updated_at',
      'occurred_at',
    ]) {
      final v = j[k];
      if (v is String && v.trim().isNotEmpty) {
        at = DateTime.tryParse(v.trim());
        if (at != null) break;
      }
    }
    at ??= DateTime.fromMillisecondsSinceEpoch(0);

    final local = at.toLocal();
    final subtitle =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return DriverPaymentLedgerItem(
      id: id.isEmpty ? title.hashCode.toString() : id,
      title: title,
      subtitle: subtitle,
      sortDate: at,
      amountLabel: amountLabel,
      statusLabel: status,
    );
  }

  static String? _formatAmount(Map<String, dynamic> j) {
    if (j['amount_label'] is String) return j['amount_label'] as String;
    if (j['amount_display'] is String) return j['amount_display'] as String;
    final cents = j['amount_cents'] ?? j['amount_cents_total'] ?? j['total_cents'];
    if (cents is num) {
      final cur = (j['currency'] as String?)?.trim().toUpperCase();
      final sym = cur == 'EUR' || cur == null ? '€' : '$cur ';
      return '$sym${(cents / 100).toStringAsFixed(2)}';
    }
    final euros = j['amount_eur'] ?? j['amount'];
    if (euros is num) return '€${euros.toStringAsFixed(2)}';
    return null;
  }
}
