import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

import '../l10n/driver_ios_update_strings.dart';

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
    final colors = themeEntry.colors;
    final typo = themeEntry.typography;
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
        colors: colors,
        textTheme: buildHeyCabyBrandMaterialTextTheme(),
      ),
      home: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.system_update_rounded,
                  size: 64,
                  color: colors.accent,
                ),
                const SizedBox(height: 28),
                Text(
                  strings.title,
                  style: typo.headingSmall.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      strings.body(
                        '$kHeyCabyMinimumIosMajorVersion',
                        systemVersion,
                      ),
                      style: typo.bodyLarge.copyWith(
                        color: colors.textMid,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  strings.footer('$kHeyCabyMinimumIosMajorVersion'),
                  style: typo.bodySmall.copyWith(
                    color: colors.textSoft,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
