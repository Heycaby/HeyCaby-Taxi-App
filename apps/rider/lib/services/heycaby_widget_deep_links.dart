import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/url_scheme_data.dart';

import '../constants/heycaby_widget_config.dart';
import '../router.dart';

/// Listens for iOS/Android home-widget opens and routes via [GoRouter].
class HeyCabyWidgetDeepLinkScope extends ConsumerStatefulWidget {
  final Widget child;

  const HeyCabyWidgetDeepLinkScope({super.key, required this.child});

  @override
  ConsumerState<HeyCabyWidgetDeepLinkScope> createState() =>
      _HeyCabyWidgetDeepLinkScopeState();
}

class _HeyCabyWidgetDeepLinkScopeState
    extends ConsumerState<HeyCabyWidgetDeepLinkScope> {
  StreamSubscription<Uri?>? _sub;
  StreamSubscription<UrlSchemeData>? _liveActivityUrlSub;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _sub = HomeWidget.widgetClicked.listen(_onUri);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _liveActivityUrlSub =
          LiveActivities().urlSchemeStream().listen(_onLiveActivityUrlScheme);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _onUri(initial);
    });
  }

  void _onLiveActivityUrlScheme(UrlSchemeData data) {
    if (!mounted) return;
    if (data.scheme != kHeyCabyWidgetUrlScheme) return;
    final url = data.url;
    if (url == null || url.isEmpty) return;
    _onUri(Uri.tryParse(url));
  }

  void _onUri(Uri? uri) {
    if (!mounted || uri == null) return;
    if (uri.scheme != kHeyCabyWidgetUrlScheme) return;
    final kind = uri.queryParameters['kind'] ?? '';
    final router = ref.read(appRouterProvider);
    switch (kind) {
      case 'WidgetA':
        router.go('/home');
        break;
      case 'WidgetB':
        router.go('/scheduled-matching');
        break;
      case 'WidgetC':
        router.go('/marketplace-matching');
        break;
      case 'WidgetD':
        router.go('/active');
        break;
      default:
        if (uri.host == 'widget') {
          router.go('/home');
        }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _liveActivityUrlSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
