import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/rider_home_banners_provider.dart';
import '../providers/rider_locale_provider.dart';

/// Invalidates locale-dependent providers when the user changes system language.
class RiderLocaleObserver extends ConsumerStatefulWidget {
  const RiderLocaleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RiderLocaleObserver> createState() =>
      _RiderLocaleObserverState();
}

class _RiderLocaleObserverState extends ConsumerState<RiderLocaleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    ref.invalidate(deviceLocaleSignalProvider);
    ref.invalidate(riderHomeBannersRefreshProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
