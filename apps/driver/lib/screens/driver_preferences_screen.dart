import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_locale_provider.dart';
import '../providers/driver_nav_app_pref_provider.dart';
import '../services/driver_data_service.dart';
import '../services/driver_nav_app_pref.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_preferences_body.dart';
import '../widgets/premium_settings_cards.dart';

class DriverPreferencesScreen extends ConsumerWidget {
  const DriverPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));
    final profileAsync = ref.watch(driverProfileProvider);

    return Scaffold(
      body: profileAsync.when(
        data: (profile) {
          return DriverPreferencesBody(
            colors: colors,
            typography: typography,
            vehicleSubtitle: profile?.vehicleDisplay ?? '—',
            languageSubtitle: _languageSubtitle(ref),
            acceptsCash: profile?.acceptsCash ?? false,
            acceptsCard: profile?.acceptsCard ?? false,
            acceptsTikkie: profile?.acceptsTikkie ?? false,
            acceptsInvoice: profile?.acceptsInvoice ?? false,
            petFriendly: profile?.isPetFriendly ?? false,
            wheelchairAccessible: profile?.isWheelchairAccessible ?? false,
            onBack: () => context.pop(),
            onVehicle: () => context.push('/driver/vehicle'),
            onLanguage: () => _showLanguagePicker(context, ref),
            onCashChanged: (v) {
              _updatePaymentMethod(context, ref, profile, 'cash', v);
            },
            onCardChanged: (v) {
              _updatePaymentMethod(context, ref, profile, 'card', v);
            },
            onTikkieChanged: (v) {
              _updatePaymentMethod(context, ref, profile, 'tikkie', v);
            },
            onInvoiceChanged: (v) {
              _updatePaymentMethod(context, ref, profile, 'invoice', v);
            },
            onPetFriendlyChanged: (v) {
              _updatePref(ref, isPetFriendly: v);
            },
            onWheelchairChanged: (v) {
              _updatePref(ref, isWheelchairAccessible: v);
            },
            navigationContent: const _NavAppPreferenceSection(),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              DriverStrings.preferencesLoadFailed,
              style: typography.bodyMedium.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updatePaymentMethod(
    BuildContext context,
    WidgetRef ref,
    DriverProfile? profile,
    String method,
    bool add,
  ) async {
    final id = await ref.read(driverIdProvider.future);
    if (id == null) return;
    final current = List<String>.from(profile?.paymentMethod ?? []);
    if (add && !current.contains(method)) current.add(method);
    if (!add) current.remove(method);
    if (current.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DriverStrings.paymentMethodRequired)),
        );
      }
      return;
    }
    final ok = await ref
        .read(driverDataServiceProvider)
        .updateDriverPrefs(id, paymentMethod: current);
    if (ok) ref.invalidate(driverProfileProvider);
  }

  Future<void> _updatePref(
    WidgetRef ref, {
    bool? isPetFriendly,
    bool? isWheelchairAccessible,
  }) async {
    final id = await ref.read(driverIdProvider.future);
    if (id == null) return;
    final ok = await ref.read(driverDataServiceProvider).updateDriverPrefs(
          id,
          isPetFriendly: isPetFriendly,
          isWheelchairAccessible: isWheelchairAccessible,
        );
    if (ok) ref.invalidate(driverProfileProvider);
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final current = ref.read(localeProvider)?.languageCode ?? 'nl';
    final followsDevice =
        ref.read(localeProvider.notifier).languageFollowsDevice;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: colors.text.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              premiumSheetHandle(colors),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  DriverStrings.language,
                  style: typo.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: Text(
                  DriverStrings.languageFollowDevice,
                  style: typo.bodyLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: followsDevice
                    ? Icon(AppIcons.checkCircle, color: colors.accent)
                    : null,
                onTap: () {
                  ref.read(localeProvider.notifier).resetToDevice();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              ...supportedLanguageCodes.map(
                (code) => ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  title: Text(
                    _languageLabel(code),
                    style: typo.bodyLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: !followsDevice && current == code
                      ? Icon(AppIcons.checkCircle, color: colors.accent)
                      : null,
                  onTap: () {
                    ref.read(localeProvider.notifier).setLocale(code);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _languageSubtitle(WidgetRef ref) {
    final notifier = ref.watch(localeProvider.notifier);
    if (notifier.languageFollowsDevice) {
      return DriverStrings.languageFollowDevice;
    }
    return _languageLabel(ref.watch(localeProvider)?.languageCode ?? 'en');
  }

  String _languageLabel(String code) {
    return switch (code) {
      'nl' => DriverStrings.languageDutch,
      'es' => DriverStrings.languageSpanish,
      'ar' => DriverStrings.languageArabic,
      _ => DriverStrings.languageEnglish,
    };
  }
}

class _NavAppPreferenceSection extends ConsumerWidget {
  const _NavAppPreferenceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final prefAsync = ref.watch(driverNavAppPrefProvider);

    return prefAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          DriverStrings.preferencesLoadFailed,
          style: typo.bodyMedium.copyWith(color: colors.textSoft),
        ),
      ),
      data: (selected) {
        Widget row(DriverNavApp app, String label, IconData icon) {
          final isSelected = selected == app;
          return InkWell(
            onTap: () =>
                ref.read(driverNavAppPrefProvider.notifier).setApp(app),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(icon, color: colors.accent, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: typo.bodyLarge.copyWith(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(AppIcons.checkCircle, color: colors.accent),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            row(
              DriverNavApp.waze,
              DriverStrings.hotspotsWaze,
              Icons.navigation_outlined,
            ),
            Divider(height: 1, color: colors.border.withValues(alpha: 0.35)),
            row(
              DriverNavApp.google,
              DriverStrings.hotspotsGoogleMaps,
              Icons.map_outlined,
            ),
          ],
        );
      },
    );
  }
}
