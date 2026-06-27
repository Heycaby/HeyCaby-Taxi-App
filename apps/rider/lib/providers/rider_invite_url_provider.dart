import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Rider Grow / invite share URL — from Supabase `fn_app_public_links` (website fallback).
final riderInviteShareUrlProvider = Provider<String>((ref) {
  final linksAsync = ref.watch(appPublicLinksProvider);
  return linksAsync.maybeWhen(
    data: (links) => links.riderInviteShareUrl(),
    orElse: () => appPublicLinks.current.riderInviteShareUrl(),
  );
});

final riderInviteShareReadyProvider = Provider<bool>((ref) {
  final linksAsync = ref.watch(appPublicLinksProvider);
  return linksAsync.maybeWhen(
    data: (links) => links.riderInviteShareReady,
    orElse: () => appPublicLinks.current.riderInviteShareReady,
  );
});

/// True when the share URL is an App Store / Play Store link (not website fallback).
final riderSharingAppStoreProvider = Provider<bool>((ref) {
  final linksAsync = ref.watch(appPublicLinksProvider);
  return linksAsync.maybeWhen(
    data: (links) => links.riderSharingAppStoreUrl,
    orElse: () => appPublicLinks.current.riderSharingAppStoreUrl,
  );
});
