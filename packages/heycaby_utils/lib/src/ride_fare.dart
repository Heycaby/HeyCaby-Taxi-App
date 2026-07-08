/// Shared ride fare resolution for rider + driver clients.
///
/// All `ride_requests` fare columns (`offered_fare`, `quoted_fare`, etc.) are
/// stored in **euros**. Waiting fees use `waiting_fee_cents`.
class HeyCabyRideFare {
  HeyCabyRideFare._();

  static const fareColumnPriority = <String>[
    'final_fare',
    'quoted_fare',
    'offered_fare',
    'marketplace_offered_fare',
    'estimated_fare',
  ];

  /// First positive € amount from a ride row (or nested map).
  static double? resolveEuroFromRow(Map<String, dynamic> row) {
    for (final key in fareColumnPriority) {
      final v = row[key];
      if (v is num) {
        final euro = v.toDouble();
        if (euro > 0) return euro;
      }
    }
    return null;
  }

  /// € total including waiting fee when present and not waived.
  static double? resolveTotalEuroFromRow(
    Map<String, dynamic> row, {
    bool includeWaiting = true,
  }) {
    final base = resolveEuroFromRow(row);
    var total = base ?? 0.0;
    if (includeWaiting && row['waiting_fee_waived'] != true) {
      final waiting = row['waiting_fee_cents'];
      if (waiting is num) total += waiting.toDouble() / 100;
    }
    return total > 0 ? total : null;
  }

  /// Whole cents for UI that stores fare as cents (rider active ride sheet).
  static int? resolveCentsFromRow(
    Map<String, dynamic> row, {
    bool includeWaiting = true,
  }) {
    final euro = resolveTotalEuroFromRow(row, includeWaiting: includeWaiting);
    if (euro == null) return null;
    return (euro * 100).round();
  }

  /// Snapshot written at booking / accept so every screen reads the same €.
  static Map<String, dynamic> fareSnapshotForInsert(double quoteEuro) => {
        'offered_fare': quoteEuro,
        'quoted_fare': quoteEuro,
        'estimated_fare': quoteEuro,
      };

  static String? formatEuroLabel(
    double? euro, {
    String symbol = '€',
  }) {
    if (euro == null || euro <= 0) return null;
    return '$symbol${euro.toStringAsFixed(2)}';
  }

  static String? formatCentsLabel(
    int? cents, {
    String symbol = '€',
  }) {
    if (cents == null || cents <= 0) return null;
    return '$symbol${(cents / 100).toStringAsFixed(2)}';
  }
}
