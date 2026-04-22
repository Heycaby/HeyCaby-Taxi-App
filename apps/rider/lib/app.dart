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
              theme: buildHeyCabyMaterialTheme(
                colors: colors,
                textTheme: buildHeyCabyBrandMaterialTextTheme(),
              ),
              routerConfig: ref.watch(appRouterProvider),
            ),
          ),
        ),
      ),
    );
  }
}
