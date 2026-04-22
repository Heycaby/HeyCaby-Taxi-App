import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/pending_invite_attribution.dart';
import '../providers/rider_invited_friends_count_provider.dart';

/// Extracts a 7-char invite code from `https://…/i/AbCd123` or `myapp://i/AbCd123`.
String? parseRiderInviteCodeFromUri(Uri? uri) {
  if (uri == null) return null;
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.length >= 2) {
    final a = segs[0].toLowerCase();
    final b = segs[1];
    if (a == 'i' && RegExp(r'^[a-zA-Z0-9]{7}$').hasMatch(b)) {
      return b;
    }
  }
  if (segs.length == 1 && segs[0].length == 7) {
    final only = segs[0];
    if (RegExp(r'^[a-zA-Z0-9]{7}$').hasMatch(only)) return only;
  }
  final q = uri.queryParameters['invite'] ?? uri.queryParameters['code'];
  if (q != null && RegExp(r'^[a-zA-Z0-9]{7}$').hasMatch(q.trim())) {
    return q.trim();
  }
  return null;
}

/// Listens for `/i/{code}` links, stores pending code, and calls Supabase once the rider session exists.
class RiderInviteAttributionScope extends ConsumerStatefulWidget {
  const RiderInviteAttributionScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RiderInviteAttributionScope> createState() =>
      _RiderInviteAttributionScopeState();
}

class _RiderInviteAttributionScopeState
    extends ConsumerState<RiderInviteAttributionScope> {
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final appLinks = AppLinks();
    final initial = await appLinks.getInitialLink();
    await _persistCodeFromUri(initial);
    _sub = appLinks.uriLinkStream.listen(_persistCodeFromUri);
    await _tryFlushPending();
  }

  Future<void> _persistCodeFromUri(Uri? uri) async {
    final code = parseRiderInviteCodeFromUri(uri);
    if (code == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(kPendingRiderInviteCodeKey, code);
    await _tryFlushPending();
  }

  Future<void> _tryFlushPending() async {
    final asyncId = ref.read(riderIdentityProvider);
    final identity = asyncId.valueOrNull;
    if (identity == null || !identity.hasSession) return;

    final p = await SharedPreferences.getInstance();
    final code = p.getString(kPendingRiderInviteCodeKey);
    if (code == null || code.isEmpty) return;

    try {
      await tryRecordRiderInviteAttribution(HeyCabySupabase.client, code);
    } catch (_) {}
    await p.remove(kPendingRiderInviteCodeKey);
    ref.invalidate(riderInvitedFriendsCountProvider);
  }

  @override
  void dispose() {
    final s = _sub;
    if (s != null) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(riderIdentityProvider, (_, __) {
      unawaited(_tryFlushPending());
    });
    return widget.child;
  }
}
