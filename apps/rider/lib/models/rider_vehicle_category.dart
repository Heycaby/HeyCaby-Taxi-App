/// Vehicle categories for the rider booking flow (matches `BookingState.vehicleCategory` names).
enum RiderVehicleCategory {
  standard,
  comfort,
  taxibus,
  wheelchair;

  String get storageKey => name;

  static RiderVehicleCategory? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final c in RiderVehicleCategory.values) {
      if (c.name == value) return c;
    }
    return null;
  }
}
