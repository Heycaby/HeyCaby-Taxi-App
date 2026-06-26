import 'package:flutter/material.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_motion_presets.dart';
import '../theme/driver_typography.dart';
import '../ui/driver_map_online_chip.dart';

/// Compact floating widget when driver is online — delegates to [DriverMapOnlineChip].
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
    return DriverMapOnlineChip(
      zoneName: zoneName,
      isOnBreak: isOnBreak,
      colors: DriverColors.fromTheme(colors),
      typography: DriverTypography.fromTheme(typo),
      onTap: onTap,
    ).driverMapChromeEnter(staggerIndex: 1);
  }
}
