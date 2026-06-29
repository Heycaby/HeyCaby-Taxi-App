import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'l10n/driver_strings.dart';
import 'providers/driver_data_providers.dart';
import 'providers/driver_locale_provider.dart';
import 'providers/driver_state_provider.dart';
import 'router.dart';
import 'services/driver_fcm_scope.dart';
import 'services/driver_operational_restore_service.dart';
import 'services/driver_session_bootstrap.dart';

class HeyCabyDriverApp extends ConsumerStatefulWidget {
  const HeyCabyDriverApp({super.key});

  @override
  ConsumerState<HeyCabyDriverApp> createState() => _HeyCabyDriverAppState();
}

class _HeyCabyDriverAppState extends ConsumerState<HeyCabyDriverApp> {
  bool _didLoadPrefs = false;
  bool _scheduledSessionHydration = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didLoadPrefs) return;
      _didLoadPrefs = true;
      ref.read(themeProvider.notifier).loadSavedTheme();
      ref.read(localeProvider.notifier).loadSaved();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _scheduledSessionHydration) return;
      _scheduledSessionHydration = true;
      await _hydrateDriverStateIfRestoredSession();
    });
  }

  /// Supabase persists the session (SharedPreferences + refresh). On cold start,
  /// [driverStateProvider] still starts empty — mirror login/splash so Riverpod
  /// and `bootstrapDriverSessionAfterAuth` match auth (until explicit sign-out).
  Future<void> _hydrateDriverStateIfRestoredSession() async {
    final user = HeyCabySupabase.client.auth.currentUser;
    if (user == null) return;
    final uid = user.id;
    if (ref.read(driverStateProvider).userId == uid) return;

    ref.read(driverStateProvider.notifier).setUser(uid, null);
    String? driverId;
    try {
      driverId = await bootstrapDriverSessionAfterAuth(ref);
    } catch (_) {
      driverId = null;
    }
    if (!mounted) return;
    ref.read(driverStateProvider.notifier).setUser(uid, driverId);
    ref.invalidate(driverIdProvider);
    ref.invalidate(driverProfileProvider);
    if (driverId != null) {
      await restoreDriverOperationalState(ref, appRouter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final themeId = ref.watch(themeProvider).id;
    final locale = ref.watch(localeProvider);
    DriverStrings.useLocale(locale);

    return DriverFcmScope(
      child: _GlobalTapHaptics(
        child: MaterialApp.router(
          title: 'HeyCaby Driver',
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('nl'),
            Locale('en'),
            Locale('es'),
            Locale('ar'),
          ],
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (locale != null) return locale;
            if (deviceLocale != null) {
              for (final supported in supportedLocales) {
                if (supported.languageCode == deviceLocale.languageCode) {
                  return supported;
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
          routerConfig: appRouter,
        ),
      ),
    );
  }
}

/// Broad tap-down haptics so lists, tiles, and controls feel responsive. Works
/// alongside [NavigatorObserver] route haptics (debounced) and explicit CTAs.
class _GlobalTapHaptics extends StatefulWidget {
  const _GlobalTapHaptics({required this.child});

  final Widget child;

  @override
  State<_GlobalTapHaptics> createState() => _GlobalTapHapticsState();
}

class _GlobalTapHapticsState extends State<_GlobalTapHaptics> {
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _onTapDown(TapDownDetails _) {
    final now = DateTime.now();
    if (now.difference(_lastTapAt).inMilliseconds < 72) return;
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
