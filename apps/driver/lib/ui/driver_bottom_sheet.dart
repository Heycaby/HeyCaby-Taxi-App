import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_shadows.dart';
import '../theme/driver_spacing.dart';
import '../widgets/driver_ride_premium_style.dart';

/// Shows a token-styled modal bottom sheet.
Future<T?> showDriverBottomSheet<T>({
  required BuildContext context,
  required DriverColors colors,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DriverBottomSheet(
      colors: colors,
      child: builder(ctx),
    ),
  );
}

class DriverBottomSheet extends StatelessWidget {
  const DriverBottomSheet({
    super.key,
    required this.colors,
    required this.child,
    this.showHandle = true,
  });

  final DriverColors colors;
  final Widget child;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return DriverRidePremiumStyle.glassSurface(
      colors: colors,
      borderRadius: DriverRadius.sheetTop,
      blurSigma: 26,
      tintOpacity: 0.8,
      boxShadow: DriverShadows.floating(colors),
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle)
            Padding(
              padding: const EdgeInsets.only(top: DriverSpacing.md),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(DriverRadius.pill),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
