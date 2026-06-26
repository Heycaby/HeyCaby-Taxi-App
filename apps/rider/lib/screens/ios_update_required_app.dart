import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:heycaby_rider/l10n/app_localizations.dart';
import 'package:heycaby_ui/heycaby_ui.dart';
import 'package:heycaby_utils/heycaby_utils.dart';

/// Full-screen gate before [MaterialApp.router] when iOS is below minimum.
class RiderIosUpdateRequiredApp extends StatelessWidget {
  const RiderIosUpdateRequiredApp({
    super.key,
    required this.systemVersion,
  });

  final String systemVersion;

  static Locale _resolveLocale(Locale device) {
    for (final l in AppLocalizations.supportedLocales) {
      if (l.languageCode == device.languageCode) {
        return l;
      }
    }
    return const Locale('nl', 'NL');
  }

  @override
  Widget build(BuildContext context) {
    final platformLocale =
        WidgetsBinding.instance.platformDispatcher.locale;
    final locale = _resolveLocale(platformLocale);
    final l10n = lookupAppLocalizations(locale);
    final themeEntry = kThemes[kRiderDefaultTheme]!;
    final colors = themeEntry.colors;
    final typo = themeEntry.typography;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildHeyCabyMaterialTheme(
        colors: colors,
        textTheme: buildHeyCabyBrandMaterialTextTheme(),
        themeId: themeEntry.id,
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
                  l10n.iosUpdateRequiredTitle,
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
                      l10n.iosUpdateRequiredBody(
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
                  l10n.iosUpdateRequiredFooter(
                    '$kHeyCabyMinimumIosMajorVersion',
                  ),
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
