import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'providers/driver_locale_provider.dart';
import 'router.dart';
import 'services/driver_fcm_scope.dart';

class HeyCabyDriverApp extends ConsumerStatefulWidget {
  const HeyCabyDriverApp({super.key});

  @override
  ConsumerState<HeyCabyDriverApp> createState() => _HeyCabyDriverAppState();
}

class _HeyCabyDriverAppState extends ConsumerState<HeyCabyDriverApp> {
  bool _didLoadPrefs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didLoadPrefs) return;
      _didLoadPrefs = true;
      ref.read(themeProvider.notifier).loadSavedTheme();
      ref.read(localeProvider.notifier).loadSaved();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(colorsProvider);
    final locale = ref.watch(localeProvider);

    return DriverFcmScope(
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
          Locale('en'),
          Locale('nl'),
          Locale('de'),
          Locale('fr'),
          Locale('es'),
          Locale('ar'),
          Locale('tr'),
        ],
        theme: buildHeyCabyMaterialTheme(
          colors: colors,
          textTheme: buildHeyCabyBrandMaterialTextTheme(),
        ),
        routerConfig: appRouter,
      ),
    );
  }
}

