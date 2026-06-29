import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import 'home_greeting_header.dart';

/// Map overlay: greeting (left), notifications (right), locate (bottom-right).
class HomeMapOverlay extends StatelessWidget {
  const HomeMapOverlay({
    super.key,
    required this.colors,
    required this.typo,
    required this.onLocate,
  });

  final HeyCabyColorTokens colors;
  final HeyCabyTypography typo;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned(
          top: top + 8,
          left: 16,
          right: 72,
          child: const HomeGreetingHeader(),
        ),
        Positioned(
          top: top + 8,
          right: 16,
          child: _MapCircleButton(
            colors: colors,
            icon: Icons.notifications_outlined,
            onTap: () => context.push('/account'),
          ),
        ),
        Positioned(
          right: 16,
          bottom: MediaQuery.sizeOf(context).height * 0.42,
          child: _MapCircleButton(
            colors: colors,
            icon: Icons.my_location_rounded,
            iconColor: colors.accent,
            onTap: onLocate,
          ),
        ),
      ],
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({
    required this.colors,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final HeyCabyColorTokens colors;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.card,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: colors.text.withValues(alpha: 0.12),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: iconColor ?? colors.text, size: 22),
        ),
      ),
    );
  }
}
