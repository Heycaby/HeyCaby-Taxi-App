import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_settings_row.dart';
import '../utils/driver_account_deletion.dart';
import '../utils/driver_logout.dart';

class DriverSettingsScreen extends ConsumerWidget {
  const DriverSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DriverColors.fromTheme(ref.watch(colorsProvider));
    final typography =
        DriverTypography.fromTheme(ref.watch(typographyProvider));

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DriverSpacing.screenEdge,
                  DriverSpacing.md,
                  DriverSpacing.screenEdge,
                  DriverSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: colors.text,
                          ),
                          onPressed: () => context.pop(),
                        ),
                        Expanded(
                          child: Text(
                            DriverStrings.settings,
                            textAlign: TextAlign.center,
                            style: typography.headlineSmall.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: DriverSpacing.lg),
                    _SettingsSectionLabel(
                      title: DriverStrings.profile,
                      colors: colors,
                      typography: typography,
                    ),
                    const SizedBox(height: DriverSpacing.sm),
                    DriverSettingsGroupCard(
                      colors: colors,
                      children: [
                        DriverSettingsNavRow(
                          icon: Icons.person_rounded,
                          title: DriverStrings.profile,
                          colors: colors,
                          typography: typography,
                          onTap: () => context.push('/driver/me'),
                        ),
                        DriverSettingsNavRow(
                          icon: Icons.directions_car_rounded,
                          title: DriverStrings.vehicle,
                          colors: colors,
                          typography: typography,
                          onTap: () => context.push('/driver/vehicle'),
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: DriverSpacing.xl),
                    _SettingsSectionLabel(
                      title: DriverStrings.work,
                      colors: colors,
                      typography: typography,
                    ),
                    const SizedBox(height: DriverSpacing.sm),
                    DriverSettingsGroupCard(
                      colors: colors,
                      children: [
                        DriverSettingsNavRow(
                          icon: Icons.tune_rounded,
                          title: DriverStrings.preferences,
                          colors: colors,
                          typography: typography,
                          onTap: () => context.push('/driver/preferences'),
                        ),
                        DriverSettingsNavRow(
                          icon: Icons.bar_chart_rounded,
                          title: DriverStrings.financeAndTax,
                          colors: colors,
                          typography: typography,
                          onTap: () => context.push('/driver/finance'),
                        ),
                        DriverSettingsNavRow(
                          icon: Icons.folder_open_rounded,
                          title: DriverStrings.documents,
                          colors: colors,
                          typography: typography,
                          onTap: () => context.push('/driver/documents'),
                        ),
                        DriverSettingsNavRow(
                          icon: Icons.receipt_long_rounded,
                          title: DriverStrings.billing,
                          colors: colors,
                          typography: typography,
                          onTap: () => context.push('/driver/billing'),
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: DriverSpacing.xl),
                    _SettingsSectionLabel(
                      title: DriverStrings.support,
                      colors: colors,
                      typography: typography,
                    ),
                    const SizedBox(height: DriverSpacing.sm),
                    DriverSettingsGroupCard(
                      colors: colors,
                      children: [
                        DriverSettingsNavRow(
                          icon: Icons.support_agent_rounded,
                          title: DriverStrings.support,
                          colors: colors,
                          typography: typography,
                          onTap: () => context.push('/driver/support'),
                        ),
                        DriverSettingsNavRow(
                          icon: Icons.help_center_rounded,
                          title: DriverStrings.faq,
                          colors: colors,
                          typography: typography,
                          onTap: () => context.push('/driver/faq'),
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: DriverSpacing.xl),
                    _SettingsSectionLabel(
                      title: DriverStrings.drawerSectionLegal,
                      colors: colors,
                      typography: typography,
                    ),
                    const SizedBox(height: DriverSpacing.sm),
                    DriverSettingsGroupCard(
                      colors: colors,
                      children: [
                        DriverSettingsNavRow(
                          icon: Icons.privacy_tip_outlined,
                          title: DriverStrings.privacyPolicy,
                          colors: colors,
                          typography: typography,
                          onTap: () => context.push('/driver/privacy'),
                        ),
                        DriverSettingsNavRow(
                          icon: Icons.gavel_rounded,
                          title: DriverStrings.termsOfService,
                          colors: colors,
                          typography: typography,
                          onTap: () => context.push('/driver/terms'),
                        ),
                        DriverSettingsNavRow(
                          icon: Icons.verified_user_outlined,
                          title: DriverStrings.indemnification,
                          colors: colors,
                          typography: typography,
                          onTap: () => context.push('/driver/indemnification'),
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: DriverSpacing.xl),
                    DriverSettingsGroupCard(
                      colors: colors,
                      children: [
                        DriverSettingsNavRow(
                          icon: Icons.logout_rounded,
                          title: DriverStrings.logout,
                          colors: colors,
                          typography: typography,
                          onTap: () => performDriverLogout(context, ref),
                        ),
                        DriverSettingsNavRow(
                          icon: Icons.delete_forever_rounded,
                          title: DriverStrings.deleteAccount,
                          colors: colors,
                          typography: typography,
                          destructive: true,
                          onTap: () =>
                              performDriverAccountDeletion(context, ref),
                          showDivider: false,
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 88),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({
    required this.title,
    required this.colors,
    required this.typography,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: typography.labelMedium.copyWith(
        color: colors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
