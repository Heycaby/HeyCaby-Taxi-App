import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';

/// Registers FCM when the driver Supabase session is present.
class DriverFcmScope extends ConsumerStatefulWidget {
  const DriverFcmScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DriverFcmScope> createState() => _DriverFcmScopeState();
}

class _DriverFcmScopeState extends ConsumerState<DriverFcmScope> {
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    HeyCabyFcmRegistration.bindDriver();
    HeyCabyFcmRegistration.wireTokenRefresh(appRole: 'driver');
    _authSub = HeyCabySupabase.client.auth.onAuthStateChange.listen((event) {
      if (event.session?.user != null) {
        HeyCabyFcmRegistration.sync(appRole: 'driver');
      }
    });
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
