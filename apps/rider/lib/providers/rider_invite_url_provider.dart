import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Public URL for Rider TAF share / copy (plain [kAppPublicSiteRoot], no `/invite` or query).
final riderInviteShareUrlProvider = Provider<String>((ref) => riderInviteShareUrl);
