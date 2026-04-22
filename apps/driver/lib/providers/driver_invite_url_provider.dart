import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Public URL for Driver TAF share / copy (plain [kAppPublicSiteRoot], no `/invite` or query).
final driverInviteShareUrlProvider = Provider<String>((ref) => driverInviteShareUrl);
