import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'providers/settings_provider.dart';
import 'router.dart';
import 'services/heycaby_widget_deep_links.dart';
import 'services/notify_search_notification_scope.dart';
import 'services/rider_invite_attribution.dart';
import 'services/rider_fcm_scope.dart';

class HeyCabyRiderApp extends ConsumerWidget {
  const HeyCabyRiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure saved theme is loaded; safe to call repeatedly.
    ref.read(themeProvider.notifier).loadSavedTheme();
    final colors = ref.watch(colorsProvider);
    final themeId = ref.watch(themeProvider).id;
    final settingsAsync = ref.watch(settingsProvider);

    Locale? effectiveLocale;
    settingsAsync.whenData((settings) {
      if (settings.language.isNotEmpty) {
        effectiveLocale = Locale(settings.language);
      }
    });

    return RiderInviteAttributionScope(
      child: RiderFcmScope(
        child: HeyCabyWidgetDeepLinkScope(
          child: NotifySearchNotificationScope(
            child: _GlobalTapHaptics(
              child: MaterialApp.router(
                title: 'HeyCaby',
                debugShowCheckedModeBanner: false,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                locale: effectiveLocale,
                localeResolutionCallback: (deviceLocale, supportedLocales) {
                  if (effectiveLocale != null) return effectiveLocale;
                  if (deviceLocale != null) {
                    for (final locale in supportedLocales) {
                      if (locale.languageCode == deviceLocale.languageCode) {
                        return locale;
                      }
                    }
                  }
                  return const Locale('nl', 'NL');
                },
                theme: buildHeyCabyMaterialTheme(
                  colors: colors,
                  textTheme: buildHeyCabyBrandMaterialTextTheme(),
                  themeId: themeId,
                ),
                routerConfig: ref.watch(appRouterProvider),
              ),
            ),
          ),
        ),
      ),
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
