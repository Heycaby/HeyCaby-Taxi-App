/// Taxi Terug stats — empty-km saved + earnings (Phase 5).
class DriverTaxiTerugStats {
  const DriverTaxiTerugStats({
    required this.ok,
    this.period = 'month',
    this.ridesCompleted = 0,
    this.emptyKmSaved = 0,
    this.earningsEuros = 0,
    this.monthRides = 0,
    this.monthEmptyKmSaved = 0,
    this.monthEarningsEuros = 0,
    this.todayRides = 0,
    this.todayEmptyKmSaved = 0,
    this.todayEarningsEuros = 0,
    this.allTimeRides = 0,
    this.allTimeEmptyKmSaved = 0,
    this.allTimeEarningsEuros = 0,
  });

  final bool ok;
  final String period;
  final int ridesCompleted;
  final double emptyKmSaved;
  final double earningsEuros;
  final int monthRides;
  final double monthEmptyKmSaved;
  final double monthEarningsEuros;
  final int todayRides;
  final double todayEmptyKmSaved;
  final double todayEarningsEuros;
  final int allTimeRides;
  final double allTimeEmptyKmSaved;
  final double allTimeEarningsEuros;

  bool get hasMonthActivity => monthRides > 0 || monthEarningsEuros > 0;

  String formatEuros(double value) => '€${value.toStringAsFixed(2)}';

  String formatKm(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  factory DriverTaxiTerugStats.fromJson(Map<String, dynamic> json) {
    double dbl(dynamic v) => (v as num?)?.toDouble() ?? 0;
    int integer(dynamic v) => (v as num?)?.toInt() ?? 0;

    return DriverTaxiTerugStats(
      ok: json['ok'] == true,
      period: (json['period'] as String?) ?? 'month',
      ridesCompleted: integer(json['rides_completed']),
      emptyKmSaved: dbl(json['empty_km_saved']),
      earningsEuros: dbl(json['earnings_euros']),
      monthRides: integer(json['month_rides']),
      monthEmptyKmSaved: dbl(json['month_empty_km_saved']),
      monthEarningsEuros: dbl(json['month_earnings_euros']),
      todayRides: integer(json['today_rides']),
      todayEmptyKmSaved: dbl(json['today_empty_km_saved']),
      todayEarningsEuros: dbl(json['today_earnings_euros']),
      allTimeRides: integer(json['all_time_rides']),
      allTimeEmptyKmSaved: dbl(json['all_time_empty_km_saved']),
      allTimeEarningsEuros: dbl(json['all_time_earnings_euros']),
    );
  }

  static DriverTaxiTerugStats? parseRpc(dynamic res) {
    if (res is! Map) return null;
    final map = Map<String, dynamic>.from(res);
    if (map['ok'] != true) return null;
    return DriverTaxiTerugStats.fromJson(map);
  }
}
