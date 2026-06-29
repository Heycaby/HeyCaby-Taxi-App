import 'package:flutter/material.dart';

import '../l10n/driver_strings.dart';
import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_spacing.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_settings_row.dart';
import 'driver_settings_flow_common.dart';

/// **Preferences** — app behavior, not business rules.
class DriverPreferencesBody extends StatelessWidget {
  const DriverPreferencesBody({
    super.key,
    required this.colors,
    required this.typography,
    required this.vehicleSubtitle,
    required this.languageSubtitle,
    required this.acceptsCash,
    required this.acceptsCard,
    required this.acceptsTikkie,
    required this.acceptsInvoice,
    required this.petFriendly,
    required this.wheelchairAccessible,
    required this.onBack,
    required this.onVehicle,
    required this.onLanguage,
    required this.onCashChanged,
    required this.onCardChanged,
    required this.onTikkieChanged,
    required this.onInvoiceChanged,
    required this.onPetFriendlyChanged,
    required this.onWheelchairChanged,
    this.navigationContent,
    this.soundsContent,
    this.extraSections = const [],
  });

  final DriverColors colors;
  final DriverTypography typography;
  final String vehicleSubtitle;
  final String languageSubtitle;
  final bool acceptsCash;
  final bool acceptsCard;
  final bool acceptsTikkie;
  final bool acceptsInvoice;
  final bool petFriendly;
  final bool wheelchairAccessible;
  final VoidCallback onBack;
  final VoidCallback onVehicle;
  final VoidCallback onLanguage;
  final ValueChanged<bool> onCashChanged;
  final ValueChanged<bool> onCardChanged;
  final ValueChanged<bool> onTikkieChanged;
  final ValueChanged<bool> onInvoiceChanged;
  final ValueChanged<bool> onPetFriendlyChanged;
  final ValueChanged<bool> onWheelchairChanged;
  final Widget? navigationContent;
  final Widget? soundsContent;
  final List<Widget> extraSections;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return DriverSettingsFlowScaffold(
      title: DriverStrings.preferences,
      colors: colors,
      typography: typography,
      onBack: onBack,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DriverSettingsHeader(
              title: DriverStrings.preferences,
              subtitle: DriverStrings.preferencesSubtitle,
              colors: colors,
              typography: typography,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: DriverSpacing.screenEdge,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                DriverSettingsSectionLabel(
                  label: DriverStrings.preferencesSectionVehicle,
                  colors: colors,
                  typography: typography,
                ),
                DriverSettingsGroupCard(
                  colors: colors,
                  children: [
                    DriverSettingsNavRow(
                      icon: Icons.directions_car_rounded,
                      title: DriverStrings.vehicle,
                      subtitle: vehicleSubtitle,
                      colors: colors,
                      typography: typography,
                      onTap: onVehicle,
                      showDivider: false,
                    ),
                  ],
                ).driverFadeSlideIn(staggerIndex: 0),
                const SizedBox(height: DriverSpacing.xl),
                _ExpandableSection(
                  title: DriverStrings.preferencesSectionPayments,
                  icon: Icons.payments_outlined,
                  colors: colors,
                  typography: typography,
                  initiallyExpanded: true,
                  children: [
                    DriverSettingsToggleRow(
                      icon: Icons.payments_outlined,
                      title: DriverStrings.acceptsCash,
                      value: acceptsCash,
                      colors: colors,
                      typography: typography,
                      onChanged: onCashChanged,
                    ),
                    DriverSettingsToggleRow(
                      icon: Icons.credit_card_rounded,
                      title: DriverStrings.acceptsCard,
                      value: acceptsCard,
                      colors: colors,
                      typography: typography,
                      onChanged: onCardChanged,
                    ),
                    DriverSettingsToggleRow(
                      icon: Icons.account_balance_wallet_outlined,
                      title: DriverStrings.acceptsTikkie,
                      value: acceptsTikkie,
                      colors: colors,
                      typography: typography,
                      onChanged: onTikkieChanged,
                    ),
                    DriverSettingsToggleRow(
                      icon: Icons.receipt_long_rounded,
                      title: DriverStrings.acceptsInvoice,
                      value: acceptsInvoice,
                      colors: colors,
                      typography: typography,
                      onChanged: onInvoiceChanged,
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: DriverSpacing.xl),
                _ExpandableSection(
                  title: DriverStrings.preferencesSectionAccessibility,
                  icon: Icons.accessibility_new_rounded,
                  colors: colors,
                  typography: typography,
                  children: [
                    DriverSettingsToggleRow(
                      icon: Icons.pets_outlined,
                      title: DriverStrings.petFriendly,
                      value: petFriendly,
                      colors: colors,
                      typography: typography,
                      onChanged: onPetFriendlyChanged,
                    ),
                    DriverSettingsToggleRow(
                      icon: Icons.accessible_rounded,
                      title: DriverStrings.wheelchairAccessible,
                      value: wheelchairAccessible,
                      colors: colors,
                      typography: typography,
                      onChanged: onWheelchairChanged,
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: DriverSpacing.xl),
                _ExpandableSection(
                  title: DriverStrings.preferencesSectionAppearance,
                  icon: Icons.language_rounded,
                  colors: colors,
                  typography: typography,
                  children: [
                    DriverSettingsNavRow(
                      icon: Icons.language_rounded,
                      title: DriverStrings.language,
                      subtitle: languageSubtitle,
                      colors: colors,
                      typography: typography,
                      onTap: onLanguage,
                      showDivider: false,
                    ),
                  ],
                ),
                if (navigationContent != null) ...[
                  const SizedBox(height: DriverSpacing.xl),
                  _ExpandableSection(
                    title: DriverStrings.preferencesSectionNavigation,
                    icon: Icons.navigation_rounded,
                    colors: colors,
                    typography: typography,
                    initiallyExpanded: true,
                    children: [navigationContent!],
                  ),
                ],
                if (soundsContent != null) ...[
                  const SizedBox(height: DriverSpacing.xl),
                  _ExpandableSection(
                    title: DriverStrings.preferencesSounds,
                    icon: Icons.music_note_rounded,
                    colors: colors,
                    typography: typography,
                    children: [soundsContent!],
                  ),
                ],
                ...extraSections,
                SizedBox(height: bottomPad + 88),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.colors,
    required this.typography,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final DriverColors colors;
  final DriverTypography typography;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DriverSettingsGroupCard(
          colors: widget.colors,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(DriverSpacing.lg),
                  child: Row(
                    children: [
                      Icon(widget.icon, color: widget.colors.textSecondary),
                      const SizedBox(width: DriverSpacing.md),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: widget.typography.titleSmall.copyWith(
                            color: widget.colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: widget.colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: DriverSpacing.sm),
                  child: DriverSettingsGroupCard(
                    colors: widget.colors,
                    children: widget.children,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    ).driverFadeSlideIn(staggerIndex: 1);
  }
}
