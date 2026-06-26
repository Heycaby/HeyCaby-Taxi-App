import 'package:flutter/material.dart';

import '../theme/driver_colors.dart';
import '../theme/driver_radius.dart';
import '../theme/driver_spacing.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DriverRadius.sheetTop,
      ),
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
                  color: colors.border,
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
