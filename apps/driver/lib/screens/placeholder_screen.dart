import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heycaby_ui/heycaby_ui.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_typography.dart';
import '../widgets/driver_staging_surface_body.dart';

class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DriverStagingSurfaceBody(
      colors: DriverColors.fromTheme(ref.watch(colorsProvider)),
      typography: DriverTypography.fromTheme(ref.watch(typographyProvider)),
      title: title,
      icon: icon,
    );
  }
}
