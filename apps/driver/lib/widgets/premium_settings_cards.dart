import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Drag handle + rounded top for modal sheets.
Widget premiumSheetHandle(HeyCabyColorTokens colors) {
  return Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: colors.border.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    ),
  );
}

/// Section label (uppercase, tracked) for grouped settings.
class PremiumSettingsSectionLabel extends StatelessWidget {
  const PremiumSettingsSectionLabel({
    super.key,
    required this.text,
    required this.colors,
    required this.typo,
  });

  final String text;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: typo.labelSmall.copyWith(
          color: colors.textSoft,
          letterSpacing: 1.15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Soft elevated card for grouped rows (no harsh dividers).
class PremiumSettingsCard extends StatelessWidget {
  const PremiumSettingsCard({
    super.key,
    required this.colors,
    required this.child,
  });

  final HeyCabyColorTokens colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.text.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}

/// Tappable row with leading icon in a soft pill.
class PremiumSettingsNavRow extends StatelessWidget {
  const PremiumSettingsNavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.typo,
    this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(icon, size: 22, color: colors.accent),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: typo.bodyLarge.copyWith(
                            color: colors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: typo.bodySmall.copyWith(
                            color: colors.textMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textSoft,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 72),
            child: Divider(height: 1, thickness: 1, color: colors.border.withValues(alpha: 0.5)),
          ),
      ],
    );
  }
}

/// Toggle row with icon + Material 3-style switch.
class PremiumSettingsToggleRow extends StatelessWidget {
  const PremiumSettingsToggleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.colors,
    required this.typo,
    required this.onChanged,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final bool value;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final void Function(bool) onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, size: 22, color: colors.accent),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: typo.bodyLarge.copyWith(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return colors.card;
                  return colors.textSoft;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return colors.accent.withValues(alpha: 0.55);
                  }
                  return colors.border.withValues(alpha: 0.55);
                }),
                trackOutlineColor: WidgetStateProperty.all(
                  colors.border.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 72),
            child: Divider(height: 1, thickness: 1, color: colors.border.withValues(alpha: 0.5)),
          ),
      ],
    );
  }
}
