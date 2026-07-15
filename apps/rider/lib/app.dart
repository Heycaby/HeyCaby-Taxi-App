import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'providers/rider_locale_provider.dart';
import 'router.dart';
import 'services/heycaby_widget_deep_links.dart';
import 'services/notify_search_notification_scope.dart';
import 'services/rider_invite_attribution.dart';
import 'services/rider_fcm_scope.dart';
import 'services/rider_live_activity_scope.dart';
import 'services/rider_ride_chat_scope.dart';
import 'utils/rider_locale_utils.dart';
import 'widgets/rider_locale_bridge_sync.dart';
import 'widgets/rider_locale_observer.dart';

class HeyCabyRiderApp extends ConsumerStatefulWidget {
  const HeyCabyRiderApp({super.key});

  @override
  ConsumerState<HeyCabyRiderApp> createState() => _HeyCabyRiderAppState();
}

class _HeyCabyRiderAppState extends ConsumerState<HeyCabyRiderApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(themeProvider.notifier).loadSavedTheme();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final themeId = ref.watch(themeProvider).id;
    final appLocale = ref.watch(riderAppLocaleProvider);

    return MaterialApp.router(
      title: 'HeyCaby',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: appLocale,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        return resolveRiderSupportedLocale(deviceLocale);
      },
      theme: buildHeyCabyMaterialTheme(
        colors: colors,
        textTheme: buildHeyCabyBrandMaterialTextTheme(),
        themeId: themeId,
      ),
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, routerChild) {
        final shell = routerChild ?? const SizedBox.shrink();
        return RiderInviteAttributionScope(
          child: RiderFcmScope(
            child: RiderRideChatScope(
              child: HeyCabyWidgetDeepLinkScope(
                child: RiderLiveActivityScope(
                  child: NotifySearchNotificationScope(
                    child: RiderLocaleObserver(
                      child: RiderLocaleBridgeSync(
                        child: _GlobalTapHaptics(child: shell),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlobalTapHaptics extends StatefulWidget {
  final Widget child;
  const _GlobalTapHaptics({required this.child});

  @override
  State<_GlobalTapHaptics> createState() => _GlobalTapHapticsState();
}

class _GlobalTapHapticsState extends State<_GlobalTapHaptics> {
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _onTapDown(TapDownDetails _) {
    final now = DateTime.now();
    if (now.difference(_lastTapAt).inMilliseconds < 60) return;
    _lastTapAt = now;
    HapticService.mediumTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _onTapDown,
      child: widget.child,
    );
  }
}
