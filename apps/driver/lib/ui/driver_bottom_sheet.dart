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
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: colors.text.withValues(alpha: 0.48),
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
    this.floating = true,
  });

  final DriverColors colors;
  final Widget child;
  final bool showHandle;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final maxSheetHeight =
        MediaQuery.sizeOf(context).height * 0.88 - bottom - viewInsets;
    final radius =
        floating ? DriverRadius.sheetFloating : DriverRadius.sheetTop;

    final sheet = DriverRidePremiumStyle.glassSurface(
      colors: colors,
      borderRadius: radius,
      blurSigma: 28,
      tintOpacity: 0.88,
      boxShadow: DriverShadows.floating(colors),
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxSheetHeight.clamp(200.0, double.infinity),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle)
              Padding(
                padding: const EdgeInsets.only(top: DriverSpacing.md),
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(DriverRadius.pill),
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: viewInsets > 0 ? 8 : 0),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );

    if (!floating) return sheet;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        DriverSpacing.lg,
        0,
        DriverSpacing.lg,
        bottom + DriverSpacing.lg,
      ),
      child: sheet,
    );
  }
}
