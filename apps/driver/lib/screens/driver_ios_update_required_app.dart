import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../l10n/driver_ios_update_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_update_gate_body.dart';

/// Full-screen gate when iOS is below minimum (before driver [MaterialApp.router]).
class DriverIosUpdateRequiredApp extends StatelessWidget {
  const DriverIosUpdateRequiredApp({
    super.key,
    required this.systemVersion,
  });

  final String systemVersion;

  @override
  Widget build(BuildContext context) {
    final platformLocale =
        WidgetsBinding.instance.platformDispatcher.locale;
    final strings = driverIosUpdateStringsFor(platformLocale);
    final themeEntry = kThemes[kDriverDefaultTheme]!;
    final colors = DriverColors.fromTheme(themeEntry.colors);
    final typography = DriverTypography.fromTheme(themeEntry.typography);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: platformLocale,
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
        colors: themeEntry.colors,
        textTheme: buildHeyCabyBrandMaterialTextTheme(),
        themeId: themeEntry.id,
      ),
      home: DriverUpdateGateBody(
        colors: colors,
        typography: typography,
        title: strings.title,
        body: strings.body(
          '$kHeyCabyMinimumIosMajorVersion',
          systemVersion,
        ),
        footer: strings.footer('$kHeyCabyMinimumIosMajorVersion'),
      ),
    );
  }
}
