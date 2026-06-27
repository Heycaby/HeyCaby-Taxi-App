/// Driver response to a rider marketplace offer (`ride_bids` row + enrichments).
class MarketplaceDriverOffer {
  const MarketplaceDriverOffer({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.bidAmountEuro,
    required this.etaMinutes,
    required this.status,
    required this.rating,
    this.vehicleLabel,
    this.photoUrl,
    this.message,
    this.expiresAt,
    this.isMutualFavorite = false,
  });

  final String id;
  final String driverId;
  final String driverName;
  final double bidAmountEuro;
  final int etaMinutes;
  final String status;
  final double rating;
  final String? vehicleLabel;
  final String? photoUrl;
  final String? message;
  final DateTime? expiresAt;
  final bool isMutualFavorite;

  bool get isPending => status == 'pending';

  /// True when the driver matched the rider's posted offer (not a counter).
  bool isAcceptAtPrice(double riderOfferEuro) =>
      (bidAmountEuro - riderOfferEuro).abs() < 0.01;

  bool isCounterOffer(double riderOfferEuro) =>
      bidAmountEuro > riderOfferEuro + 0.01;

  /// Sort key: rating first, then ETA, then price (see product IA).
  double sortScore(double riderOfferEuro) {
    final acceptBonus = isAcceptAtPrice(riderOfferEuro) ? 8.0 : 0.0;
    return rating * 20 + acceptBonus - etaMinutes * 0.8 - bidAmountEuro * 0.05;
  }

  factory MarketplaceDriverOffer.fromJson(
    Map<String, dynamic> json, {
    required double riderOfferEuro,
    bool isMutualFavorite = false,
  }) {
    final snapshot = json['driver_snapshot'];
    Map<String, dynamic>? snap;
    if (snapshot is Map) {
      snap = Map<String, dynamic>.from(snapshot);
    }

    final driver = json['drivers'];
    Map<String, dynamic>? driverRow;
    if (driver is Map) {
      driverRow = Map<String, dynamic>.from(driver);
    }

    final name = (snap?['name'] ??
            driverRow?['full_name'] ??
            driverRow?['name'] ??
            '')
        .toString()
        .trim();

    final rating = (snap?['rating'] as num?)?.toDouble() ??
        (driverRow?['rating'] as num?)?.toDouble() ??
        (driverRow?['avg_rating'] as num?)?.toDouble() ??
        5.0;

    final make = driverRow?['vehicle_make'] as String?;
    final model = driverRow?['vehicle_model'] as String?;
    final vehicleLabel = [
      if (make != null && make.trim().isNotEmpty) make.trim(),
      if (model != null && model.trim().isNotEmpty) model.trim(),
    ].join(' ');

    final expiresRaw = json['expires_at'];
    DateTime? expiresAt;
    if (expiresRaw != null) {
      expiresAt = DateTime.tryParse(expiresRaw.toString());
    }

    return MarketplaceDriverOffer(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      driverName: name.isEmpty ? 'Driver' : name,
      bidAmountEuro: (json['bid_amount'] as num).toDouble(),
      etaMinutes: (json['eta_minutes'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'pending',
      rating: rating,
      vehicleLabel: vehicleLabel.isEmpty ? null : vehicleLabel,
      photoUrl: (snap?['photo_url'] ?? driverRow?['profile_photo_url']) as String?,
      message: (json['message'] as String?)?.trim(),
      expiresAt: expiresAt,
      isMutualFavorite: isMutualFavorite,
    );
  }
}
