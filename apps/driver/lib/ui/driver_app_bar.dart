import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_icons.dart';
import '../theme/driver_typography.dart';

/// Consistent driver app bar — minimal, map-friendly.
class DriverAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DriverAppBar({
    super.key,
    required this.title,
    required this.colors,
    required this.typography,
    this.leading,
    this.actions,
    this.transparent = false,
    this.centerTitle = false,
  });

  final String title;
  final DriverColors colors;
  final DriverTypography typography;
  final Widget? leading;
  final List<Widget>? actions;
  final bool transparent;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: transparent ? Colors.transparent : colors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: leading ??
          (Navigator.canPop(context)
              ? DriverIconButton(
                  icon: AppIcons.arrowBack,
                  colors: colors,
                  onPressed: () => Navigator.maybePop(context),
                )
              : null),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: typography.titleLarge.copyWith(
          color: colors.text,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      centerTitle: centerTitle,
      actions: actions,
    );
  }
}
