class HeyCabyFormatters {
  HeyCabyFormatters._();

  static String formatDistance(double km) {
    if (km < 1.0) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  static String formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Driving ETA fallback when Mapbox routing is unavailable.
  /// Uses faster effective speeds on longer legs (highway-heavy trips).
  static int estimateDrivingMinutes(double distanceKm) {
    if (distanceKm <= 0) return 1;
    final minutesPerKm = distanceKm >= 30
        ? 0.9
        : distanceKm >= 10
            ? 1.2
            : 2.0;
    return (distanceKm * minutesPerKm).ceil().clamp(1, 480);
  }
}
