/// UUID v4 pattern for route guards (support chat ticket ids, etc.).
bool isValidUuid(String? value) {
  if (value == null || value.isEmpty) return false;
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
