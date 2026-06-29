import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

/// Shared top bar for booking steps (vehicle, payment, etc.).
class BookingFlowScreenHeader extends StatelessWidget {
  const BookingFlowScreenHeader({
    super.key,
    required this.colors,
    required this.typo,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: colors.card,
              foregroundColor: colors.text,
            ),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          if (icon != null) ...[
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.accentL,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colors.accent, size: 24),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: typo.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: typo.bodySmall.copyWith(
                      color: colors.textMid,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
