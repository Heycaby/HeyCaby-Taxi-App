import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

import 'settings_provider.dart';

/// Resolved rider name + email for UI (passport, home greeting, completeness).
class RiderProfileDisplay {
  const RiderProfileDisplay({
    required this.displayName,
    required this.editableName,
    required this.email,
    required this.hasName,
    required this.hasEmail,
    required this.nameInitial,
  });

  /// Best name for display (identity → settings → auth metadata).
  final String displayName;

  /// Name the user can edit in Account (identity → settings only).
  final String editableName;

  final String? email;
  final bool hasName;
  final bool hasEmail;
  final String nameInitial;

  int get completenessPercent => (hasName ? 50 : 0) + (hasEmail ? 50 : 0);
  bool get isComplete => hasName && hasEmail;
}

String formatRiderDisplayName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed.split(RegExp(r'\s+')).map((part) {
    if (part.isEmpty) return part;
    return part[0].toUpperCase() + part.substring(1).toLowerCase();
  }).join(' ');
}

String? _authDisplayName() {
  final meta = HeyCabySupabase.client.auth.currentUser?.userMetadata;
  if (meta == null) return null;
  for (final key in ['full_name', 'name', 'display_name']) {
    final value = (meta[key] as String?)?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String? _authEmail() {
  final user = HeyCabySupabase.client.auth.currentUser;
  if (user == null || user.isAnonymous) return null;
  final email = user.email?.trim();
  if (email == null || email.isEmpty) return null;
  return email;
}

final riderProfileDisplayProvider = Provider<RiderProfileDisplay>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  final identity = ref.watch(riderIdentityProvider).valueOrNull;

  final identityName = (identity?.bookingName ?? '').trim();
  final settingsName = (settings?.userName ?? '').trim();
  final authName = (_authDisplayName() ?? '').trim();

  final editableName =
      identityName.isNotEmpty ? identityName : settingsName;

  String rawDisplayName = editableName;
  if (rawDisplayName.isEmpty && authName.isNotEmpty) {
    rawDisplayName = authName;
  }

  final hasName = rawDisplayName.isNotEmpty;
  final displayName =
      hasName ? formatRiderDisplayName(rawDisplayName) : '';

  final identityEmail = (identity?.email ?? '').trim();
  final authEmail = _authEmail();
  final resolvedEmail =
      identityEmail.isNotEmpty ? identityEmail : authEmail;
  final hasEmail = resolvedEmail != null && resolvedEmail.isNotEmpty;

  final initialSource = displayName.isNotEmpty
      ? displayName
      : (hasEmail ? resolvedEmail : '?');

  return RiderProfileDisplay(
    displayName: displayName,
    editableName: editableName,
    email: hasEmail ? resolvedEmail : null,
    hasName: hasName,
    hasEmail: hasEmail,
    nameInitial: initialSource[0].toUpperCase(),
  );
});
