/// Rider booking / trip payment method ids (`cash`, `pin`, `tikkie`).
enum RidePaymentMethod {
  cash('cash'),
  pin('pin'),
  tikkie('tikkie');

  const RidePaymentMethod(this.id);
  final String id;

  static RidePaymentMethod fromId(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return switch (normalized) {
      'pin' || 'card' => RidePaymentMethod.pin,
      'tikkie' => RidePaymentMethod.tikkie,
      _ => RidePaymentMethod.cash,
    };
  }

  static RidePaymentMethod fromBookingMethods(List<String> methods) {
    if (methods.isEmpty) return RidePaymentMethod.cash;
    return fromId(methods.first);
  }

  /// Driver receipt / profile may use `card` instead of `pin`.
  String get driverReceiptId => switch (this) {
        RidePaymentMethod.pin => 'card',
        _ => id,
      };
}

String formatRidePaymentEuro(double value) => '€${value.toStringAsFixed(2)}';

double? parseRidePaymentEuroLabel(String? raw) {
  if (raw == null || raw.trim().isEmpty || raw.trim() == '—') return null;
  final cleaned = raw
      .replaceAll('€', '')
      .replaceAll(RegExp(r'EUR', caseSensitive: false), '')
      .trim()
      .replaceAll(',', '.');
  return double.tryParse(cleaned);
}
