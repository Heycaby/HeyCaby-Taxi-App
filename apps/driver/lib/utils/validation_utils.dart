final _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Returns true if [value] is a valid UUID v4 format.
/// Use before passing any route parameter to a Supabase query.
bool isValidUuid(String? value) {
  if (value == null || value.isEmpty) return false;
  return _uuidRegex.hasMatch(value);
}

/// Returns true only if [url] is a valid HTTPS URL from an allowed domain.
/// Use before passing any backend-provided URL to an image widget.
bool isValidImageUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  try {
    final uri = Uri.parse(url);
    return uri.scheme == 'https' &&
        (uri.host.endsWith('supabase.co') ||
            uri.host.endsWith('supabase.in') ||
            uri.host.endsWith('heycaby.nl'));
  } catch (_) {
    return false;
  }
}
