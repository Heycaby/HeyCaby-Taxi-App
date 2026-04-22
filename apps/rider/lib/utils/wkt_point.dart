/// Parses `POINT(lng lat)` / `POINT (lng lat)` from PostGIS WKT-style text.
(double? lng, double? lat) parseWktPoint(dynamic raw) {
  if (raw == null) return (null, null);
  final s = raw.toString();
  final m = RegExp(
    r'POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)',
    caseSensitive: false,
  ).firstMatch(s);
  if (m == null) return (null, null);
  return (
    double.tryParse(m.group(1)!),
    double.tryParse(m.group(2)!),
  );
}
