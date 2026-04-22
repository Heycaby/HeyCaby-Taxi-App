import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/app_icons.dart';
import '../providers/driver_data_providers.dart';
import '../providers/driver_locale_provider.dart';
import '../services/driver_data_service.dart';
import '../widgets/premium_settings_cards.dart';

class DriverPreferencesScreen extends ConsumerWidget {
  const DriverPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(colorsProvider);
    final typo = ref.watch(typographyProvider);
    final profileAsync = ref.watch(driverProfileProvider);
    final themeData = ref.watch(themeProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.bg,
      body: profileAsync.when(
        data: (profile) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: Icon(
                            AppIcons.backIos,
                            color: colors.text,
                            size: 20,
                          ),
                          onPressed: () => context.pop(),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DriverStrings.preferences,
                                style: typo.titleMedium.copyWith(
                                  color: colors.text,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.35,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DriverStrings.preferencesSubtitle,
                                style: typo.bodySmall.copyWith(
                                  color: colors.textSoft,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    PremiumSettingsSectionLabel(
                      text: DriverStrings.preferencesSectionVehicle,
                      colors: colors,
                      typo: typo,
                    ),
                    PremiumSettingsCard(
                      colors: colors,
                      child: Column(
                        children: [
                          PremiumSettingsNavRow(
                            icon: AppIcons.carFront,
                            title: DriverStrings.vehicle,
                            subtitle: profile?.vehicleDisplay ?? '—',
                            colors: colors,
                            typo: typo,
                            onTap: () => context.push('/driver/vehicle'),
                          ),
                          PremiumSettingsNavRow(
                            icon: AppIcons.radar,
                            title: DriverStrings.pickupDistance,
                            subtitle:
                                '${(profile?.pickupDistanceMaxKm ?? 20).round()} km',
                            colors: colors,
                            typo: typo,
                            onTap: () => _showPickupDistanceModal(context, ref),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    PremiumSettingsSectionLabel(
                      text: DriverStrings.preferencesSectionPayments,
                      colors: colors,
                      typo: typo,
                    ),
                    PremiumSettingsCard(
                      colors: colors,
                      child: Column(
                        children: [
                          PremiumSettingsToggleRow(
                            icon: AppIcons.payments,
                            title: DriverStrings.acceptsCash,
                            value: profile?.acceptsCash ?? false,
                            colors: colors,
                            typo: typo,
                            onChanged: (v) =>
                                _updatePaymentMethod(context, ref, profile, 'cash', v),
                          ),
                          PremiumSettingsToggleRow(
                            icon: Icons.credit_card_rounded,
                            title: DriverStrings.acceptsCard,
                            value: profile?.acceptsCard ?? false,
                            colors: colors,
                            typo: typo,
                            onChanged: (v) =>
                                _updatePaymentMethod(context, ref, profile, 'card', v),
                          ),
                          PremiumSettingsToggleRow(
                            icon: AppIcons.wallet,
                            title: DriverStrings.acceptsTikkie,
                            value: profile?.acceptsTikkie ?? false,
                            colors: colors,
                            typo: typo,
                            onChanged: (v) =>
                                _updatePaymentMethod(context, ref, profile, 'tikkie', v),
                          ),
                          PremiumSettingsToggleRow(
                            icon: Icons.receipt_long_rounded,
                            title: DriverStrings.acceptsInvoice,
                            value: profile?.acceptsInvoice ?? false,
                            colors: colors,
                            typo: typo,
                            onChanged: (v) =>
                                _updatePaymentMethod(context, ref, profile, 'invoice', v),
                          ),
                          PremiumSettingsToggleRow(
                            icon: AppIcons.dog,
                            title: DriverStrings.petFriendly,
                            value: profile?.isPetFriendly ?? false,
                            colors: colors,
                            typo: typo,
                            onChanged: (v) => _updatePref(ref, isPetFriendly: v),
                          ),
                          PremiumSettingsToggleRow(
                            icon: AppIcons.accessibility,
                            title: DriverStrings.wheelchairAccessible,
                            value: profile?.isWheelchairAccessible ?? false,
                            colors: colors,
                            typo: typo,
                            onChanged: (v) =>
                                _updatePref(ref, isWheelchairAccessible: v),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    PremiumSettingsSectionLabel(
                      text: DriverStrings.preferencesSectionAppearance,
                      colors: colors,
                      typo: typo,
                    ),
                    PremiumSettingsCard(
                      colors: colors,
                      child: Column(
                        children: [
                          PremiumSettingsNavRow(
                            icon: AppIcons.globe,
                            title: DriverStrings.language,
                            subtitle: languageDisplayName[
                                    ref.watch(localeProvider)?.languageCode ??
                                        'en'] ??
                                'English',
                            colors: colors,
                            typo: typo,
                            onTap: () => _showLanguagePicker(context, ref),
                          ),
                          PremiumSettingsNavRow(
                            icon: AppIcons.palette,
                            title: DriverStrings.theme,
                            subtitle: themeData.name,
                            colors: colors,
                            typo: typo,
                            onTap: () => _showThemePicker(context, ref),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: bottomPad + 88),
                  ]),
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.accent),
        ),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load preferences',
              style: typo.bodyMedium.copyWith(color: colors.textSoft),
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
    final current = ref.read(localeProvider)?.languageCode ?? 'en';
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
              ...['en', 'nl', 'ar'].map(
                (code) => ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  title: Text(
                    languageDisplayName[code] ?? code,
                    style: typo.bodyLarge.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: current == code
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

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final colors = ref.read(colorsProvider);
    final typo = ref.read(typographyProvider);
    final currentId = ref.read(themeProvider).id;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (ctx, scrollController) => DecoratedBox(
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
            children: [
              premiumSheetHandle(colors),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  DriverStrings.theme,
                  style: typo.titleMedium.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    ...kThemes.keys.map((id) {
                      final theme = kThemes[id]!;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        title: Text(
                          theme.name,
                          style: typo.bodyLarge.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          theme.tagline,
                          style: typo.bodySmall.copyWith(color: colors.textSoft),
                        ),
                        trailing: currentId == id
                            ? Icon(AppIcons.checkCircle, color: colors.accent)
                            : null,
                        onTap: () async {
                          await ref.read(themeProvider.notifier).setTheme(id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPickupDistanceModal(BuildContext context, WidgetRef ref) {
    final initial =
        ref.read(driverProfileProvider).valueOrNull?.pickupDistanceMaxKm ?? 20.0;
    final typo = ref.read(typographyProvider);
    final colors = ref.read(colorsProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
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
          child: _PickupDistanceSheet(
            initialValue: initial,
            typo: typo,
            colors: colors,
            onSave: (value) async {
              final id = await ref.read(driverIdProvider.future);
              if (id == null) return;
              final ok = await ref.read(driverDataServiceProvider).updateDriverPrefs(
                    id,
                    pickupDistanceMaxKm: value,
                  );
              if (ok && ctx.mounted) {
                ref.invalidate(driverProfileProvider);
                Navigator.pop(ctx);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _PickupDistanceSheet extends StatefulWidget {
  final double initialValue;
  final HeyCabyTypography typo;
  final HeyCabyColorTokens colors;
  final Future<void> Function(double) onSave;

  const _PickupDistanceSheet({
    required this.initialValue,
    required this.typo,
    required this.colors,
    required this.onSave,
  });

  @override
  State<_PickupDistanceSheet> createState() => _PickupDistanceSheetState();
}

class _PickupDistanceSheetState extends State<_PickupDistanceSheet> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final t = widget.typo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          premiumSheetHandle(c),
          Text(
            DriverStrings.pickupDistance,
            style: t.titleMedium.copyWith(
              color: c.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_value.round()} km',
            style: t.titleMedium.copyWith(
              color: c.accent,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: c.accent.withValues(alpha: 0.55),
              inactiveTrackColor: c.border.withValues(alpha: 0.6),
              thumbColor: c.accent,
              overlayColor: c.accent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: _value,
              min: 5,
              max: 50,
              divisions: 9,
              label: '${_value.round()} km',
              onChanged: (v) => setState(() => _value = v),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              onPressed: () => widget.onSave(_value),
              child: Text(
                DriverStrings.saveAction,
                style: t.labelLarge.copyWith(
                  color: c.onAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
