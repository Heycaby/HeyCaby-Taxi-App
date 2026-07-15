/// Taxi Terug wizard limits — must stay aligned with Supabase
/// `fn_driver_return_mode_activate` + `terugtaxi_config` wizard_* keys.
abstract final class TaxiTerugWizardContract {
  static const double maxDiscountPct = 50;
  static const double maxDepartureHours = 10;
  static const double minPickupRadiusKm = 1;
  static const double maxPickupRadiusKm = 50;
  static const double maxDropDistanceKm = 30;
  static const List<int> dropDistanceOptions = [5, 10, 15, 20, 25, 30];

  static double clampPickupRadiusKm(double km) =>
      km.clamp(minPickupRadiusKm, maxPickupRadiusKm).toDouble();

  static double clampDropDistanceKm(double km) =>
      km.clamp(5, maxDropDistanceKm).toDouble();

  static double snapDropDistanceKm(double km) {
    final clamped = clampDropDistanceKm(km);
    var nearest = dropDistanceOptions.first.toDouble();
    var best = double.infinity;
    for (final opt in dropDistanceOptions) {
      final delta = (clamped - opt).abs();
      if (delta < best) {
        best = delta;
        nearest = opt.toDouble();
      }
    }
    return nearest;
  }

  static double clampDiscountPct(double pct) =>
      pct.clamp(0, maxDiscountPct).toDouble();

  static double clampDepartureHours(double hours) =>
      hours.clamp(0, maxDepartureHours).toDouble();
}
