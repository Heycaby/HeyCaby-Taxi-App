import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/rider_home_banners_provider.dart';
import '../providers/rider_locale_provider.dart';
import '../utils/rider_effective_locale_bridge.dart';

/// Keeps [RiderEffectiveLocaleBridge] in sync and refetches locale-sensitive data.
class RiderLocaleBridgeSync extends ConsumerWidget {
  const RiderLocaleBridgeSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(riderAppLocaleProvider);
    RiderEffectiveLocaleBridge.update(locale);

    ref.listen<Locale>(riderAppLocaleProvider, (previous, next) {
      if (previous == next) return;
      ref.read(riderHomeBannersRefreshProvider.notifier).state++;
    });

    return child;
  }
}
