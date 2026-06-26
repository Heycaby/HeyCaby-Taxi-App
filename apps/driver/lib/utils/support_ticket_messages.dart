import 'dart:convert';

/// Normalizes `tickets.messages` from Supabase: JSONB arrays, JSON strings, or legacy shapes.
List<dynamic> normalizeTicketMessages(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) return List<dynamic>.from(raw);
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return const [];
    try {
      final decoded = jsonDecode(t);
      if (decoded is List) return List<dynamic>.from(decoded);
      if (decoded is Map) return [decoded];
    } catch (_) {
      return [<String, dynamic>{'role': 'system', 'content': t}];
    }
    return const [];
  }
  if (raw is Map) return [raw];
  return const [];
}

/// Chat UI expects a list of maps (role/content or legacy keys).
List<Map<String, dynamic>> ticketMessagesToMapList(dynamic raw) {
  final out = <Map<String, dynamic>>[];
  for (final e in normalizeTicketMessages(raw)) {
    if (e is Map) {
      out.add(Map<String, dynamic>.from(e as Map));
    } else {
      out.add(<String, dynamic>{'role': 'system', 'content': e.toString()});
    }
  }
  return out;
}
