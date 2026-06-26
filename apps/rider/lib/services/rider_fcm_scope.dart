import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Binds FCM registration to [riderIdentityProvider] (session + identity required).
class RiderFcmScope extends ConsumerStatefulWidget {
  const RiderFcmScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RiderFcmScope> createState() => _RiderFcmScopeState();
}

class _RiderFcmScopeState extends ConsumerState<RiderFcmScope> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    HeyCabyFcmRegistration.bindRiderIdentity(
      () => ref.read(riderIdentityProvider).valueOrNull?.identityId,
    );
    HeyCabyFcmRegistration.wireTokenRefresh(appRole: 'rider');
    _authSub = HeyCabySupabase.client.auth.onAuthStateChange.listen((_) async {
      final s = ref.read(riderIdentityProvider).valueOrNull;
      if (s != null && s.identityId != null && s.identityId!.isNotEmpty) {
        await HeyCabyFcmRegistration.sync(appRole: 'rider');
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = ref.read(riderIdentityProvider).valueOrNull;
      if (s != null && s.identityId != null && s.identityId!.isNotEmpty) {
        await HeyCabyFcmRegistration.sync(appRole: 'rider');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(riderIdentityProvider, (prev, next) {
      next.whenData((s) async {
        if (s.hasSession && s.identityId != null && s.identityId!.isNotEmpty) {
          await HeyCabyFcmRegistration.sync(appRole: 'rider');
        }
      });
    });
    return widget.child;
  }
}
