import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../l10n/driver_strings.dart';

/// Compact floating widget when driver is online. Green/amber dot, text, zone, chevron.
class DriverOnlineStatusWidget extends StatelessWidget {
  const DriverOnlineStatusWidget({
    super.key,
    required this.zoneName,
    required this.isOnBreak,
    required this.colors,
    required this.typo,
    required this.onTap,
  });

  final String zoneName;
  final bool isOnBreak;
  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = isOnBreak ? colors.warning : colors.success;

    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(999),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isOnBreak ? DriverStrings.onBreak : DriverStrings.online,
                style: typo.bodySmall.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 1,
                  height: 12,
                  color: colors.border,
                ),
              ),
              Text(
                isOnBreak ? DriverStrings.resume : zoneName,
                style: typo.bodySmall.copyWith(color: colors.textSoft),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: colors.textSoft),
            ],
          ),
        ),
      ),
    ).animate().slideY(begin: -0.5, end: 0, duration: 400.ms, curve: Curves.easeOutBack).fadeIn(duration: 300.ms);
  }
}
